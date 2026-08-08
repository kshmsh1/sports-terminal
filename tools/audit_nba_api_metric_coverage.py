#!/usr/bin/env python3
"""Inventory nba_api endpoint schemas and map them to Sports Terminal metrics.

The audit is intentionally schema-only: it never calls stats.nba.com. It reads the
``expected_data`` declarations shipped with ``nba_api``, parses the Sports Terminal
metric registry, validates explicit population recipes, and emits an auditable
coverage report. Live ingestion is a separate step.
"""

from __future__ import annotations

import argparse
import importlib
import inspect
import json
import pkgutil
import re
import sys
from collections import defaultdict
from importlib import metadata
from pathlib import Path
from typing import Any, Iterable


ENGINE_COLUMN_ALIASES: dict[str, list[str]] = {
    "gp": ["GP", "G", "GAMESPLAYED"],
    "min": ["MIN", "MINUTES"],
    "pts": ["PTS", "POINTS"],
    "reb": ["REB", "REBOUNDS"],
    "oreb": ["OREB"],
    "dreb": ["DREB"],
    "ast": ["AST", "ASSISTS"],
    "stl": ["STL", "STEALS"],
    "blk": ["BLK", "BLOCKS"],
    "tov": ["TOV", "TO", "TURNOVERS"],
    "pf": ["PF", "FOULSPERSONAL"],
    "fgm": ["FGM", "FIELDGOALSMADE"],
    "fga": ["FGA", "FIELDGOALSATTEMPTED"],
    "fg_pct": ["FG_PCT", "FGPCT", "FIELDGOALPERCENTAGE"],
    "three_pm": ["FG3M", "3PM", "THREE_PM", "THREEPOINTERSMADE"],
    "three_pa": ["FG3A", "3PA", "THREE_PA", "THREEPOINTERSATTEMPTED"],
    "three_pct": ["FG3_PCT", "3P_PCT", "THREE_PCT", "THREEPOINTERSPERCENTAGE"],
    "ftm": ["FTM", "FREETHROWSMADE"],
    "fta": ["FTA", "FREETHROWSATTEMPTED"],
    "ft_pct": ["FT_PCT", "FTPCT", "FREETHROWPERCENTAGE"],
    "efg_pct": ["EFG_PCT", "E_FG_PCT"],
    "ts_pct": ["TS_PCT", "TSPCT"],
    "ft_rate": ["FTA_RATE", "FT_RATE"],
    "three_rate": ["FG3A_RATE", "THREE_RATE", "3PA_RATE", "FG3A_FREQUENCY"],
    "bpm": ["BPM"],
    "ast_tov": ["AST_TO", "AST_TOV", "AST_TO_RATIO"],
}


PRIORITY_ENDPOINT_HINTS: dict[str, list[str]] = {
    "Basic": ["LeagueDashPlayerStats", "PlayerGameLogs"],
    "Defense": ["LeagueHustleStatsPlayer", "LeagueDashPtDefend", "PlayerDashPtShotDefend"],
    "Playmaking": ["BoxScorePlayerTrackV3", "PlayerDashPtPass", "BoxScoreAdvancedV2"],
    "Rebounding": ["PlayerDashPtReb", "BoxScoreAdvancedV2", "PlayerEstimatedMetrics"],
    "Efficiency": ["LeagueDashPlayerStats", "LeagueDashPlayerBioStats", "BoxScoreAdvancedV2"],
    "Impact": ["BoxScoreAdvancedV3", "PlayerEstimatedMetrics", "TeamPlayerOnOffSummary"],
    "Aggregate": ["PlayerEstimatedMetrics"],
    "Movement": ["BoxScorePlayerTrackV3", "LeagueDashPtStats"],
    "Clutch": ["LeagueDashPlayerClutch", "PlayerDashboardByClutch"],
    "Shot Profile": ["LeagueDashPlayerPtShot", "LeagueDashPlayerShotLocations", "PlayerDashPtShots", "ShotChartDetail", "DunkScoreLeaders"],
    "Play Type": ["SynergyPlayTypes"],
    "Creation": ["GravityLeaders", "BoxScorePlayerTrackV3"],
    "Physical": ["LeagueDashPlayerBioStats", "DraftCombineStats"],
    "Discipline": ["BoxScoreMatchupsV3", "BoxScoreMiscV3", "PlayByPlayV3"],
    "Availability": [],
}


METRIC_RE = re.compile(
    r"^\s*_m\('(?P<key>[^']+)',\s*'(?P<label>[^']*)',\s*'(?P<short>[^']*)',\s*'(?P<group>[^']*)'"
)
RAW_RE = re.compile(r"raw:\s*\[([^\]]*)\]")
ENGINE_RE = re.compile(r"engineKey:\s*'([^']+)'")
QUOTED_RE = re.compile(r"'([^']+)'")


