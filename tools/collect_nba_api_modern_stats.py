#!/usr/bin/env python3
"""Collect modern NBA Stats data and materialize Sports Terminal metric overlays.

The historical warehouse remains the long-run source of truth. This pipeline adds a
separate modern NBA.com/nba_api layer for tracking, hustle, clutch, shot-profile,
play-type and related fields that do not exist in the historical season tables.

Design rules:
- regular season and playoffs are always separate scopes;
- every raw result row is archived before transformation;
- failures are recorded without deleting prior successful scopes;
- collection is rate limited and never runs live in CI;
- only reviewed deterministic recipes may materialize terminal metrics.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib
import inspect
import json
import re
import sqlite3
import sys
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from importlib import metadata
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB = ROOT / "data" / "warehouse" / "nba_api_modern.sqlite"
DEFAULT_PLAN = ROOT / "assets" / "data" / "nba" / "metadata" / "nba_api_collection_plan.json"
DEFAULT_RECIPES = ROOT / "assets" / "data" / "nba" / "metadata" / "nba_api_metric_recipes.json"

SEASON_TYPE_LABELS = {
    "regular": "Regular Season",
    "playoffs": "Playoffs",
}

PARAMETER_CANDIDATES: dict[str, tuple[str, ...]] = {
    "season": ("season", "season_nullable"),
    "season_type": ("season_type_all_star", "season_type_nullable", "season_type"),
    "league_id": ("league_id", "league_id_nullable"),
    "per_mode": ("per_mode_detailed", "per_mode_simple", "per_mode_nullable", "per_mode"),
    "measure_type": ("measure_type_detailed_defense", "measure_type_nullable", "measure_type"),
    "defense_category": ("defense_category",),
    "pt_measure_type": ("pt_measure_type",),
    "player_or_team": ("player_or_team",),
    "clutch_time": ("clutch_time",),
    "ahead_behind": ("ahead_behind",),
    "point_diff": ("point_diff",),
    "distance_range": ("distance_range",),
    "play_type": ("play_type_nullable", "play_type"),
    "type_grouping": ("type_grouping_nullable", "type_grouping"),
}

PLAYER_ID_KEYS = ("PLAYER_ID", "PERSON_ID", "personId", "playerId", "VS_PLAYER_ID")
PLAYER_NAME_KEYS = (
    "PLAYER_NAME",
    "PLAYER_NAME_LAST_FIRST",
    "PLAYER",
    "playerName",
    "name",
)
TEAM_ID_KEYS = ("TEAM_ID", "teamId")
TEAM_ABBR_KEYS = ("TEAM_ABBREVIATION", "TEAM_ABBR", "teamTricode", "TEAM")

SIMPLE_STATUSES = {
    "direct",
    "direct_aggregate",
    "direct_estimate",
    "transparent_derived",
    "context_direct",
}


@dataclass(frozen=True)
class EndpointPlan:
    key: str
    module: str
    class_name: str
    datasets: tuple[str, ...]
    first_season: str
    enabled: bool
    variants: tuple[dict[str, Any], ...]
    notes: str = ""


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def connect(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(path)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys = ON")
    db.execute("PRAGMA journal_mode = WAL")
    db.execute("PRAGMA synchronous = NORMAL")
    return db


def init_db(db: sqlite3.Connection) -> None:
    db.executescript(
        """
        CREATE TABLE IF NOT EXISTS nba_api_collection_runs (
          run_id TEXT PRIMARY KEY,
          started_at TEXT NOT NULL,
          completed_at TEXT,
          status TEXT NOT NULL,
          package_version TEXT NOT NULL,
          plan_version INTEGER NOT NULL,
          request_count INTEGER NOT NULL DEFAULT 0,
          success_count INTEGER NOT NULL DEFAULT 0,
          failure_count INTEGER NOT NULL DEFAULT 0,
          notes TEXT NOT NULL DEFAULT ''
        );

        CREATE TABLE IF NOT EXISTS nba_api_requests (
          request_id TEXT PRIMARY KEY,
          run_id TEXT NOT NULL REFERENCES nba_api_collection_runs(run_id) ON DELETE CASCADE,
          endpoint_key TEXT NOT NULL,
          endpoint_module TEXT NOT NULL,
          endpoint_class TEXT NOT NULL,
          season TEXT NOT NULL,
          season_type TEXT NOT NULL,
          variant_key TEXT NOT NULL,
          kwargs_json TEXT NOT NULL,
          status TEXT NOT NULL,
          error TEXT NOT NULL DEFAULT '',
          started_at TEXT NOT NULL,
          completed_at TEXT,
          response_sha256 TEXT NOT NULL DEFAULT '',
          result_set_count INTEGER NOT NULL DEFAULT 0,
          row_count INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS nba_api_result_sets (
          request_id TEXT NOT NULL REFERENCES nba_api_requests(request_id) ON DELETE CASCADE,
          dataset TEXT NOT NULL,
          headers_json TEXT NOT NULL,
          row_count INTEGER NOT NULL,
          PRIMARY KEY(request_id, dataset)
        );

        CREATE TABLE IF NOT EXISTS nba_api_raw_rows (
          request_id TEXT NOT NULL REFERENCES nba_api_requests(request_id) ON DELETE CASCADE,
          endpoint_key TEXT NOT NULL,
          endpoint_class TEXT NOT NULL,
          dataset TEXT NOT NULL,
          season TEXT NOT NULL,
          season_type TEXT NOT NULL,
          variant_key TEXT NOT NULL,
          row_number INTEGER NOT NULL,
          player_id TEXT NOT NULL DEFAULT '',
          player_name TEXT NOT NULL DEFAULT '',
          team_id TEXT NOT NULL DEFAULT '',
          team_abbreviation TEXT NOT NULL DEFAULT '',
          payload_json TEXT NOT NULL,
          PRIMARY KEY(request_id, dataset, row_number)
        );

        CREATE TABLE IF NOT EXISTS nba_api_metric_values (
          season TEXT NOT NULL,
          season_type TEXT NOT NULL,
          player_id TEXT NOT NULL,
          player_name TEXT NOT NULL DEFAULT '',
          team_id TEXT NOT NULL DEFAULT '',
          team_abbreviation TEXT NOT NULL DEFAULT '',
          metric_key TEXT NOT NULL,
          metric_value REAL NOT NULL,
          source_endpoint TEXT NOT NULL,
          source_dataset TEXT NOT NULL,
          variant_key TEXT NOT NULL DEFAULT '',
          recipe_status TEXT NOT NULL,
          operation TEXT NOT NULL,
          recipe_priority INTEGER NOT NULL,
          request_id TEXT NOT NULL,
          materialized_at TEXT NOT NULL,
          PRIMARY KEY(
            season, season_type, player_id, team_id, metric_key,
            source_endpoint, source_dataset, variant_key
          )
        );

        CREATE INDEX IF NOT EXISTS idx_nba_api_raw_scope
          ON nba_api_raw_rows(season, season_type, endpoint_class, dataset);
        CREATE INDEX IF NOT EXISTS idx_nba_api_raw_player
          ON nba_api_raw_rows(player_id, season, season_type);
        CREATE INDEX IF NOT EXISTS idx_nba_api_metric_scope
          ON nba_api_metric_values(season, season_type, metric_key, player_id);
        CREATE INDEX IF NOT EXISTS idx_nba_api_metric_player
          ON nba_api_metric_values(player_id, season, season_type);
        CREATE INDEX IF NOT EXISTS idx_nba_api_requests_scope
          ON nba_api_requests(season, season_type, endpoint_key, status);
        """
    )
    db.commit()


def package_version() -> str:
    try:
        return metadata.version("nba_api")
    except metadata.PackageNotFoundError:
        return "not-installed"


def load_plan(path: Path) -> tuple[int, str, list[EndpointPlan]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    rows = payload.get("endpoints")
    if not isinstance(rows, list):
        raise RuntimeError(f"Collection plan has no endpoints list: {path}")
    plans: list[EndpointPlan] = []
    for raw in rows:
        if not isinstance(raw, dict):
            continue
        plans.append(
            EndpointPlan(
                key=str(raw.get("key") or ""),
                module=str(raw.get("module") or ""),
                class_name=str(raw.get("class") or ""),
                datasets=tuple(str(value) for value in raw.get("datasets") or []),
                first_season=str(raw.get("first_season") or "1946-47"),
                enabled=raw.get("enabled") is not False,
                variants=tuple(
                    dict(value) for value in (raw.get("variants") or [{"key": "default"}])
                    if isinstance(value, dict)
                ),
                notes=str(raw.get("notes") or ""),
            )
        )
    return int(payload.get("version") or 1), str(payload.get("nba_api_version") or ""), plans


def load_recipes(path: Path) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    rows = payload.get("recipes")
    if not isinstance(rows, list):
        raise RuntimeError(f"Metric recipe file has no recipes list: {path}")
    return [dict(row) for row in rows if isinstance(row, dict)]


def season_start(label: str) -> int:
    match = re.match(r"^(\d{4})-(\d{2}|\d{4})$", label.strip())
    if not match:
        raise ValueError(f"Invalid NBA season label: {label}")
    return int(match.group(1))


def season_label(start: int) -> str:
    return f"{start}-{str(start + 1)[-2:]}"


def season_range(start: str, end: str) -> list[str]:
    first = season_start(start)
    last = season_start(end)
    if last < first:
        raise ValueError("--to-season must not precede --from-season")
    return [season_label(year) for year in range(first, last + 1)]


def _endpoint_class(plan: EndpointPlan):
    module = importlib.import_module(f"nba_api.stats.endpoints.{plan.module}")
    endpoint_class = getattr(module, plan.class_name, None)
    if endpoint_class is None:
        raise RuntimeError(f"nba_api endpoint class not found: {plan.module}.{plan.class_name}")
    return endpoint_class


def _declared_datasets(endpoint_class: Any) -> set[str]:
    expected = getattr(endpoint_class, "expected_data", None)
    if isinstance(expected, dict):
        return {str(key) for key in expected}
    return set()


def _supported_parameter(signature: inspect.Signature, semantic: str) -> str | None:
    for candidate in PARAMETER_CANDIDATES.get(semantic, (semantic,)):
        if candidate in signature.parameters:
            return candidate
    return None


def resolve_kwargs(
    endpoint_class: Any,
    season: str,
    season_type: str,
    variant: dict[str, Any],
    timeout: float,
) -> tuple[dict[str, Any], list[str], list[str]]:
    signature = inspect.signature(endpoint_class.__init__)
    kwargs: dict[str, Any] = {}
    notes: list[str] = []
    supplied_semantics: set[str] = set()

    common = {
        "season": season,
        "season_type": SEASON_TYPE_LABELS[season_type],
        "league_id": "00",
    }
    for semantic, value in common.items():
        parameter = _supported_parameter(signature, semantic)
        if parameter:
            kwargs[parameter] = value
            supplied_semantics.add(semantic)

    for semantic, value in variant.items():
        if semantic == "key":
            continue
        parameter = _supported_parameter(signature, semantic)
        if parameter:
            kwargs[parameter] = value
            supplied_semantics.add(semantic)
        else:
            notes.append(f"variant semantic '{semantic}' is not accepted by constructor")

    if "timeout" in signature.parameters:
        kwargs["timeout"] = timeout

    missing_required: list[str] = []
    for name, parameter in signature.parameters.items():
        if name == "self" or name in kwargs:
            continue
        if parameter.kind in (inspect.Parameter.VAR_POSITIONAL, inspect.Parameter.VAR_KEYWORD):
            continue
        if parameter.default is inspect.Parameter.empty:
            missing_required.append(name)

    return kwargs, notes, missing_required


def dry_run_plan(
    plans: list[EndpointPlan],
    selected_keys: set[str],
    include_disabled: bool,
    season: str,
    season_type: str,
    timeout: float,
) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    errors = 0
    for plan in plans:
        if selected_keys and plan.key not in selected_keys:
            continue
        if not plan.enabled and not include_disabled:
            continue
        try:
            endpoint_class = _endpoint_class(plan)
            declared = _declared_datasets(endpoint_class)
            missing_datasets = [dataset for dataset in plan.datasets if declared and dataset not in declared]
            variants = []
            for variant in plan.variants:
                kwargs, notes, missing_required = resolve_kwargs(
                    endpoint_class, season, season_type, variant, timeout
                )
                valid = not missing_required
                if not valid:
                    errors += 1
                variants.append(
                    {
                        "key": str(variant.get("key") or "default"),
                        "valid": valid,
                        "kwargs": kwargs,
                        "notes": notes,
                        "missing_required": missing_required,
                    }
                )
            if missing_datasets:
                errors += len(missing_datasets)
            rows.append(
                {
                    "endpoint_key": plan.key,
                    "class": plan.class_name,
                    "enabled": plan.enabled,
                    "declared_datasets": sorted(declared),
                    "missing_datasets": missing_datasets,
                    "variants": variants,
                    "notes": plan.notes,
                }
            )
        except Exception as exc:
            errors += 1
            rows.append(
                {
                    "endpoint_key": plan.key,
                    "class": plan.class_name,
                    "enabled": plan.enabled,
                    "error": f"{type(exc).__name__}: {exc}",
                }
            )
    return {"package_version": package_version(), "errors": errors, "endpoints": rows}


def _response_dict(instance: Any) -> dict[str, Any]:
    getter = getattr(instance, "get_dict", None)
    if callable(getter):
        payload = getter()
        if isinstance(payload, dict):
            return payload
    nba_response = getattr(instance, "nba_response", None)
    getter = getattr(nba_response, "get_dict", None)
    if callable(getter):
        payload = getter()
        if isinstance(payload, dict):
            return payload
    raise RuntimeError("nba_api endpoint instance did not expose a dictionary response")


def _result_sets(payload: dict[str, Any]) -> list[dict[str, Any]]:
    candidates: list[Any] = []
    if isinstance(payload.get("resultSets"), list):
        candidates.extend(payload["resultSets"])
    elif isinstance(payload.get("resultSets"), dict):
        candidates.append(payload["resultSets"])
    if isinstance(payload.get("resultSet"), list):
        candidates.extend(payload["resultSet"])
    elif isinstance(payload.get("resultSet"), dict):
        candidates.append(payload["resultSet"])
    if not candidates:
        for name, value in payload.items():
            if isinstance(value, dict) and ("rowSet" in value or "headers" in value):
                item = dict(value)
                item.setdefault("name", name)
                candidates.append(item)
    return [dict(item) for item in candidates if isinstance(item, dict)]


def _row_objects(result_set: dict[str, Any]) -> tuple[list[str], list[dict[str, Any]]]:
    headers_raw = result_set.get("headers") or []
    if isinstance(headers_raw, list) and headers_raw and isinstance(headers_raw[0], dict):
        headers = [str(item.get("columnNames") or item.get("name") or "") for item in headers_raw]
    else:
        headers = [str(item) for item in headers_raw] if isinstance(headers_raw, list) else []
    row_set = result_set.get("rowSet") or result_set.get("rows") or []
    rows: list[dict[str, Any]] = []
    if isinstance(row_set, list):
        for item in row_set:
            if isinstance(item, dict):
                rows.append({str(key): value for key, value in item.items()})
            elif isinstance(item, (list, tuple)):
                rows.append({headers[index] if index < len(headers) else f"column_{index}": value for index, value in enumerate(item)})
    if not headers and rows:
        headers = list(rows[0])
    return headers, rows


def _ci_get(row: dict[str, Any], candidates: Iterable[str]) -> Any:
    lookup = {str(key).lower(): value for key, value in row.items()}
    for candidate in candidates:
        if candidate in row:
            return row[candidate]
        lowered = candidate.lower()
        if lowered in lookup:
            return lookup[lowered]
    return None


def _text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value).strip()


def archive_response(
    db: sqlite3.Connection,
    *,
    request_id: str,
    run_id: str,
    plan: EndpointPlan,
    season: str,
    season_type: str,
    variant_key: str,
    kwargs: dict[str, Any],
    payload: dict[str, Any],
    started_at: str,
) -> tuple[int, int, str]:
    serialized = json.dumps(payload, separators=(",", ":"), sort_keys=True, default=str)
    digest = hashlib.sha256(serialized.encode("utf-8")).hexdigest()
    sets = _result_sets(payload)
    total_rows = 0
    for index, result_set in enumerate(sets):
        dataset = str(result_set.get("name") or result_set.get("resultSetName") or f"dataset_{index}")
        headers, rows = _row_objects(result_set)
        db.execute(
            "INSERT OR REPLACE INTO nba_api_result_sets(request_id,dataset,headers_json,row_count) VALUES (?,?,?,?)",
            (request_id, dataset, json.dumps(headers), len(rows)),
        )
        for row_number, row in enumerate(rows):
            db.execute(
                """
                INSERT OR REPLACE INTO nba_api_raw_rows(
                  request_id,endpoint_key,endpoint_class,dataset,season,season_type,variant_key,
                  row_number,player_id,player_name,team_id,team_abbreviation,payload_json
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                (
                    request_id,
                    plan.key,
                    plan.class_name,
                    dataset,
                    season,
                    season_type,
                    variant_key,
                    row_number,
                    _text(_ci_get(row, PLAYER_ID_KEYS)),
                    _text(_ci_get(row, PLAYER_NAME_KEYS)),
                    _text(_ci_get(row, TEAM_ID_KEYS)),
                    _text(_ci_get(row, TEAM_ABBR_KEYS)),
                    json.dumps(row, separators=(",", ":"), sort_keys=True, default=str),
                ),
            )
        total_rows += len(rows)
    db.execute(
        """
        INSERT OR REPLACE INTO nba_api_requests(
          request_id,run_id,endpoint_key,endpoint_module,endpoint_class,season,season_type,
          variant_key,kwargs_json,status,error,started_at,completed_at,response_sha256,
          result_set_count,row_count
        ) VALUES (?,?,?,?,?,?,?,?,?,'success','',?,?,?,?,?,?)
        """,
        (
            request_id,
            run_id,
            plan.key,
            plan.module,
            plan.class_name,
            season,
            season_type,
            variant_key,
            json.dumps(kwargs, sort_keys=True, default=str),
            started_at,
            now_iso(),
            digest,
            len(sets),
            total_rows,
        ),
    )
    db.commit()
    return len(sets), total_rows, digest


def record_failure(
    db: sqlite3.Connection,
    *,
    request_id: str,
    run_id: str,
    plan: EndpointPlan,
    season: str,
    season_type: str,
    variant_key: str,
    kwargs: dict[str, Any],
    started_at: str,
    error: str,
) -> None:
    db.execute(
        """
        INSERT OR REPLACE INTO nba_api_requests(
          request_id,run_id,endpoint_key,endpoint_module,endpoint_class,season,season_type,
          variant_key,kwargs_json,status,error,started_at,completed_at,response_sha256,
          result_set_count,row_count
        ) VALUES (?,?,?,?,?,?,?,?,?,'failure',?,?,?,'',0,0)
        """,
        (
            request_id,
            run_id,
            plan.key,
            plan.module,
            plan.class_name,
            season,
            season_type,
            variant_key,
            json.dumps(kwargs, sort_keys=True, default=str),
            error,
            started_at,
            now_iso(),
        ),
    )
    db.commit()


def collect(
    db_path: Path,
    plan_version: int,
    plans: list[EndpointPlan],
    seasons: list[str],
    season_types: list[str],
    selected_keys: set[str],
    include_disabled: bool,
    delay: float,
    retries: int,
    timeout: float,
    replace_scope: bool,
) -> dict[str, Any]:
    version = package_version()
    if version == "not-installed":
        raise RuntimeError("nba_api is not installed. Use scripts/collect_nba_api_modern_stats.sh.")
    run_id = f"nbaapi_{uuid.uuid4().hex[:16]}"
    started = now_iso()
    with connect(db_path) as db:
        init_db(db)
        db.execute(
            "INSERT INTO nba_api_collection_runs(run_id,started_at,status,package_version,plan_version) VALUES (?,?,?,?,?)",
            (run_id, started, "running", version, plan_version),
        )
        db.commit()

        request_count = success_count = failure_count = 0
        last_request_at = 0.0
        for season in seasons:
            for season_type in season_types:
                for plan in plans:
                    if selected_keys and plan.key not in selected_keys:
                        continue
                    if not plan.enabled and not include_disabled:
                        continue
                    if season_start(season) < season_start(plan.first_season):
                        continue
                    endpoint_class = _endpoint_class(plan)
                    if replace_scope:
                        old_ids = [
                            row["request_id"]
                            for row in db.execute(
                                "SELECT request_id FROM nba_api_requests WHERE season=? AND season_type=? AND endpoint_key=?",
                                (season, season_type, plan.key),
                            ).fetchall()
                        ]
                        for old_id in old_ids:
                            db.execute("DELETE FROM nba_api_requests WHERE request_id=?", (old_id,))
                        db.commit()
                    for variant in plan.variants:
                        request_count += 1
                        variant_key = str(variant.get("key") or "default")
                        request_id = f"req_{uuid.uuid4().hex[:20]}"
                        request_started = now_iso()
                        kwargs, notes, missing = resolve_kwargs(endpoint_class, season, season_type, variant, timeout)
                        if missing:
                            failure_count += 1
                            record_failure(
                                db,
                                request_id=request_id,
                                run_id=run_id,
                                plan=plan,
                                season=season,
                                season_type=season_type,
                                variant_key=variant_key,
                                kwargs=kwargs,
                                started_at=request_started,
                                error=f"Missing required constructor parameters: {', '.join(missing)}; {'; '.join(notes)}",
                            )
                            continue
                        error = ""
                        for attempt in range(retries + 1):
                            elapsed = time.monotonic() - last_request_at
                            if elapsed < delay:
                                time.sleep(delay - elapsed)
                            try:
                                last_request_at = time.monotonic()
                                instance = endpoint_class(**kwargs)
                                payload = _response_dict(instance)
                                archive_response(
                                    db,
                                    request_id=request_id,
                                    run_id=run_id,
                                    plan=plan,
                                    season=season,
                                    season_type=season_type,
                                    variant_key=variant_key,
                                    kwargs=kwargs,
                                    payload=payload,
                                    started_at=request_started,
                                )
                                success_count += 1
                                error = ""
                                break
                            except Exception as exc:
                                error = f"{type(exc).__name__}: {exc}"
                                if attempt < retries:
                                    time.sleep(max(delay, 1.0) * (2 ** attempt))
                        if error:
                            failure_count += 1
                            record_failure(
                                db,
                                request_id=request_id,
                                run_id=run_id,
                                plan=plan,
                                season=season,
                                season_type=season_type,
                                variant_key=variant_key,
                                kwargs=kwargs,
                                started_at=request_started,
                                error=error,
                            )

        status = "success" if failure_count == 0 else "partial" if success_count else "failure"
        db.execute(
            """
            UPDATE nba_api_collection_runs
            SET completed_at=?,status=?,request_count=?,success_count=?,failure_count=?
            WHERE run_id=?
            """,
            (now_iso(), status, request_count, success_count, failure_count, run_id),
        )
        db.commit()
        return {
            "run_id": run_id,
            "status": status,
            "package_version": version,
            "requests": request_count,
            "successes": success_count,
            "failures": failure_count,
            "database": str(db_path),
        }


def _number(value: Any) -> float | None:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).replace(",", "").replace("%", "").strip()
    try:
        return float(text)
    except ValueError:
        return None


