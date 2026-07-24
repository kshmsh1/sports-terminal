from __future__ import annotations

import json
import os
from functools import lru_cache
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException, Query

router = APIRouter(prefix="/v2/nba", tags=["nba-data"])

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_RELEASE_ROOT = REPOSITORY_ROOT / "assets" / "data" / "nba" / "terminal_seed"
ALLOWED_DATASETS = {
    "players": "players.json",
    "games": "games.json",
    "team-records": "team_records.json",
    "team-game-logs": "team_game_logs.json",
    "player-season-totals": "player_season_totals.json",
    "player-game-logs": "player_game_logs.json",
    "standings": "standings.json",
    "search": "search_index.json",
}


def _release_root() -> Path:
    configured = os.getenv("SPORTS_TERMINAL_NBA_RELEASE_ROOT")
    return Path(configured).expanduser().resolve() if configured else DEFAULT_RELEASE_ROOT


def _season_end_year(season: str) -> int:
    normalized = season.strip().replace("–", "-")
    parts = normalized.split("-")
    if len(parts) == 2 and len(parts[0]) == 4:
        end_suffix = int(parts[1])
        century = int(parts[0][:2]) * 100
        end_year = century + end_suffix
        if end_year <= int(parts[0]):
            end_year += 100
        return end_year
    if normalized.isdigit() and len(normalized) == 4:
        return int(normalized)
    raise HTTPException(status_code=400, detail="Season must use 2025-26 or 2026 format")


def _season_path(season: str) -> Path:
    end_year = _season_end_year(season)
    path = _release_root() / f"nba_{end_year}"
    if not path.exists():
        raise HTTPException(
            status_code=404,
            detail=f"Certified NBA release is not installed for {end_year - 1}-{str(end_year)[-2:]}",
        )
    return path


@lru_cache(maxsize=64)
def _load_document(path_text: str, modified_ns: int) -> Any:
    del modified_ns
    path = Path(path_text)
    return json.loads(path.read_text(encoding="utf-8"))


def _load(path: Path) -> Any:
    if not path.exists():
        raise HTTPException(status_code=404, detail=f"Dataset file is missing: {path.name}")
    stat = path.stat()
    return _load_document(str(path), stat.st_mtime_ns)


def _release_metadata(path: Path) -> dict[str, Any]:
    release = _load(path / "release_manifest.json") if (path / "release_manifest.json").exists() else {}
    validation = _load(path / "launch_validation.json") if (path / "launch_validation.json").exists() else {}
    manifest = _load(path / "manifest.json") if (path / "manifest.json").exists() else {}
    return {
        "release": release if isinstance(release, dict) else {},
        "validation": validation if isinstance(validation, dict) else {},
        "manifest": manifest if isinstance(manifest, dict) else {},
        "directory": str(path),
    }


def _text(row: dict[str, Any], fields: list[str]) -> str:
    return " ".join(str(row.get(field) or "") for field in fields).lower()


def _number(value: Any) -> float | None:
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).replace(",", ""))
    except (TypeError, ValueError):
        return None


def _filter_rows(
    rows: list[dict[str, Any]],
    *,
    query: str,
    player_id: str,
    team_id: str,
    game_id: str,
    date_from: str,
    date_to: str,
) -> list[dict[str, Any]]:
    query_value = query.strip().lower()
    player_value = player_id.strip().lower()
    team_value = team_id.strip().upper()
    game_value = game_id.strip().lower()
    output: list[dict[str, Any]] = []
    for row in rows:
        if player_value and str(row.get("player_id") or "").lower() != player_value:
            continue
        row_teams = {
            str(row.get("team_id") or "").upper(),
            str(row.get("team_ids") or "").upper(),
            str(row.get("home_team_id") or "").upper(),
            str(row.get("away_team_id") or "").upper(),
            str(row.get("opponent_team_id") or "").upper(),
        }
        if team_value and not any(team_value in value for value in row_teams):
            continue
        if game_value and str(row.get("game_id") or "").lower() != game_value:
            continue
        row_date = str(row.get("game_date") or row.get("date") or "")
        if date_from and row_date and row_date < date_from:
            continue
        if date_to and row_date and row_date > date_to:
            continue
        if query_value and query_value not in _text(
            row,
            [
                "player_id",
                "player_name",
                "player_label",
                "team_id",
                "team_ids",
                "team_name",
                "game_id",
                "home_team_id",
                "away_team_id",
                "opponent_team_id",
                "label",
                "subtitle",
            ],
        ):
            continue
        output.append(row)
    return output


def _sort_rows(
    rows: list[dict[str, Any]],
    sort: str,
    descending: bool,
) -> list[dict[str, Any]]:
    if not sort:
        return rows

    def key(row: dict[str, Any]):
        value = row.get(sort)
        numeric = _number(value)
        return (numeric is not None, numeric if numeric is not None else str(value or ""))

    return sorted(rows, key=key, reverse=descending)


@router.get("/{season}/release")
def get_release(season: str) -> dict[str, Any]:
    path = _season_path(season)
    metadata = _release_metadata(path)
    release = metadata["release"]
    validation = metadata["validation"]
    return {
        "season": season,
        "status": release.get("status") or "development",
        "version": release.get("version"),
        "generated_at": release.get("generatedAt") or release.get("generated_at"),
        "validation_status": validation.get("status") or release.get("validation", {}).get("status"),
        "counts": release.get("counts") or metadata["manifest"].get("counts") or {},
        "files": sorted(path.name for path in path.glob("*.json")),
        "source_notes": release.get("sourceNotes") or release.get("source_notes") or [],
    }


@router.get("/{season}/{dataset}")
def query_dataset(
    season: str,
    dataset: str,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=1000),
    query: str = "",
    player_id: str = "",
    team_id: str = "",
    game_id: str = "",
    date_from: str = "",
    date_to: str = "",
    sort: str = "",
    descending: bool = True,
) -> dict[str, Any]:
    filename = ALLOWED_DATASETS.get(dataset)
    if filename is None:
        raise HTTPException(
            status_code=404,
            detail=f"Unknown NBA dataset. Supported values: {', '.join(sorted(ALLOWED_DATASETS))}",
        )
    path = _season_path(season)
    document = _load(path / filename)
    if not isinstance(document, list):
        raise HTTPException(status_code=500, detail=f"Dataset is not a row collection: {filename}")
    rows = [
        item
        for item in document
        if isinstance(item, dict)
    ]
    filtered = _filter_rows(
        rows,
        query=query,
        player_id=player_id,
        team_id=team_id,
        game_id=game_id,
        date_from=date_from,
        date_to=date_to,
    )
    ordered = _sort_rows(filtered, sort, descending)
    page = ordered[offset : offset + limit]
    metadata = _release_metadata(path)
    release = metadata["release"]
    return {
        "season": season,
        "dataset": dataset,
        "source_file": filename,
        "release_id": release.get("id"),
        "release_version": release.get("version"),
        "release_status": release.get("status") or "development",
        "total_rows": len(rows),
        "matched_rows": len(ordered),
        "offset": offset,
        "limit": limit,
        "next_offset": offset + limit if offset + limit < len(ordered) else None,
        "rows": page,
    }
