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
            "note": "Sports Terminal inventories and imports files already present on disk.",
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
            "note": "Provider identities resolve to Sports Terminal canonical entities before serving.",
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
            "All-NBA / All-Defense / All-Rookie team honors",
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
    "shots": [
        "sportsdataverse_releases",
        "nba_com_captures",
        "pbpstats_cache",
        "basketball_reference",
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
            "bytes": 0,
        }
    files = [item for item in root.rglob("*") if item.is_file()]
    return {
        "available": bool(files),
        "path": str(root),
        "file_count": len(files),
        "json_files": sum(item.suffix.lower() == ".json" for item in files),
        "parquet_files": sum(
            item.suffix.lower() in {".parquet", ".pq"} for item in files
        ),
        "sqlite_files": sum(
            item.suffix.lower() in {".sqlite", ".sqlite3", ".db"}
            for item in files
        ),
        "bytes": sum(item.stat().st_size for item in files),
    }


def _nba_com_inventory(project_root: Path, parent_root: Path) -> dict[str, Any]:
    root = _first_existing(
        (
            project_root / "raw" / "nba_com_stats",
            parent_root / "raw" / "nba_com_stats",
        )
    )
    inventory = _file_inventory(root)
    normalized_count = 0
    endpoint_counts: dict[str, int] = {}
    if root is not None:
        normalized = root / "normalized"
        if normalized.is_dir():
            normalized_files = [
                path
                for path in normalized.rglob("*.json")
                if path.is_file()
            ]
            normalized_count = len(normalized_files)
            for path in normalized_files:
                try:
                    relative = path.relative_to(normalized)
                    endpoint = relative.parts[0] if len(relative.parts) > 1 else path.stem
                except Exception:
                    endpoint = path.parent.name or "unknown"
                endpoint_counts[endpoint] = endpoint_counts.get(endpoint, 0) + 1
    inventory.update(
        {
            "normalized_file_count": normalized_count,
            "normalized_endpoint_counts": dict(sorted(endpoint_counts.items())),
        }
    )
    return inventory


def _sportsdataverse_inventory(
    project_root: Path,
    parent_root: Path,
) -> dict[str, Any]:
    root = _first_existing(
        (
            project_root / "raw" / "sportsdataverse" / "nba",
            parent_root / "raw" / "sportsdataverse" / "nba",
        )
    )
    inventory = _file_inventory(root)
    manifest = _load_json(root / "manifest.json", {}) if root is not None else {}
    datasets = manifest.get("datasets") if isinstance(manifest, dict) else []
    if not isinstance(datasets, list):
        datasets = []
    inventory.update(
        {
            "manifest_contract": (
                str(manifest.get("contract") or "")
                if isinstance(manifest, dict)
                else ""
            ),
            "dataset_count": len(datasets),
            "datasets": sorted(
                {
                    str(row.get("dataset"))
                    for row in datasets
                    if isinstance(row, dict) and row.get("dataset")
                }
            ),
        }
    )
    return inventory


def _pbpstats_inventory(project_root: Path, parent_root: Path) -> dict[str, Any]:
    root = _first_existing(
        (
            project_root / "raw" / "pbpstats",
            parent_root / "raw" / "pbpstats",
        )
    )
    inventory = _file_inventory(root)
    cached = _load_json(root / "inventory.json", {}) if root is not None else {}
    if isinstance(cached, dict):
        directories = cached.get("directories")
        readiness = cached.get("readiness")
        inventory.update(
            {
                "inventory_contract": str(cached.get("contract") or ""),
                "resource_directories": directories if isinstance(directories, dict) else {},
                "readiness": readiness if isinstance(readiness, dict) else {},
            }
        )
    return inventory


def _basketball_reference_inventory(
    project_root: Path,
    parent_root: Path,
) -> dict[str, Any]:
    root = _first_existing(
        (
            project_root / "raw" / "basketball_reference",
            parent_root / "raw" / "basketball_reference",
            project_root / "raw" / "historical" / "basketball_reference",
            parent_root / "raw" / "historical" / "basketball_reference",
        )
    )
    inventory = _file_inventory(root)
    manifest = _load_json(root / "manifest.json", {}) if root is not None else {}
    datasets = manifest.get("datasets") if isinstance(manifest, dict) else []
    if not isinstance(datasets, list):
        datasets = []
    inventory.update(
        {
            "manifest_contract": (
                str(manifest.get("contract") or "")
                if isinstance(manifest, dict)
                else ""
            ),
            "dataset_count": len(datasets),
            "datasets": sorted(
                {
                    str(row.get("dataset"))
                    for row in datasets
                    if isinstance(row, dict) and row.get("dataset")
                }
            ),
        }
    )
    return inventory