def _payload_value(payload: dict[str, Any], field: str) -> Any:
    if field in payload:
        return payload[field]
    normalized = re.sub(r"[^a-z0-9]", "", field.lower())
    for key, value in payload.items():
        if re.sub(r"[^a-z0-9]", "", str(key).lower()) == normalized:
            return value
    return None


def _simple_metric_value(recipe: dict[str, Any], payload: dict[str, Any]) -> float | None:
    operation = str(recipe.get("operation") or "").strip()
    inputs = [str(value) for value in recipe.get("inputs") or []]
    ratio = re.fullmatch(r"\s*([A-Za-z0-9_]+)\s*/\s*([A-Za-z0-9_]+)\s*", operation)
    if ratio:
        numerator = _number(_payload_value(payload, ratio.group(1)))
        denominator = _number(_payload_value(payload, ratio.group(2)))
        if numerator is None or denominator in (None, 0):
            return None
        return numerator / denominator
    if operation.lower() == "identity" or "identity" in operation.lower():
        for field in reversed(inputs):
            candidate = _number(_payload_value(payload, field))
            if candidate is not None:
                return candidate
        return None
    if str(recipe.get("status") or "") == "direct_aggregate" and len(inputs) >= 2:
        numerator = _number(_payload_value(payload, inputs[0]))
        denominator = _number(_payload_value(payload, inputs[1]))
        if numerator is not None and denominator not in (None, 0):
            return numerator / denominator
    return None


