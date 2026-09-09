from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Query

from .user_salary_snapshot import (
    SEASON,
    contract_seed_records,
    snapshot_diagnostics,
    team_position_seed_records,
)

router = APIRouter(prefix="/v2/front-office-snapshot", tags=["front-office-snapshot"])


def _filter(
    rows: list[dict[str, Any]],
    *,
    season: str = "",
    team_id: str = "",
    player_id: str = "",
    source_status: str = "",
    limit: int = 1000,
) -> list[dict[str, Any]]:
    if season and season != SEASON:
        return []
    team = team_id.upper().strip()
    out = [
        row
        for row in rows
        if (not team or row.get("team_id") == team)
        and (not player_id or row.get("player_id") == player_id)
        and (not source_status or row.get("source_status") == source_status)
    ]
    return out[: max(1, min(limit, 1000))]


@router.get("/contracts")
def snapshot_contracts(
    season: str = SEASON,
    team_id: str = "",
    player_id: str = "",
    source_status: str = "",
    limit: int = Query(default=1000, ge=1, le=1000),
) -> list[dict[str, Any]]:
    return _filter(
        contract_seed_records(),
        season=season,
        team_id=team_id,
        player_id=player_id,
        source_status=source_status,
        limit=limit,
    )


@router.get("/team-positions")
def snapshot_team_positions(
    season: str = SEASON,
    team_id: str = "",
    source_status: str = "",
    limit: int = Query(default=100, ge=1, le=1000),
) -> list[dict[str, Any]]:
    return _filter(
        team_position_seed_records(),
        season=season,
        team_id=team_id,
        source_status=source_status,
        limit=limit,
    )


@router.get("/diagnostics")
def snapshot_quality() -> dict[str, Any]:
    return snapshot_diagnostics()
