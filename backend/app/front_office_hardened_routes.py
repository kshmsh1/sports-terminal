from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException

from .front_office_api import (
    RecordUpsert,
    front_office_reconciliation,
    init_front_office_db,
    list_front_office_records,
    upsert_front_office_record,
)
from .main import connect

router = APIRouter(prefix="/v2/front-office", tags=["front-office-hardened"])


def _assert_record_type(record_id: str, record_type: str) -> None:
    init_front_office_db()
    with connect() as connection:
        row = connection.execute(
            "SELECT record_type FROM front_office_records WHERE id = ?",
            (record_id,),
        ).fetchone()
    if row is not None and row["record_type"] != record_type:
        raise HTTPException(
            status_code=409,
            detail={
                "message": "Front-office record IDs cannot change type",
                "record_id": record_id,
                "existing_type": row["record_type"],
                "requested_type": record_type,
            },
        )


def _upsert(
    record_type: str,
    record_id: str,
    payload: RecordUpsert,
) -> dict[str, Any]:
    _assert_record_type(record_id, record_type)
    return upsert_front_office_record(record_type, record_id, payload)


@router.put("/contracts/{record_id}")
def upsert_contract_hardened(
    record_id: str,
    payload: RecordUpsert,
) -> dict[str, Any]:
    return _upsert("contract", record_id, payload)


@router.put("/team-positions/{record_id}")
def upsert_team_position_hardened(
    record_id: str,
    payload: RecordUpsert,
) -> dict[str, Any]:
    return _upsert("team_position", record_id, payload)


@router.put("/draft-assets/{record_id}")
def upsert_draft_asset_hardened(
    record_id: str,
    payload: RecordUpsert,
) -> dict[str, Any]:
    return _upsert("draft_asset", record_id, payload)


@router.put("/ledger/{record_id}")
def upsert_ledger_hardened(
    record_id: str,
    payload: RecordUpsert,
) -> dict[str, Any]:
    return _upsert("ledger", record_id, payload)


@router.get("/reconcile/{team_id}/{season}")
def reconcile_team_hardened(team_id: str, season: str) -> dict[str, Any]:
    result = front_office_reconciliation(team_id, season)
    normalized_team = team_id.upper()
    ledgers = list_front_office_records(
        "ledger",
        season=season,
        record_status="active",
        limit=1000,
    )
    matching = [
        item
        for item in ledgers
        if normalized_team
        in {
            str(team).upper()
            for team in item.get("record", {}).get("teams", [])
        }
    ]
    result["ledger_transaction_count"] = len(matching)
    unverified = set(result.get("unverified_record_ids", []))
    unverified.update(
        item["id"]
        for item in matching
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