def materialize(
    db_path: Path,
    recipe_path: Path,
    seasons: list[str] | None = None,
    season_types: list[str] | None = None,
) -> dict[str, Any]:
    recipes = load_recipes(recipe_path)
    scopes = {(season, season_type) for season in (seasons or []) for season_type in (season_types or [])}
    inserted = skipped = 0
    with connect(db_path) as db:
        init_db(db)
        if scopes:
            for season, season_type in scopes:
                db.execute(
                    "DELETE FROM nba_api_metric_values WHERE season=? AND season_type=?",
                    (season, season_type),
                )
        else:
            db.execute("DELETE FROM nba_api_metric_values")
        db.commit()

        for priority, recipe in enumerate(recipes):
            status = str(recipe.get("status") or "")
            if status not in SIMPLE_STATUSES:
                skipped += 1
                continue
            endpoint = str(recipe.get("endpoint") or "")
            dataset_spec = str(recipe.get("dataset") or "")
            if not endpoint or not dataset_spec or "+" in dataset_spec:
                skipped += 1
                continue
            clauses = ["endpoint_class=?", "dataset=?", "player_id<>''"]
            params: list[Any] = [endpoint, dataset_spec]
            if scopes:
                scope_sql = " OR ".join("(season=? AND season_type=?)" for _ in scopes)
                clauses.append(f"({scope_sql})")
                for season, season_type in sorted(scopes):
                    params.extend([season, season_type])
            rows = db.execute(
                f"SELECT * FROM nba_api_raw_rows WHERE {' AND '.join(clauses)} ORDER BY season,season_type,request_id,row_number",
                params,
            ).fetchall()
            for row in rows:
                payload = json.loads(row["payload_json"])
                if not isinstance(payload, dict):
                    continue
                value = _simple_metric_value(recipe, payload)
                if value is None or value != value or value in (float("inf"), float("-inf")):
                    continue
                db.execute(
                    """
                    INSERT OR REPLACE INTO nba_api_metric_values(
                      season,season_type,player_id,player_name,team_id,team_abbreviation,
                      metric_key,metric_value,source_endpoint,source_dataset,variant_key,
                      recipe_status,operation,recipe_priority,request_id,materialized_at
                    ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                    """,
                    (
                        row["season"], row["season_type"], row["player_id"], row["player_name"],
                        row["team_id"], row["team_abbreviation"], str(recipe.get("metric") or ""), value,
                        endpoint, dataset_spec, row["variant_key"], status,
                        str(recipe.get("operation") or ""), priority, row["request_id"], now_iso(),
                    ),
                )
                inserted += 1
        db.commit()
        distinct_metrics = int(db.execute("SELECT COUNT(DISTINCT metric_key) FROM nba_api_metric_values").fetchone()[0])
        distinct_players = int(db.execute("SELECT COUNT(DISTINCT player_id) FROM nba_api_metric_values").fetchone()[0])
        scopes_count = int(db.execute("SELECT COUNT(*) FROM (SELECT DISTINCT season,season_type FROM nba_api_metric_values)").fetchone()[0])
    return {
        "database": str(db_path),
        "materialized_rows": inserted,
        "skipped_recipe_classes": skipped,
        "distinct_metrics": distinct_metrics,
        "distinct_players": distinct_players,
        "scopes": scopes_count,
    }