READY_RECIPE_STATUSES = {
    "direct",
    "direct_aggregate",
    "direct_estimate",
    "game_aggregate",
    "transparent_derived",
    "context_direct",
    "context_aggregate",
    "context_derived",
    "event_aggregate",
    "event_classifier",
    "custom_geometry",
}


def normalize(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def flatten_columns(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        output: list[str] = []
        for nested in value.values():
            output.extend(flatten_columns(nested))
        return output
    if isinstance(value, (list, tuple, set)):
        output: list[str] = []
        for nested in value:
            output.extend(flatten_columns(nested))
        return output
    return []


def parse_metric_catalog(path: Path) -> list[dict[str, Any]]:
    metrics: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = METRIC_RE.search(line)
        if not match:
            continue
        raw_match = RAW_RE.search(line)
        engine_match = ENGINE_RE.search(line)
        raw_aliases = QUOTED_RE.findall(raw_match.group(1)) if raw_match else []
        engine_key = engine_match.group(1) if engine_match else ""
        # Deliberately do not use the display short label as a schema alias.
        # Punctuation normalization would make STL% collide with STL, AST% with
        # AST, etc., creating semantically false positives.
        aliases = [
            match.group("key"),
            *raw_aliases,
            *ENGINE_COLUMN_ALIASES.get(engine_key, []),
        ]
        metrics.append(
            {
                "key": match.group("key"),
                "label": match.group("label"),
                "short_label": match.group("short"),
                "group": match.group("group"),
                "engine_key": engine_key,
                "aliases": sorted({alias for alias in aliases if alias}),
            }
        )
    if not metrics:
        raise RuntimeError(f"No metrics parsed from {path}")
    return metrics


def load_recipes(path: Path) -> dict[str, list[dict[str, Any]]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    rows = payload.get("recipes")
    if not isinstance(rows, list):
        raise RuntimeError(f"Recipe file has no recipes list: {path}")
    recipes: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if not isinstance(row, dict):
            continue
        metric = str(row.get("metric") or "").strip()
        if metric:
            recipes[metric].append(row)
    return dict(recipes)


def inventory_nba_api() -> tuple[str, list[dict[str, Any]]]:
    try:
        from nba_api.stats import endpoints  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "nba_api is not installed. Run scripts/audit_nba_api_metric_coverage.sh "
            "or install nba_api in the active Python environment."
        ) from exc

    try:
        version = metadata.version("nba_api")
    except metadata.PackageNotFoundError:
        version = "unknown"

    inventory: list[dict[str, Any]] = []
    seen: set[tuple[str, str, str]] = set()
    for module_info in pkgutil.iter_modules(endpoints.__path__):
        if module_info.name.startswith("_"):
            continue
        module_name = f"{endpoints.__name__}.{module_info.name}"
        try:
            module = importlib.import_module(module_name)
        except Exception as exc:
            inventory.append(
                {
                    "module": module_name,
                    "class": "",
                    "endpoint": "",
                    "dataset": "__IMPORT_ERROR__",
                    "columns": [],
                    "error": f"{type(exc).__name__}: {exc}",
                }
            )
            continue

        for class_name, endpoint_class in inspect.getmembers(module, inspect.isclass):
            if endpoint_class.__module__ != module.__name__:
                continue
            expected = getattr(endpoint_class, "expected_data", None)
            if not expected:
                continue
            endpoint_name = str(getattr(endpoint_class, "endpoint", module_info.name))
            if isinstance(expected, dict):
                datasets: Iterable[tuple[str, Any]] = expected.items()
            else:
                datasets = ((class_name, expected),)
            for dataset_name, columns_value in datasets:
                columns = flatten_columns(columns_value)
                identity = (class_name, str(dataset_name), endpoint_name)
                if identity in seen:
                    continue
                seen.add(identity)
                inventory.append(
                    {
                        "module": module_name,
                        "class": class_name,
                        "endpoint": endpoint_name,
                        "dataset": str(dataset_name),
                        "columns": columns,
                        "error": "",
                    }
                )
    return version, inventory


def _recipe_schema_support(
    recipe: dict[str, Any],
    inventory: list[dict[str, Any]],
) -> dict[str, Any]:
    endpoint_class = str(recipe.get("endpoint") or "")
    dataset_spec = str(recipe.get("dataset") or "")
    requested_datasets = [part.strip() for part in dataset_spec.split("+") if part.strip()]

    endpoint_rows = [
        item
        for item in inventory
        if not item.get("error") and item.get("class") == endpoint_class
    ]
    if not endpoint_rows:
        return {**recipe, "schema_supported": False, "schema_error": "endpoint class not discovered"}

    if requested_datasets:
        selected_rows: list[dict[str, Any]] = []
        missing_datasets: list[str] = []
        for dataset in requested_datasets:
            matches = [item for item in endpoint_rows if item.get("dataset") == dataset]
            if not matches:
                missing_datasets.append(dataset)
            selected_rows.extend(matches)
        if missing_datasets:
            return {
                **recipe,
                "schema_supported": False,
                "schema_error": f"missing result set(s): {', '.join(missing_datasets)}",
            }
    else:
        selected_rows = endpoint_rows

    available = {
        normalize(column)
        for item in selected_rows
        for column in item.get("columns", [])
        if normalize(column)
    }
    missing_inputs = [
        str(value)
        for value in recipe.get("inputs", [])
        if normalize(str(value)) not in available
    ]
    return {
        **recipe,
        "schema_supported": not missing_inputs,
        "schema_error": "" if not missing_inputs else f"missing declared field(s): {', '.join(missing_inputs)}",
    }


def build_coverage(
    metrics: list[dict[str, Any]],
    inventory: list[dict[str, Any]],
    recipes: dict[str, list[dict[str, Any]]],
) -> list[dict[str, Any]]:
    column_index: dict[str, list[dict[str, str]]] = defaultdict(list)
    for item in inventory:
        if item.get("error"):
            continue
        for column in item["columns"]:
            column_index[normalize(column)].append(
                {
                    "class": item["class"],
                    "endpoint": item["endpoint"],
                    "dataset": item["dataset"],
                    "column": column,
                }
            )

    output: list[dict[str, Any]] = []
    for metric in metrics:
        candidates: list[dict[str, str]] = []
        seen: set[tuple[str, str, str, str]] = set()
        for alias in metric["aliases"]:
            for candidate in column_index.get(normalize(alias), []):
                identity = (
                    candidate["class"],
                    candidate["dataset"],
                    candidate["column"],
                    candidate["endpoint"],
                )
                if identity in seen:
                    continue
                seen.add(identity)
                candidates.append(candidate)

        checked_recipes = [
            _recipe_schema_support(recipe, inventory)
            for recipe in recipes.get(metric["key"], [])
        ]
        ready_recipes = [
            recipe
            for recipe in checked_recipes
            if recipe.get("schema_supported")
            and recipe.get("status") in READY_RECIPE_STATUSES
        ]
        candidate_recipes = [
            recipe
            for recipe in checked_recipes
            if recipe.get("schema_supported")
            and recipe.get("status") not in READY_RECIPE_STATUSES
        ]
        if candidates:
            status = "direct_alias"
        elif ready_recipes:
            status = "recipe_supported"
        elif candidate_recipes:
            status = "candidate_only"
        elif checked_recipes:
            status = "recipe_schema_mismatch"
        else:
            status = "unresolved"
        output.append(
            {
                **metric,
                "coverage_status": status,
                "schema_backed": bool(candidates or ready_recipes),
                "direct_candidates": candidates,
                "recipes": checked_recipes,
            }
        )
    return output


def markdown_report(payload: dict[str, Any]) -> str:
    summary = payload["summary"]
    coverage = payload["metric_coverage"]
    lines = [
        "# NBA API metric coverage audit",
        "",
        f"- nba_api version: `{payload['nba_api_version']}`",
        f"- endpoint classes discovered: **{summary['endpoint_classes']}**",
        f"- result sets discovered: **{summary['result_sets']}**",
        f"- unique result columns discovered: **{summary['unique_columns']}**",
        f"- Sports Terminal metrics: **{summary['metrics']}**",
        f"- exact alias-backed metrics: **{summary['direct_alias_metrics']}**",
        f"- recipe-backed metrics: **{summary['recipe_supported_metrics']}**",
        f"- total schema-backed metrics: **{summary['schema_backed_metrics']}**",
        f"- candidate-only metrics: **{summary['candidate_only_metrics']}**",
        f"- unresolved / recipe-mismatch metrics: **{summary['unresolved_metrics']}**",
        f"- recipe schema errors: **{summary['recipe_schema_errors']}**",
        "",
        "Display labels are deliberately excluded from exact matching so punctuation stripping cannot turn STL% into STL or AST% into AST. Recipe-backed coverage means the declared endpoint/result-set fields needed by a reviewed Sports Terminal transform exist in the pinned nba_api schema; it does not mean live historical availability has already been validated.",
        "",
        "## Priority endpoint families",
        "",
    ]
    discovered_classes = {item["class"] for item in payload["endpoint_inventory"]}
    for group, hints in PRIORITY_ENDPOINT_HINTS.items():
        rendered = [
            f"`{hint}`{' ✓' if hint in discovered_classes else ' ?'}"
            for hint in hints
        ]
        lines.append(
            f"- **{group}:** {', '.join(rendered) if rendered else 'No native endpoint expected; use another source/model.'}"
        )

    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for metric in coverage:
        grouped[metric["group"]].append(metric)
    lines.extend(["", "## Metric coverage", ""])
    for group in sorted(grouped):
        lines.append(f"### {group}")
        lines.append("")
        for metric in grouped[group]:
            status = metric["coverage_status"]
            if status == "direct_alias":
                candidates = metric["direct_candidates"][:4]
                locations = ", ".join(
                    f"`{item['class']}.{item['dataset']}:{item['column']}`"
                    for item in candidates
                )
                extra = len(metric["direct_candidates"]) - len(candidates)
                if extra > 0:
                    locations += f" (+{extra} more)"
                lines.append(f"- **{metric['short_label']}** — exact schema alias — {locations}")
            elif status in {"recipe_supported", "candidate_only"}:
                recipe = next(
                    item for item in metric["recipes"] if item.get("schema_supported")
                )
                prefix = "recipe" if status == "recipe_supported" else "candidate recipe"
                lines.append(
                    f"- **{metric['short_label']}** — {prefix} — `{recipe['endpoint']}.{recipe['dataset']}` — {recipe.get('operation', 'transform')}"
                )
            elif status == "recipe_schema_mismatch":
                errors = "; ".join(
                    str(item.get("schema_error"))
                    for item in metric["recipes"]
                    if item.get("schema_error")
                )
                lines.append(f"- **{metric['short_label']}** — recipe schema mismatch — {errors}")
            else:
                lines.append(f"- **{metric['short_label']}** — unresolved")
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--catalog",
        type=Path,
        default=Path("lib/services/nba_stats_metric_catalog.dart"),
    )
    parser.add_argument(
        "--recipes",
        type=Path,
        default=Path("assets/data/nba/metadata/nba_api_metric_recipes.json"),
    )
    parser.add_argument(
        "--output-json",
        type=Path,
        default=Path("artifacts/nba_api_metric_coverage.json"),
    )
    parser.add_argument(
        "--output-markdown",
        type=Path,
        default=Path("artifacts/nba_api_metric_coverage.md"),
    )
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    metrics = parse_metric_catalog(args.catalog)
    recipes = load_recipes(args.recipes)
    version, inventory = inventory_nba_api()
    coverage = build_coverage(metrics, inventory, recipes)

    endpoint_classes = {item["class"] for item in inventory if item["class"]}
    columns = {
        normalize(column)
        for item in inventory
        if not item.get("error")
        for column in item["columns"]
        if normalize(column)
    }
    direct_alias = sum(1 for item in coverage if item["coverage_status"] == "direct_alias")
    recipe_supported = sum(1 for item in coverage if item["coverage_status"] == "recipe_supported")
    schema_backed = sum(1 for item in coverage if item["schema_backed"])
    candidate_only = sum(1 for item in coverage if item["coverage_status"] == "candidate_only")
    recipe_errors = sum(
        1
        for item in coverage
        for recipe in item["recipes"]
        if not recipe.get("schema_supported")
    )
    unresolved = len(metrics) - schema_backed - candidate_only
    payload = {
        "nba_api_version": version,
        "summary": {
            "endpoint_classes": len(endpoint_classes),
            "result_sets": sum(1 for item in inventory if not item.get("error")),
            "unique_columns": len(columns),
            "metrics": len(metrics),
            "direct_alias_metrics": direct_alias,
            "recipe_supported_metrics": recipe_supported,
            "schema_backed_metrics": schema_backed,
            "candidate_only_metrics": candidate_only,
            "unresolved_metrics": unresolved,
            "recipe_schema_errors": recipe_errors,
            "module_import_errors": sum(1 for item in inventory if item.get("error")),
        },
        "priority_endpoint_hints": PRIORITY_ENDPOINT_HINTS,
        "metric_coverage": coverage,
        "endpoint_inventory": inventory,
    }

    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_markdown.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(
        json.dumps(payload, indent=2, sort_keys=True),
        encoding="utf-8",
    )
    args.output_markdown.write_text(markdown_report(payload), encoding="utf-8")

    print(json.dumps(payload["summary"], indent=2, sort_keys=True))
    print(f"JSON: {args.output_json}")
    print(f"Markdown: {args.output_markdown}")

    if args.check:
        if len(metrics) < 150:
            print("Metric catalog unexpectedly small", file=sys.stderr)
            return 2
        if not endpoint_classes:
            print("No nba_api endpoint schemas discovered", file=sys.stderr)
            return 3
        if schema_backed < 60:
            print(
                f"Too few Sports Terminal metrics are schema-backed: {schema_backed}",
                file=sys.stderr,
            )
            return 4
        if recipe_errors:
            print(
                f"NBA API recipe schema validation found {recipe_errors} error(s)",
                file=sys.stderr,
            )
            return 5
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
