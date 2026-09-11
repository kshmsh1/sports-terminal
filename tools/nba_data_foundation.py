from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]

DATA_FOUNDATION_CONTRACT = "sports-terminal-nba-data-foundation-v1"

_PROVIDER_SPECS: tuple[dict[str, Any], ...] = (
    {
        "key": "canonical_warehouse",
        "label": "Sports Terminal canonical NBA warehouse",
        "role": "primary_canonical",
        "acquisition": "local_database",
        "runtime_network_required": False,
        "capabilities": [
            "canonical players and teams",
            "seasons and games",
            "player-season statistics",
            "team-season statistics",
            "historical cross-era identity",
        ],
        "coverage": {
            "policy": "derived_from_compiled_static_manifest",
            "note": "The browser consumes compiled static JSON, not SQLite directly.",
        },
        "path_kind": "database",
    },
    {
        "key": "nba_com_captures",
        "label": "NBA.com Stats authorized historical captures",
        "role": "official_enrichment",
        "acquisition": "user_captured_json_then_local_materialization",
        "runtime_network_required": False,
        "capabilities": [
            "traditional player aggregates",
            "advanced player aggregates",
            "misc/scoring/usage/defense aggregates",
            "hustle statistics",
            "defensive matchup statistics",
            "advanced game logs",
            "team aggregates",
            "lineups",
        ],
        "coverage": {
            "player_general": "1996-97 through 2025-26 where locally captured",
            "defense_dashboard": "2013-14 through 2025-26 where locally captured",
            "hustle": "2015-16 through 2025-26 where locally captured",
            "season_leaders": "1951-52 through 2025-26 where locally captured",
        },
        "path_kind": "nba_com",
    },
    {
        "key": "sportsdataverse_releases",
        "label": "SportsDataverse / hoopR NBA release datasets",
        "role": "bulk_historical_release",
        "acquisition": "prebuilt_release_download",
        "runtime_network_required": False,
        "capabilities": [
            "play-by-play",
            "possessions",
            "lineups",
            "shots",
            "schedules",
            "box scores",
            "rosters",
            "standings",
            "player and team season stats",
            "officials and draft data",
        ],
        "coverage": {
            "policy": "dataset-specific",
            "note": "Release loaders are acquisition-time tools; imported files are consumed locally afterward.",
        },
        "path_kind": "sportsdataverse",
    },
    {
        "key": "pbpstats_cache",
        "label": "pbpstats enhanced play-by-play cache",
        "role": "possession_and_event_enrichment",
        "acquisition": "predownloaded_file_cache",
        "runtime_network_required": False,
        "capabilities": [
            "enhanced play-by-play",
            "lineups on floor",
            "possession boundaries",
            "shot-zone event context",
            "possession start/end state",
        ],
        "coverage": {
            "policy": "cache-specific",
            "note": "Sports Terminal only inventories and imports files already present on disk.",
        },
        "path_kind": "pbpstats",
    },
    {
        "key": "basketball_reference",
        "label": "Basketball-Reference historical reference layer",
        "role": "historical_backfill_and_crosscheck",
        "acquisition": "explicit_import_or_scrape_then_local_materialization",
        "runtime_network_required": False,
        "capabilities": [
            "season totals",
            "advanced season totals",
            "schedules",
            "standings",
            "player game logs",
            "shooting splits",
            "rosters",
            "contracts where available",
        ],
        "coverage": {
            "policy": "import-specific",
            "note": "Existing Sports Terminal source-index mapping resolves provider identities to canonical entities.",
        },
        "path_kind": "basketball_reference",
    },
    {
        "key": "manual_awards",
        "label": "Curated NBA awards and honors supplement",
        "role": "historical_awards_backfill",
        "acquisition": "curated_static_source",
        "runtime_network_required": False,
        "capabilities": [
            "annual awards",
            "All-Star Game MVP",
            "conference finals MVP",
            "NBA Cup honors",
            "player honor history",
        ],
        "coverage": {
            "policy": "supplement_plus_canonical",
            "note": "Rows are merged into history/awards.json and canonical player dossiers during static compilation.",
        },
        "path_kind": "internal",
    },
)

_SOURCE_PRECEDENCE: dict[str, list[str]] = {
    "identity": ["canonical_warehouse", "basketball_reference"],
    "traditional_player_season": [
        "canonical_warehouse",
        "nba_com_captures",
        "basketball_reference",
    ],
    "advanced_player_season": [
        "nba_com_captures",
        "canonical_warehouse",
        "basketball_reference",
    ],
    "team_season": [
        "canonical_warehouse",
        "nba_com_captures",
        "sportsdataverse_releases",
    ],
    "games_and_box_scores": [
        "canonical_warehouse",
        "sportsdataverse_releases",
        "nba_com_captures",
        "basketball_reference",
    ],
    "play_by_play": [
        "canonical_warehouse",
        "sportsdataverse_releases",
        "pbpstats_cache",
        "basketball_reference",
    ],
    "possessions_and_lineups": [
        "sportsdataverse_releases",
        "pbpstats_cache",
        "nba_com_captures",
    ],
    "awards": ["canonical_warehouse", "manual_awards"],
}

def _load_json(path: Path, fallback: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return fallback

def _first_existing(candidates: tuple[Path, ...]) -> Path | None:
    for candidate in candidates:
        if candidate.exists():
            return candidate.resolve()
    return None

def _file_inventory(root: Path | None) -> dict[str, Any]:
    if root is None or not root.exists():
        return {
            "available": False,
            "path": None,
            "file_count": 0,
            "json_files": 0,
            "parquet_files": 0,
            "sqlite_files": 0,
        }
    files = [item for item in root.rglob("*") if item.is_file()]
    return {
        "available": bool(files),
        "path": str(root),
        "file_count": len(files),
        "json_files": sum(item.suffix.lower() == ".json" for item in files),
        "parquet_files": sum(item.suffix.lower() in {".parquet", ".pq"} for item in files),
        "sqlite_files": sum(item.suffix.lower() in {".sqlite", ".sqlite3", ".db"} for item in files),
    }

def _nba_com_inventory(project_root: Path, parent_root: Path) -> dict[str, Any]:
    root = _first_existing(
        (
            project_root / "raw" / "nba_com_stats",
            parent_root / "raw" / "nba_com_stats",
        )
    )
    inventory = _file_inventory(root)
    if root is not None:
        normalized = root / "normalized"
        if normalized.exists():
            normalized_files = [
                path for path in normalized.rglob