def status(db_path: Path) -> dict[str, Any]:
    if not db_path.exists():
        return {"database": str(db_path), "exists": False, "ready": False}
    with connect(db_path) as db:
        init_db(db)
        latest = db.execute(
            "SELECT * FROM nba_api_collection_runs ORDER BY started_at DESC LIMIT 1"
        ).fetchone()
        counts = {
            "runs": int(db.execute("SELECT COUNT(*) FROM nba_api_collection_runs").fetchone()[0]),
            "requests": int(db.execute("SELECT COUNT(*) FROM nba_api_requests").fetchone()[0]),
            "successful_requests": int(db.execute("SELECT COUNT(*) FROM nba_api_requests WHERE status='success'").fetchone()[0]),
            "failed_requests": int(db.execute("SELECT COUNT(*) FROM nba_api_requests WHERE status='failure'").fetchone()[0]),
            "raw_rows": int(db.execute("SELECT COUNT(*) FROM nba_api_raw_rows").fetchone()[0]),
            "metric_rows": int(db.execute("SELECT COUNT(*) FROM nba_api_metric_values").fetchone()[0]),
            "metrics": int(db.execute("SELECT COUNT(DISTINCT metric_key) FROM nba_api_metric_values").fetchone()[0]),
            "players": int(db.execute("SELECT COUNT(DISTINCT player_id) FROM nba_api_metric_values").fetchone()[0]),
        }
        coverage = [
            dict(row)
            for row in db.execute(
                """
                SELECT season,season_type,COUNT(DISTINCT endpoint_key) AS endpoints,
                       COUNT(DISTINCT player_id) AS players,COUNT(*) AS raw_rows
                FROM nba_api_raw_rows
                GROUP BY season,season_type
                ORDER BY season DESC,season_type
                """
            ).fetchall()
        ]
    return {
        "database": str(db_path),
        "exists": True,
        "ready": counts["metric_rows"] > 0,
        "latest_run": dict(latest) if latest else None,
        "counts": counts,
        "coverage": coverage,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--plan", type=Path, default=DEFAULT_PLAN)
    parser.add_argument("--recipes", type=Path, default=DEFAULT_RECIPES)
    parser.add_argument("--season", action="append", default=[])
    parser.add_argument("--from-season", default="")
    parser.add_argument("--to-season", default="")
    parser.add_argument("--season-type", choices=("regular", "playoffs", "both"), default="both")
    parser.add_argument("--endpoint", action="append", default=[])
    parser.add_argument("--include-disabled", action="store_true")
    parser.add_argument("--delay", type=float, default=1.25)
    parser.add_argument("--retries", type=int, default=2)
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--replace-scope", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--materialize-only", action="store_true")
    parser.add_argument("--status", action="store_true")
    args = parser.parse_args()

    if args.status:
        print(json.dumps(status(args.db), indent=2, sort_keys=True))
        return 0

    plan_version, expected_version, plans = load_plan(args.plan)
    selected = set(args.endpoint)
    seasons = list(dict.fromkeys(args.season))
    if args.from_season or args.to_season:
        if not args.from_season or not args.to_season:
            parser.error("--from-season and --to-season must be supplied together")
        seasons.extend(season_range(args.from_season, args.to_season))
    seasons = list(dict.fromkeys(seasons or ["2025-26"]))
    season_types = ["regular", "playoffs"] if args.season_type == "both" else [args.season_type]

    if args.dry_run:
        report = dry_run_plan(
            plans,
            selected,
            args.include_disabled,
            seasons[-1],
            season_types[0],
            args.timeout,
        )
        report["expected_package_version"] = expected_version
        report["plan_version"] = plan_version
        print(json.dumps(report, indent=2, sort_keys=True, default=str))
        if args.check and report["errors"]:
            return 1
        return 0

    if not args.materialize_only:
        result = collect(
            args.db,
            plan_version,
            plans,
            seasons,
            season_types,
            selected,
            args.include_disabled,
            max(args.delay, 0.0),
            max(args.retries, 0),
            max(args.timeout, 1.0),
            args.replace_scope,
        )
        print(json.dumps(result, indent=2, sort_keys=True))

    result = materialize(args.db, args.recipes, seasons, season_types)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
