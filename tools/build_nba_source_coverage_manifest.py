from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]


def _read_json(path: Path) -> Any:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def _count_files(root: Path, suffixes: tuple[str, ...]) -> int:
    if not root.is_dir():
        return 0
    return sum(
        1
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in suffixes
    )


def _dataset_rows(manifest: Any) -> list[dict[str, Any]]:
    if not isinstance(manifest, dict):
        return []
    rows = manifest.get("datasets") or []
    return [row for row in rows if isinstance(row, dict)]


def _season_bounds(rows: list[dict[str, Any]]) -> tuple[int | None, int | None]:
    years: set[int] = set()
    for row in rows:
        season_end_year = row.get("season_end_year")
        if isinstance(season_end_year, int):
            years.add(season_end_year)
        for value in row.get("seasons") or []:
            if isinstance(value, int):
                years.add(value)
    ordered = sorted(years)
    return (ordered[0], ordered[-1]) if ordered else (None, None)


def _sportsdataverse_summary(root: Path) -> dict[str, Any]:
    manifest = _read_json(root / "manifest.json")
    rows = _dataset_rows(manifest)
    datasets = sorted(
        {str(row.get("dataset")) for row in rows if row.get("dataset")}
    )
    lo, hi = _season_bounds(rows)
    return {
        "id": "sportsdataverse",
        "label": "SportsDataverse / hoopR release data",
        "role": "bulk historical release datasets and cross-check source",
        "runtime_dependency": False,
        "root": str(root),
        "available": bool(
            rows or _count_files(root, (".parquet", ".json", ".csv"))
        ),
        "dataset_count": len(datasets),
        "datasets": datasets,
        "season_end_year_min": lo,
        "season_end_year_max": hi,
        "files": _count_files(root, (".parquet", ".json", ".csv")),
        "recommended_surfaces": [
            "play_by_play",
            "possessions",
            "lineups",
            "shots",
            "rosters",
            "boxscores",
            "game_logs",
            "league_dash",
            "standings",
            "officials",
            "coaches",
            "draft",
        ],
    }


def _basketball_reference_summary(root: Path) -> dict[str, Any]:
    manifest = _read_json(root / "manifest.json")
    rows = _dataset_rows(manifest)
    datasets = sorted(
        {str(row.get("dataset")) for row in rows if row.get("dataset")}
    )
    lo, hi = _season_bounds(rows)
    return {
        "id": "basketball_reference",
        "label": "Basketball-Reference",
        "role": "historical reference, advanced metrics, shooting, schedules, rosters, contracts and game logs",
        "runtime_dependency": False,
        "root": str(root),
        "available": bool(
            rows
            or _count_files(root, (".json", ".csv", ".sqlite", ".sqlite3", ".db"))
        ),
        "dataset_count": len(datasets),
        "datasets": datasets,
        "season_end_year_min": lo,
        "season_end_year_max": hi,
        "files": _count_files(
            root, (".json", ".csv", ".sqlite", ".sqlite3", ".db")
        ),
        "recommended_surfaces": [
            "season_schedule",
            "player_totals",
            "player_advanced",
            "standings",
            "shooting",
            "regular_game_logs",
            "playoff_game_logs",
            "rosters",
            "current_contracts",
        ],
    }


def _nba_com_summary(root: Path, static_root: Path) -> dict[str, Any]:
    normalized_files = _count_files(root, (".json",))
    static_manifest = _read_json(static_root / "manifest.json")
    enrichment = (
        static_manifest.get("nba_com_enrichment")
        if isinstance(static_manifest, dict)
        else None
    )
    if not isinstance(enrichment, dict):
        enrichment = {}
    return {
        "id": "nba_com",
        "label": "NBA.com Stats",
        "role": "official player/team/lineup advanced, tracking, hustle and defended-shooting surfaces",
        "runtime_dependency": False,
        "root": str(root),
        "available": normalized_files > 0 or bool(enrichment),
        "normalized_capture_files": normalized_files,
        "materialized_player_season_rows": int(
            enrichment.get("enriched_player_rows") or 0
        ),
        "matched_source_rows": int(enrichment.get("matched_source_rows") or 0),
        "unmatched_source_rows": int(
            enrichment.get("unmatched_source_rows") or 0
        ),
        "recommended_surfaces": [
            "base",
            "advanced",
            "misc",
            "scoring",
            "usage",
            "estimated_advanced",
            "hustle",
            "defended_shooting",
            "lineups",
            "tracking",
        ],
    }


def _pbpstats_summary(root: Path) -> dict[str, Any]:
    return {
        "id": "pbpstats",
        "label": "pbpstats",
        "role": "event-order repair, enhanced play-by-play and possession derivation",
        "runtime_dependency": False,
        "root": str(root),
        "available": _count_files(root, (".json", ".txt", ".csv")) > 0,
        "files": _count_files(root, (".json", ".txt", ".csv")),
        "recommended_surfaces": [
            "raw_pbp",
            "enhanced_pbp",
            "possessions",
            "on_court_lineups",
            "shot_zone_events",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Build a static source-coverage manifest for the Sports Terminal NBA data layer."
        )
    )
    parser.add_argument(
        "--output",
        default=str(ROOT / "web" / "data" / "nba_static" / "source_coverage.json"),
    )
    parser.add_argument(
        "--static-root", default=str(ROOT / "web" / "data" / "nba_static")
    )
    parser.add_argument("--nba-com-root", default=str(ROOT / "raw" / "nba_com"))
    parser.add_argument(
        "--sportsdataverse-root",
        default=str(ROOT / "raw" / "sportsdataverse" / "nba"),
    )
    parser.add_argument(
        "--basketball-reference-root",
        default=str(ROOT / "raw" / "basketball_reference"),
    )
    parser.add_argument(
        "--pbpstats-root", default=str(ROOT / "raw" / "pbpstats")
    )
    args = parser.parse_args()

    static_root = Path(args.static_root).expanduser().resolve()
    nba_com_root = Path(args.nba_com_root).expanduser().resolve()
    sportsdataverse_root = Path(args.sportsdataverse_root).expanduser().resolve()
    basketball_reference_root = (
        Path(args.basketball_reference_root).expanduser().resolve()
    )
    pbpstats_root = Path(args.pbpstats_root).expanduser().resolve()

    sources = [
        _nba_com_summary(nba_com_root, static_root),
        _sportsdataverse_summary(sportsdataverse_root),
        _basketball_reference_summary(basketball_reference_root),
        _pbpstats_summary(pbpstats_root),
    ]

    manifest = {
        "contract": "sports-terminal-nba-source-coverage-v1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "architecture": {
            "historical_runtime": "static-first",
            "browser_runtime_external_scraping_required": False,
            "canonical_entity_graph_required": True,
            "source_precedence": [
                "canonical_warehouse",
                "official_nba_com_static_capture",
                "sportsdataverse_release",
                "basketball_reference_supplement",
                "pbpstats_possession_derivation",
            ],
            "missing_values_policy": "preserve-column-and-render-dash",
        },
        "sources": sources,
        "available_source_count": sum(
            1 for source in sources if source.get("available")
        ),
    }

    output = Path(args.output).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "status": "ok",
                "output": str(output),
                "available_sources": manifest["available_source_count"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
