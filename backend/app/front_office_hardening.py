from __future__ import annotations

from collections.abc import Callable
from typing import Any

from fastapi import HTTPException
from pydantic import BaseModel

from .main import connect


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


def hardened_upsert(
    original_upsert: Callable[..., dict[str, Any]],
    initializer: Callable[[], None],
) -> Callable[..., dict[str, Any]]:
    def upsert(
        record_type: str,
        record_id: str,
        payload: Any,
    ) -> dict[str, Any]:
        initializer()
        with connect() as connection:
            existing = connection.execute(
                "SELECT record_type FROM front_office_records WHERE id = ?",
                (record_id,),
            ).fetchone()
        if existing is not None and existing["record_type"] != record_type:
            raise HTTPException(
                status_code=409,
                detail={
                    "message": "Front-office record IDs cannot change type",
                    "record_id": record_id,
                    "existing_type": existing["record_type"],
                    "requested_type": record_type,
                },
            )
        return original_upsert(record_type, record_id, payload)

    return upsert


def hardened_reconciliation(
    original_reconciliation: Callable[[str, str], dict[str, Any]],
    list_records: Callable[..., list[dict[str, Any]]],
) -> Callable[[str, str], dict[str, Any]]:
    def reconcile(team_id: str, season: str) -> dict[str, Any]:
        result = original_reconciliation(team_id, season)
        normalized_team = team_id.upper()
        all_ledgers = list_records(
            "ledger",
            season=season,
            record_status="active",
            limit=1000,
        )
        matching_ledgers = [
            item
            for item in all_ledgers
            if normalized_team
            in {
                str(team).upper()
                for team in item.get("record", {}).get("teams", [])
            }
        ]
        result["ledger_transaction_count"] = len(matching_ledgers)
        unverified = set(result.get("unverified_record_ids", []))
        unverified.update(
            item["id"]
            for item in matching_ledgers
            if item.get("source_status") != "verified"
        )
        result["unverified_record_ids"] = sorted(unverified)
        blockers = list(result.get("blockers", []))
        if unverified and not any(
            "modeled or uploaded" in blocker for blocker in blockers
        ):
            blockers.append(
                "One or more records are modeled or uploaded rather than verified."
            )
        result["blockers"] = blockers
        result["status"] = "pass" if not blockers else "review"
        return result

    return reconcile
