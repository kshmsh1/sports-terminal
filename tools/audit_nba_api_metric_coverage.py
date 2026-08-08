#!/usr/bin/env python3
"""Inventory nba_api endpoint schemas and match them to Sports Terminal metrics.

This script intentionally does not call stats.nba.com. It reads the endpoint schema
metadata shipped by the installed ``nba_api`` package, inventories every declared
result set/column, parses the Sports Terminal Dart metric registry, and emits a
coverage report showing which metric columns have direct NBA API candidates.

A separate ingestion step can then target the high-yield endpoints instead of
blindly hammering hundreds of NBA.com endpoints.
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
    "gp": ["GP"],
    "min": ["MIN", "MINUTES"],
    "pts": ["PTS"],
    "reb": ["REB"],
    "oreb": ["OREB"],
    "dreb": ["DREB"],
    "ast": ["AST"],
    "stl": ["STL"],
    "blk": ["BLK"],
    "tov": ["TOV", "TO"],
    "pf": ["PF"],
    "fgm": ["FGM"],
    "fga": ["FGA"],
    "fg_pct": ["FG_PCT", "FGPCT"],
    "three_pm": ["FG3M", "3PM", "THREE_PM"],
    "three_pa": ["FG3A", "3PA", "THREE_PA"],
    "three_pct": ["FG3_PCT", "3P_PCT", "THREE_PCT"],
    "ftm": ["FTM"],
    "fta": ["FTA"],
    "ft_pct": ["FT_PCT", "FTPCT"],
    "efg_pct": ["EFG_PCT", "E_FG_PCT"],
    "ts_pct": ["TS_PCT", "TSPCT"],
    "ft_rate": ["FTA_RATE", "FT_RATE"],
    "three_rate": ["FG3A_RATE", "THREE_RATE", "3PA_RATE"],
    "bpm": ["BPM"],
    "ast_tov": ["AST_TO", "AST_TOV", "AST_TO_RATIO"],
}


PRIORITY_ENDPOINT_HINTS: dict[str, list[str]] = {
    "Basic": ["LeagueDashPlayerStats", "PlayerGameLogs"],
    "Defense": ["LeagueHustleStatsPlayer", "LeagueDashPtDefend", "LeagueDashPtStats"],
    "Playmaking": ["LeagueDashPtStats", "PlayerDashPtPass"],
    "Rebounding": ["LeagueDashPtStats", "PlayerDashPtReb"],
    "Efficiency": ["LeagueDashPlayerStats", "PlayerEstimatedMetrics"],
    "Impact": ["LeagueDashPlayerStats", "PlayerEstimatedMetrics", "TeamPlayerOnOffSummary"],
    "Aggregate": ["PlayerEstimatedMetrics"],
    "Movement": ["LeagueDashPtStats"],
    "Clutch": ["LeagueDashPlayerClutch", "PlayerDashboardByClutch"],
    "Shot Profile": ["LeagueDashPlayerPtShot", "LeagueDashPlayerShotLocations", "ShotChartDetail"],
    "Play Type": ["SynergyPlayTypes"],
    "Creation": ["GravityLeaders", "LeagueDashPtStats"],
    "Physical": ["LeagueDashPlayerBioStats", "DraftCombineStats"],
    "Discipline": ["LeagueHustleStatsPlayer", "PlayByPlayV3"],
    "Availability": [],
}


METRIC_RE = re.compile(
    r"^\s*_m\('(?P<key>[^']+)',\s*'(?P<label>[^']*)',\s*'(?P<short>[^']*)',\s*'(?P<group>[^']*)'"
)
RAW_RE = re.compile(r"raw:\s*\[([^\]]*)\]")
ENGINE_RE = re.compile(r"engineKey:\s*'([^']+)'")
QUOTED_RE = re.compile(r"'([^']+)'" )


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
        aliases = [
            match.group("key"),
            match.group("short"),
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
        except Exception as exc:  # endpoint modules should not block the rest of the audit
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


def build_coverage(
    metrics: list[dict[str, Any]],
    inventory: list[dict[str, Any]],
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
        output.append({**metric, "matched": bool(candidates), "candidates": candidates})
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
        f"- direct schema matches: **{summary['matched_metrics']}**",
        f"- unresolved by direct alias: **{summary['unmatched_metrics']}**",
        "",
        "Direct match means at least one declared nba_api result column matches a Sports Terminal key, source alias, short label, or known engine alias after normalization. It does not guarantee that the NBA endpoint currently returns data for every season.",
        "",
        "## Priority endpoint families",
        "",
    ]
    discovered_classes = {item["class"] for item in payload["endpoint_inventory"]}
    for group, hints in PRIORITY_ENDPOINT_HINTS.items():
        rendered = []
        for hint in hints:
            rendered.append(f"`{hint}`{' ✓' if hint in discovered_classes else ' ?'}")
        lines.append(f"- **{group}:** {', '.join(rendered) if rendered else 'No native endpoint expected; use another source/model.'}")

    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for metric in coverage:
        grouped[metric["group"]].append(metric)
    lines.extend(["", "## Metric coverage", ""])
    for group in sorted(grouped):
        lines.append(f"### {group}")
        lines.append("")
        for metric in grouped[group]:
            if metric["matched"]:
                candidates = metric["candidates"][:5]
                locations = ", ".join(
                    f"`{item['class']}.{item['dataset']}:{item['column']}`"
                    for item in candidates
                )
                extra = len(metric["candidates"]) - len(candidates)
                if extra > 0:
                    locations += f" (+{extra} more)"
                lines.append(f"- **{metric['short_label']}** — {locations}")
            else:
                lines.append(f"- **{metric['short_label']}** — unresolved by direct schema alias")
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
    version, inventory = inventory_nba_api()
    coverage = build_coverage(metrics, inventory)

    endpoint_classes = {item["class"] for item in inventory if item["class"]}
    columns = {
        normalize(column)
        for item in inventory
        if not item.get("error")
        for column in item["columns"]
        if normalize(column)
    }
    matched = sum(1 for metric in coverage if metric["matched"])
    payload = {
        "nba_api_version": version,
        "summary": {
            "endpoint_classes": len(endpoint_classes),
            "result_sets": sum(1 for item in inventory if not item.get("error")),
            "unique_columns": len(columns),
            "metrics": len(metrics),
            "matched_metrics": matched,
            "unmatched_metrics": len(metrics) - matched,
            "module_import_errors": sum(1 for item in inventory if item.get("error")),
        },
        "priority_endpoint_hints": PRIORITY_ENDPOINT_HINTS,
        "metric_coverage": coverage,
        "endpoint_inventory": inventory,
    }

    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_markdown.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
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
        if matched < 20:
            print("Too few Sports Terminal metrics matched NBA API schemas", file=sys.stderr)
            return 4
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