def _awards_inventory(project_root: Path, output: Path) -> dict[str, Any]:
    history = _load_json(output / "history" / "awards.json", [])
    if not isinstance(history, list):
        history = []
    curated_candidates = (
        project_root / "raw" / "curated" / "nba_awards.json",
        project_root.parent / "raw" / "curated" / "nba_awards.json",
    )
    curated = _first_existing(curated_candidates)
    curated_payload = _load_json(curated, {}) if curated is not None else {}
    curated_rows = (
        curated_payload.get("rows")
        if isinstance(curated_payload, dict)
        else []
    )
    if not isinstance(curated_rows, list):
        curated_rows = []
    return {
        "available": bool(history),
        "path": str(output / "history" / "awards.json"),
        "compiled_rows": len(history),
        "external_curated_path": str(curated) if curated is not None else None,
        "external_curated_rows": len(curated_rows),
    }


def _canonical_inventory(database: Path, output: Path) -> dict[str, Any]:
    inventory = _file_inventory(database.parent if database.exists() else None)
    manifest = _load_json(output / "manifest.json", {})
    seasons = _load_json(output / "seasons.json", [])
    if not isinstance(seasons, list):
        seasons = []
    inventory.update(
        {
            "available": database.is_file() and database.stat().st_size > 0,
            "database_path": str(database),
            "database_bytes": database.stat().st_size if database.is_file() else 0,
            "compiled_contract": (
                str(manifest.get("contract") or manifest.get("schema") or "")
                if isinstance(manifest, dict)
                else ""
            ),
            "compiled_seasons": len(seasons),
        }
    )
    return inventory


def _provider_inventory(
    key: str,
    project_root: Path,
    parent_root: Path,
    output: Path,
    database: Path,
) -> dict[str, Any]:
    if key == "canonical_warehouse":
        return _canonical_inventory(database, output)
    if key == "nba_com_captures":
        return _nba_com_inventory(project_root, parent_root)
    if key == "sportsdataverse_releases":
        return _sportsdataverse_inventory(project_root, parent_root)
    if key == "pbpstats_cache":
        return _pbpstats_inventory(project_root, parent_root)
    if key == "basketball_reference":
        return _basketball_reference_inventory(project_root, parent_root)
    if key == "manual_awards":
        return _awards_inventory(project_root, output)
    return {"available": False}


def build_data_foundation(
    output: Path,
    database: Path,
    *,
    project_root: Path = ROOT,
) -> dict[str, Any]:
    output = output.expanduser().resolve()
    database = database.expanduser().resolve()
    project_root = project_root.expanduser().resolve()
    parent_root = project_root.parent

    providers: list[dict[str, Any]] = []
    for spec in _PROVIDER_SPECS:
        row = dict(spec)
        inventory = _provider_inventory(
            str(spec["key"]),
            project_root,
            parent_root,
            output,
            database,
        )
        row["inventory"] = inventory
        row["available"] = bool(inventory.get("available"))
        providers.append(row)

    payload: dict[str, Any] = {
        "contract": DATA_FOUNDATION_CONTRACT,
        "historical_delivery": "compiled_static_files",
        "runtime_network_required": False,
        "canonicalization_required": True,
        "provider_count": len(providers),
        "available_provider_count": sum(
            1 for provider in providers if provider.get("available") is True
        ),
        "providers": providers,
        "source_precedence": _SOURCE_PRECEDENCE,
        "principles": [
            "provider acquisition is separate from browser rendering",
            "raw source definitions are preserved before canonicalization",
            "canonical entity identity is shared across every product surface",
            "missing metrics remain missing instead of being fabricated",
            "regular season and playoffs remain distinct statistical samples",
            "historical releases are immutable after validation",
        ],
    }
    fingerprint_source = json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    )
    payload["fingerprint"] = hashlib.sha256(
        fingerprint_source.encode("utf-8")
    ).hexdigest()

    target = output / "data_foundation.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return payload


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Build the local-first NBA provider/source foundation manifest."
    )
    parser.add_argument(
        "--output",
        default=str(ROOT / "web" / "data" / "nba_static"),
    )
    parser.add_argument(
        "--database",
        default=str(ROOT / "data" / "warehouse" / "nba_history.sqlite"),
    )
    args = parser.parse_args()
    foundation = build_data_foundation(
        Path(args.output),
        Path(args.database),
    )
    print(
        "NBA data foundation: "
        f"{foundation['available_provider_count']}/{foundation['provider_count']} "
        f"providers available; fingerprint={foundation['fingerprint'][:12]}"
    )
