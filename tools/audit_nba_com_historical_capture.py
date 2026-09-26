from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / "assets/data/nba/metadata/nba_com_capture_plan_part1.json"
FETCHER = ROOT / "tools/fetch_nba_com_historical_stats.py"


def load_fetcher():
    spec = importlib.util.spec_from_file_location("sports_terminal_nba_com_fetcher_audit", FETCHER)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load collector module: {FETCHER}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def expected_scopes(plan_path: Path) -> set[str]:
    fetcher = load_fetcher()
    payload, surfaces = fetcher.load_plan(plan_path)
    bounds = payload.get("season_range") or {}
    seasons = fetcher.seasons_between(
        str(bounds.get("from") or "1946-47"),
        str(bounds.get("to") or "2025-26"),
    )
    season_types = list(payload.get("season_types") or ["Regular Season", "Playoffs"])
    return {
        fetcher.coverage_key(surface, variant, season, season_type)
        for season in seasons
        for surface in surfaces
        for variant in surface.variants
        for season_type in season_types
    }


def actual_scopes(root: Path) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    if not root.is_dir():
        return result
    for path in root.glob("*/*/*/*/metadata.json"):
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if not isinstance(payload, dict):
            continue
        surface = str(payload.get("surface") or "")
        variant = str(payload.get("variant") or "")
        season = str(payload.get("season") or "")
        season_type = "playoffs" if "play" in str(payload.get("season_type") or "").lower() else "regular"
        key = f"{surface}/{variant}/{season}/{season_type}"
        payload["_metadata_path"] = str(path)
        result[key] = payload
    return result


def summarize(plan_path: Path, root: Path) -> dict[str, Any]:
    expected = expected_scopes(plan_path)
    actual = actual_scopes(root)
    missing = sorted(expected - set(actual))
    unexpected = sorted(set(actual) - expected)
    statuses: dict[str, int] = {}
    rows = 0
    bad: list[dict[str, Any]] = []
    complete_statuses = {"success", "empty", "unavailable"}
    for key in sorted(expected & set(actual)):
        item = actual[key]
        status = str(item.get("validation_status") or "unknown")
        statuses[status] = statuses.get(status, 0) + 1
        rows += int(item.get("row_count") or 0)
        if status not in complete_statuses:
            bad.append({
                "scope": key,
                "status": status,
                "error": item.get("error"),
                "validation_errors": item.get("validation_errors") or [],
                "metadata_path": item.get("_metadata_path"),
            })
    return {
        "contract": "sports-terminal-nba-com-historical-capture-audit-v1",
        "plan": str(plan_path),
        "root": str(root),
        "expected_scopes": len(expected),
        "recorded_scopes": len(expected & set(actual)),
        "missing_scopes": len(missing),
        "unexpected_scopes": len(unexpected),
        "status_counts": statuses,
        "row_count": rows,
        "complete": not missing and not bad,
        "missing_examples": missing[:50],
        "unexpected_examples": unexpected[:50],
        "bad_examples": bad[:50],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit completeness of the NBA.com Part 1 historical capture corpus.")
    parser.add_argument("--plan", type=Path, default=PLAN)
    parser.add_argument("--root", type=Path, default=ROOT / "raw/nba_com_stats")
    parser.add_argument("--require-complete", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    summary = summarize(args.plan.expanduser().resolve(), args.root.expanduser().resolve())
    rendered = json.dumps(summary, indent=2, sort_keys=True)
    print(rendered)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    return 1 if args.require_complete and not summary["complete"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
