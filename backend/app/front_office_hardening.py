from __future__ import annotations

from typing import Any

from fastapi import HTTPException
from pydantic import BaseModel


def record_dimensions(
    record_type: str,
    record: BaseModel,
) -> tuple[str, str, str, str]:
    payload: dict[str, Any] = record.model_dump()
    if record_type == "draft_asset":
        draft_year = payload.get("draft_year")
        if draft_year is None:
            raise HTTPException(status_code=422, detail="A draft year is required")
        season = f"draft-{int(draft_year)}"
    else:
        season = str(payload.get("season") or "")
        if not season:
            raise HTTPException(status_code=422, detail="A season is required")
    team_id = str(
        payload.get("team_id")
        or payload.get("current_team_id")
        or ""
    )
    player_id = str(payload.get("player_id") or "")
    organization_id = str(payload.get("organization_id") or "")
    if record_type == "ledger" and not team_id:
        teams = payload.get("teams") or []
        team_id = str(teams[0]) if teams else ""
    return season, team_id, player_id, organization_id
