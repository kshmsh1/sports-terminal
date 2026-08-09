#!/usr/bin/env python3
"""Materialize cached NBA API evidence into Sports Terminal player metrics.

The materialized database is an overlay, not a replacement for certified seed or
historical canonical data. Every value retains endpoint/result-set/formula
provenance. Candidate mappings that still require semantic review are never
materialized automatically.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sqlite3
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CACHE_ROOT = ROOT / "data" / "warehouse" / "nba_api_raw"
DEFAULT_DATABASE = ROOT / "data" / "warehouse" / "nba_api_metrics.sqlite"
DEFAULT_REPORT = ROOT / "data" / "warehouse" / "nba_api_metric_materialization_report.json"
DEFAULT_RECIPES = ROOT / "assets" / "data" / "nba" / "metadata" / "nba_api_metric_recipes.json"
DEFAULT_CATALOG = ROOT / "lib" / "services" / "nba_stats_metric_catalog.dart"

AUTOMATIC_STATUSES = {
    "direct",
    "context_direct",
    "direct_estimate",
    "direct_aggregate",
    "context_aggregate",
    "transparent_derived",
    "derived",
}
STATUS_PRIORITY = {
    "direct": 100,
    "context_direct": 95,
    "direct_estimate": 90,
    "direct_aggregate": 85,
    "context_aggregate": 82,
    "transparent_derived": 80,
    "derived": 75,
}
PLAYER_ID_FIELDS = (
    "PLAYER_ID",
    "PERSON_ID",
    "player_id",
    "person_id",
    "playerId",
    "personId",
)
PLAYER_NAME_FIELDS = (
    "PLAYER_NAME",
    "PLAYER",
    "PLAYER_NAME_LAST_FIRST",
    "player_name",
    "player",
    "playerName",
)
TEAM_ID_FIELDS = ("TEAM_ID", "team_id", "teamId")
TEAM_ABBREVIATION_FIELDS = (
    "TEAM_ABBREVIATION",
    "TEAM_ABBREV",
    "team_abbreviation",
    "teamAbbreviation",
)


@dataclass(frozen=True)
class Recipe:
    metric: str
    endpoint: str
    dataset: str
    status: str
    fields: tuple[str, ...]
    formula: str
    context: dict[str, Any]
    raw: dict[str, Any]


@dataclass
class Evidence:
    metric: str
    season: str
    season_type: str
    league_id: str
    player_id: str
    player_name: str
    team_id: str
    team_abbreviation: str
    value: float
    endpoint: str
    dataset: str
    status: str
    formula: str
    fields: list[str]
    variant: dict[str, Any]
    parameters: dict[str, Any]
    collected_at: str
    cache_path: str
    source_row: dict[str, Any]

    @property
    def priority(self) -> int:
        return STATUS_PRIORITY.get(self.status, 0)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def normalize_token(value: str) -> str:
    return re.sub(r"[^A-Z0-9]+", "_", value.upper()).strip("_")


def as_number(value: Any) -> float | None:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return float(int(value))
    if isinstance(value, (int, float)):
        result = float(value)
        return result if math.isfinite(result) else None
    try:
        result = float(str(value).replace(",", "").strip())
    except (TypeError, ValueError):
        return None
    return result if math.isfinite(result) else None


def first_text(row: dict[str, Any], candidates: Iterable[str]) -> str:
    normalized = {normalize_token(key): value for key, value in row.items()}
    for candidate in candidates:
        value = row.get(candidate)
        if value not in (None, ""):
            return str(value)
        value = normalized.get(normalize_token(candidate))
        if value not in (None, ""):
            return str(value)
    return ""


def normalized_row(row: dict[str, Any]) -> dict[str, Any]:
    result = dict(row)
    for key, value in row.items():
        result.setdefault(normalize_token(key), value)
    return result


def load_catalog_keys(path: Path) -> set[str]:
    if not path.exists():
        return set()
    text = path.read_text(encoding="utf-8")
    return set(re.findall(r"key:\s*'([^']+)'", text))


def listify(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    if isinstance(value, tuple):
        return list(value)
    return [value]


def normalize_fields(recipe: dict[str, Any]) -> tuple[str, ...]:
    values: list[Any] = []
    for key in ("fields", "inputs", "source_fields", "columns"):
        values.extend(listify(recipe.get(key)))
    for key in ("field", "source_field", "column"):
        if recipe.get(key) is not None:
            values.append(recipe[key])
    result: list[str] = []
    for item in values:
        if isinstance(item, str):
            result.append(item)
        elif isinstance(item, dict):
            for candidate in ("field", "column", "name", "source"):
                if item.get(candidate):
                    result.append(str(item[candidate]))
                    break
    formula = str(
        recipe.get("formula")
        or recipe.get("operation")
        or recipe.get("expression")
        or ""
    )
    if formula:
        for token in re.findall(r"\b[A-Z][A-Z0-9_]{1,}\b", formula.upper()):
            if token not in {"DIRECT", "SUM", "AVG", "AVERAGE", "PER", "GAME"}:
                result.append(token)
    deduped: list[str] = []
    seen: set[str] = set()
    for item in result:
        if item and normalize_token(item) not in seen:
            seen.add(normalize_token(item))
            deduped.append(item)
    return tuple(deduped)


def normalize_context(recipe: dict[str, Any]) -> dict[str, Any]:
    for key in ("context", "filters", "selector", "selectors"):
        value = recipe.get(key)
        if isinstance(value, dict):
            return {str(k): v for k, v in value.items()}
    return {}


def load_recipes(path: Path) -> list[Recipe]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    source = payload.get("recipes", []) if isinstance(payload, dict) else payload
    recipes: list[Recipe] = []
    for item in source if isinstance(source, list) else []:
        if not isinstance(item, dict):
            continue
        metric = str(item.get("metric") or item.get("metric_key") or item.get("key") or "")
        endpoint = str(item.get("endpoint") or "")
        dataset = str(item.get("dataset") or item.get("result_set") or item.get("resultSet") or "")
        status = str(item.get("status") or item.get("mapping_status") or "direct").lower()
        formula = str(item.get("formula") or item.get("operation") or item.get("expression") or "")
        if metric and endpoint:
            recipes.append(
                Recipe(
                    metric=metric,
                    endpoint=endpoint,
                    dataset=dataset,
                    status=status,
                    fields=normalize_fields(item),
                    formula=formula,
                    context=normalize_context(item),
                    raw=item,
                )
            )
    return recipes


def iter_cache_documents(cache_root: Path) -> Iterable[tuple[Path, dict[str, Any]]]:
    if not cache_root.exists():
        return
    for path in sorted(cache_root.rglob("*.json")):
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if isinstance(payload, dict) and payload.get("endpoint") and isinstance(payload.get("result_sets"), dict):
            yield path, payload


def context_matches(
    row: dict[str, Any],
    context: dict[str, Any],
    variant: dict[str, Any],
    parameters: dict[str, Any],
) -> bool:
    if not context:
        return True
    normalized = normalized_row(row)
    for key, expected in context.items():
        # Request-level selectors are accepted from variant/parameters, row-level
        # selectors from the result row. This preserves parameterized tracking
        # evidence without requiring every selector to be repeated in each row.
        candidates = [
            normalized.get(normalize_token(key)),
            variant.get(key),
            parameters.get(key),
        ]
        actual = next((value for value in candidates if value not in (None, "")), None)
        if isinstance(expected, list):
            if str(actual).lower() not in {str(value).lower() for value in expected}:
                return False
        elif str(actual).strip().lower() != str(expected).strip().lower():
            return False
    return True


def row_value(row: dict[str, Any], field: str) -> float | None:
    value = row.get(field)
    if value is None:
        value = normalized_row(row).get(normalize_token(field))
    return as_number(value)


def evaluate_formula(recipe: Recipe, row: dict[str, Any]) -> float | None:
    fields = list(recipe.fields)
    formula = recipe.formula.strip()
    if not formula or formula.lower() in {"direct", "identity", "source", "field"}:
        for field in fields:
            value = row_value(row, field)
            if value is not None:
                return value
        return None

    expression = formula.upper().replace("÷", "/").replace("×", "*")
    # A deliberately small evaluator: Sports Terminal only materializes transparent
    # arithmetic transforms. Anything outside this grammar remains unresolved.
    tokens = re.findall(r"[A-Z][A-Z0-9_]*|\d+(?:\.\d+)?|[()+\-*/]", expression)
    if not tokens:
        return None
    values: dict[str, float] = {}
    for token in tokens:
        if re.fullmatch(r"[A-Z][A-Z0-9_]*", token):
            value = row_value(row, token)
            if value is None:
                # Some manifests describe a rate semantically rather than as a
                # literal field formula; try listed fields before giving up.
                for field in fields:
                    candidate = row_value(row, field)
                    if candidate is not None:
                        values[normalize_token(field)] = candidate
                if token not in values:
                    return None
            else:
                values[token] = value
    safe_parts: list[str] = []
    for token in tokens:
        if re.fullmatch(r"[A-Z][A-Z0-9_]*", token):
            safe_parts.append(repr(values[token]))
        else:
            safe_parts.append(token)
    try:
        result = eval("".join(safe_parts), {"__builtins__": {}}, {})  # noqa: S307 - restricted grammar above
    except (ArithmeticError, SyntaxError, TypeError, ValueError):
        return None
    value = as_number(result)
    return value


def evaluate(recipe: Recipe, row: dict[str, Any]) -> float | None:
    if recipe.status not in AUTOMATIC_STATUSES:
        return None
    direct = evaluate_formula(recipe, row)
    if direct is not None:
        return direct
    # Common transparent recipe fallback when manifests use prose operations such
    # as "DEFLECTIONS per game" rather than a parseable arithmetic expression.
    numeric = [(field, row_value(row, field)) for field in recipe.fields]
    numeric = [(field, value) for field, value in numeric if value is not None]
    if not numeric:
        return None
    lower = recipe.formula.lower()
    if ("per game" in lower or recipe.metric.endswith("_pg")) and len(numeric) >= 1:
        games = row_value(row, "G") or row_value(row, "GP") or row_value(row, "GAMES")
        if games and games > 0:
            return numeric[0][1] / games
    if ("ratio" in lower or "/" in recipe.formula) and len(numeric) >= 2 and numeric[1][1] != 0:
        return numeric[0][1] / numeric[1][1]
    if "difference" in lower and len(numeric) >= 2:
        return numeric[0][1] - numeric[1][1]
    if len(numeric) == 1:
        return numeric[0][1]
    return None


def dataset_candidates(recipe: Recipe, result_sets: dict[str, Any]) -> Iterable[tuple[str, list[dict[str, Any]]]]:
    if recipe.dataset:
        wanted = normalize_token(recipe.dataset)
        exact = [
            (name, rows)
            for name, rows in result_sets.items()
            if normalize_token(name) == wanted and isinstance(rows, list)
        ]
        if exact:
            yield from exact
            return
    for name, rows in result_sets.items():
        if isinstance(rows, list):
            yield str(name), [row for row in rows if isinstance(row, dict)]


def evidence_from_document(
    path: Path,
    document: dict[str, Any],
    recipes: list[Recipe],
) -> Iterable[Evidence]:
    endpoint = str(document.get("endpoint") or "")
    season = str(document.get("season") or "")
    season_type = str(document.get("season_type") or "")
    variant = document.get("variant") if isinstance(document.get("variant"), dict) else {}
    parameters = document.get("parameters") if isinstance(document.get("parameters"), dict) else {}
    collected_at = str(document.get("collected_at") or "")
    result_sets = document.get("result_sets") if isinstance(document.get("result_sets"), dict) else {}
    for recipe in recipes:
        if recipe.endpoint != endpoint or recipe.status not in AUTOMATIC_STATUSES:
            continue
        for dataset, rows in dataset_candidates(recipe, result_sets):
            for raw_row in rows:
                row = {str(key): value for key, value in raw_row.items()}
                if not context_matches(row, recipe.context, variant, parameters):
                    continue
                player_id = first_text(row, PLAYER_ID_FIELDS)
                if not player_id:
                    continue
                value = evaluate(recipe, row)
                if value is None:
                    continue
                yield Evidence(
                    metric=recipe.metric,
                    season=season,
                    season_type=season_type,
                    league_id=first_text(row, ("LEAGUE_ID", "league_id")) or "00",
                    player_id=player_id,
                    player_name=first_text(row, PLAYER_NAME_FIELDS),
                    team_id=first_text(row, TEAM_ID_FIELDS),
                    team_abbreviation=first_text(row, TEAM_ABBREVIATION_FIELDS),
                    value=value,
                    endpoint=endpoint,
                    dataset=dataset,
                    status=recipe.status,
                    formula=recipe.formula or "direct",
                    fields=list(recipe.fields),
                    variant=dict(variant),
                    parameters=dict(parameters),
                    collected_at=collected_at,
                    cache_path=str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path),
                    source_row=row,
                )


def init_database(db: sqlite3.Connection) -> None:
    db.executescript(
        """
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS nba_api_metric_runs (
          run_id TEXT PRIMARY KEY,
          generated_at TEXT NOT NULL,
          recipe_version TEXT,
          catalog_metrics INTEGER NOT NULL,
          cache_documents INTEGER NOT NULL,
          materialized_metrics INTEGER NOT NULL,
          materialized_players INTEGER NOT NULL,
          materialized_seasons INTEGER NOT NULL,
          summary_json TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS nba_api_materialized_metrics (
          season_id TEXT NOT NULL,
          season_type TEXT NOT NULL,
          league_id TEXT NOT NULL,
          player_id TEXT NOT NULL,
          player_name TEXT,
          team_id TEXT,
          team_abbreviation TEXT,
          metric_key TEXT NOT NULL,
          value REAL NOT NULL,
          mapping_status TEXT NOT NULL,
          source_endpoint TEXT NOT NULL,
          source_dataset TEXT NOT NULL,
          source_formula TEXT NOT NULL,
          source_fields_json TEXT NOT NULL,
          request_variant_json TEXT NOT NULL,
          request_parameters_json TEXT NOT NULL,
          cache_path TEXT NOT NULL,
          collected_at TEXT,
          provenance_json TEXT NOT NULL,
          PRIMARY KEY (season_id, season_type, league_id, player_id, metric_key)
        );
        CREATE INDEX IF NOT EXISTS idx_nba_api_materialized_player
          ON nba_api_materialized_metrics(season_id, season_type, player_id);
        CREATE INDEX IF NOT EXISTS idx_nba_api_materialized_metric
          ON nba_api_materialized_metrics(season_id, season_type, metric_key);
        CREATE TABLE IF NOT EXISTS nba_api_metric_conflicts (
          conflict_id TEXT PRIMARY KEY,
          season_id TEXT NOT NULL,
          season_type TEXT NOT NULL,
          player_id TEXT NOT NULL,
          metric_key TEXT NOT NULL,
          kept_endpoint TEXT NOT NULL,
          kept_value REAL NOT NULL,
          alternate_endpoint TEXT NOT NULL,
          alternate_value REAL NOT NULL,
          relative_difference REAL,
          evidence_json TEXT NOT NULL
        );
        CREATE VIEW IF NOT EXISTS nba_api_metric_coverage AS
        SELECT season_id, season_type, metric_key,
               COUNT(DISTINCT player_id) AS players,
               COUNT(*) AS values_count,
               MIN(value) AS min_value,
               MAX(value) AS max_value,
               GROUP_CONCAT(DISTINCT source_endpoint) AS endpoints
        FROM nba_api_materialized_metrics
        GROUP BY season_id, season_type, metric_key;
        """
    )


def evidence_key(evidence: Evidence) -> tuple[str, str, str, str, str]:
    return (
        evidence.season,
        evidence.season_type,
        evidence.league_id,
        evidence.player_id,
        evidence.metric,
    )


def relative_difference(left: float, right: float) -> float:
    denominator = max(abs(left), abs(right), 1e-9)
    return abs(left - right) / denominator


def choose_evidence(items: list[Evidence]) -> Evidence:
    return sorted(
        items,
        key=lambda item: (
            item.priority,
            bool(item.player_name),
            bool(item.team_id),
            item.collected_at,
            item.endpoint,
        ),
        reverse=True,
    )[0]


def materialize(
    *,
    cache_root: Path,
    recipes_path: Path,
    catalog_path: Path,
    database_path: Path,
    report_path: Path,
    replace: bool,
) -> dict[str, Any]:
    recipes_payload = json.loads(recipes_path.read_text(encoding="utf-8"))
    recipe_version = str(recipes_payload.get("version") or "") if isinstance(recipes_payload, dict) else ""
    recipes = load_recipes(recipes_path)
    catalog_keys = load_catalog_keys(catalog_path)
    automatic_recipes = [recipe for recipe in recipes if recipe.status in AUTOMATIC_STATUSES]
    unknown_metrics = sorted({recipe.metric for recipe in recipes if catalog_keys and recipe.metric not in catalog_keys})

    documents = list(iter_cache_documents(cache_root))
    grouped: dict[tuple[str, str, str, str, str], list[Evidence]] = defaultdict(list)
    observed_columns: dict[str, set[str]] = defaultdict(set)
    for path, document in documents:
        endpoint = str(document.get("endpoint") or "")
        for rows in document.get("result_sets", {}).values():
            if isinstance(rows, list):
                for row in rows:
                    if isinstance(row, dict):
                        observed_columns[endpoint].update(str(key) for key in row.keys())
        for evidence in evidence_from_document(path, document, automatic_recipes):
            grouped[evidence_key(evidence)].append(evidence)

    chosen = {key: choose_evidence(items) for key, items in grouped.items()}
    database_path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(database_path)
    db.row_factory = sqlite3.Row
    init_database(db)
    if replace:
        db.execute("DELETE FROM nba_api_materialized_metrics")
        db.execute("DELETE FROM nba_api_metric_conflicts")
    conflict_rows = 0
    for key, evidence in chosen.items():
        provenance = {
            "source": "nba_api",
            "endpoint": evidence.endpoint,
            "dataset": evidence.dataset,
            "mapping_status": evidence.status,
            "formula": evidence.formula,
            "fields": evidence.fields,
            "variant": evidence.variant,
            "parameters": evidence.parameters,
            "cache_path": evidence.cache_path,
            "collected_at": evidence.collected_at,
        }
        db.execute(
            """
            INSERT INTO nba_api_materialized_metrics(
              season_id,season_type,league_id,player_id,player_name,team_id,team_abbreviation,
              metric_key,value,mapping_status,source_endpoint,source_dataset,source_formula,
              source_fields_json,request_variant_json,request_parameters_json,cache_path,
              collected_at,provenance_json
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT(season_id,season_type,league_id,player_id,metric_key) DO UPDATE SET
              player_name=excluded.player_name,team_id=excluded.team_id,
              team_abbreviation=excluded.team_abbreviation,value=excluded.value,
              mapping_status=excluded.mapping_status,source_endpoint=excluded.source_endpoint,
              source_dataset=excluded.source_dataset,source_formula=excluded.source_formula,
              source_fields_json=excluded.source_fields_json,
              request_variant_json=excluded.request_variant_json,
              request_parameters_json=excluded.request_parameters_json,
              cache_path=excluded.cache_path,collected_at=excluded.collected_at,
              provenance_json=excluded.provenance_json
            """,
            (
                evidence.season,
                evidence.season_type,
                evidence.league_id,
                evidence.player_id,
                evidence.player_name,
                evidence.team_id,
                evidence.team_abbreviation,
                evidence.metric,
                evidence.value,
                evidence.status,
                evidence.endpoint,
                evidence.dataset,
                evidence.formula or "direct",
                json.dumps(evidence.fields),
                json.dumps(evidence.variant, sort_keys=True),
                json.dumps(evidence.parameters, sort_keys=True, default=str),
                evidence.cache_path,
                evidence.collected_at,
                json.dumps(provenance, sort_keys=True, default=str),
            ),
        )
        for alternate in grouped[key]:
            if alternate is evidence:
                continue
            difference = relative_difference(evidence.value, alternate.value)
            if difference < 0.005:
                continue
            digest = hashlib.sha256(
                "|".join([*key, evidence.endpoint, alternate.endpoint, str(alternate.value)]).encode("utf-8")
            ).hexdigest()[:24]
            db.execute(
                """
                INSERT OR REPLACE INTO nba_api_metric_conflicts(
                  conflict_id,season_id,season_type,player_id,metric_key,kept_endpoint,kept_value,
                  alternate_endpoint,alternate_value,relative_difference,evidence_json
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?)
                """,
                (
                    digest,
                    evidence.season,
                    evidence.season_type,
                    evidence.player_id,
                    evidence.metric,
                    evidence.endpoint,
                    evidence.value,
                    alternate.endpoint,
                    alternate.value,
                    difference,
                    json.dumps(
                        {
                            "kept": evidence.cache_path,
                            "alternate": alternate.cache_path,
                            "kept_status": evidence.status,
                            "alternate_status": alternate.status,
                        },
                        sort_keys=True,
                    ),
                ),
            )
            conflict_rows += 1

    coverage_rows = [dict(row) for row in db.execute(
        "SELECT * FROM nba_api_metric_coverage ORDER BY season_id,season_type,metric_key"
    ).fetchall()]
    materialized_metrics = len({row["metric_key"] for row in coverage_rows})
    materialized_players = int(db.execute(
        "SELECT COUNT(DISTINCT player_id) FROM nba_api_materialized_metrics"
    ).fetchone()[0])
    materialized_seasons = int(db.execute(
        "SELECT COUNT(DISTINCT season_id || '|' || season_type) FROM nba_api_materialized_metrics"
    ).fetchone()[0])
    actual_coverage_pct = round(materialized_metrics / len(catalog_keys) * 100, 2) if catalog_keys else 0.0
    summary = {
        "schema_version": 1,
        "generated_at": now_iso(),
        "recipe_version": recipe_version,
        "catalog_metrics": len(catalog_keys),
        "recipes": len(recipes),
        "automatic_recipes": len(automatic_recipes),
        "cache_documents": len(documents),
        "materialized_values": len(chosen),
        "materialized_metrics": materialized_metrics,
        "materialized_players": materialized_players,
        "materialized_season_partitions": materialized_seasons,
        "actual_metric_coverage_pct": actual_coverage_pct,
        "conflicts": conflict_rows,
        "unknown_recipe_metrics": unknown_metrics,
        "coverage": coverage_rows,
        "observed_columns": {
            endpoint: sorted(columns) for endpoint, columns in sorted(observed_columns.items())
        },
    }
    run_id = hashlib.sha256(
        json.dumps(summary, sort_keys=True, default=str).encode("utf-8")
    ).hexdigest()[:24]
    db.execute(
        """
        INSERT OR REPLACE INTO nba_api_metric_runs(
          run_id,generated_at,recipe_version,catalog_metrics,cache_documents,
          materialized_metrics,materialized_players,materialized_seasons,summary_json
        ) VALUES (?,?,?,?,?,?,?,?,?)
        """,
        (
            run_id,
            summary["generated_at"],
            recipe_version,
            len(catalog_keys),
            len(documents),
            materialized_metrics,
            materialized_players,
            materialized_seasons,
            json.dumps(summary, sort_keys=True, default=str),
        ),
    )
    db.commit()
    db.close()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(summary, indent=2, default=str), encoding="utf-8")
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-root", type=Path, default=DEFAULT_CACHE_ROOT)
    parser.add_argument("--recipes", type=Path, default=DEFAULT_RECIPES)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--database", type=Path, default=DEFAULT_DATABASE)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    summary = materialize(
        cache_root=args.cache_root,
        recipes_path=args.recipes,
        catalog_path=args.catalog,
        database_path=args.database,
        report_path=args.report,
        replace=args.replace,
    )
    compact = {key: value for key, value in summary.items() if key not in {"coverage", "observed_columns"}}
    print(json.dumps(compact, indent=2))
    print(f"Database: {args.database}")
    print(f"Report: {args.report}")
    if args.check:
        if summary["unknown_recipe_metrics"]:
            return 1
        if summary["cache_documents"] > 0 and summary["materialized_values"] == 0:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
