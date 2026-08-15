from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from .database import connect
from .environment_promotions import EnvironmentPromotionError, EnvironmentPromotionService
from .main import rows_to_dicts

router = APIRouter(prefix="/v2/operations/environments", tags=["environment-promotion"])


class PromoteRequest(BaseModel):
    source: str
    target: str
    reason: str


@router.get("")
def environments() -> dict[str, Any]:
    with connect() as connection:
        rows = rows_to_dicts(
            connection.execute(
                "SELECT environment, release_id, database_schema_version, status, deployed_at, updated_at "
                "FROM deployment_environments ORDER BY environment"
            ).fetchall()
        )
    return {"environments": rows}


@router.post("/promote")
def promote(payload: PromoteRequest, request: Request) -> dict[str, Any]:
    actor = str(getattr(request.state, "user_id", "platform-operator"))
    try:
        result = EnvironmentPromotionService().promote(
            source=payload.source,
            target=payload.target,
            actor=actor,
            reason=payload.reason,
        )
    except EnvironmentPromotionError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    return {
        "source": result.source,
        "target": result.target,
        "release_id": result.release_id,
        "schema_version": result.schema_version,
        "promoted_at": result.promoted_at,
    }


@router.post("/{environment}/healthy")
def mark_healthy(environment: str, request: Request) -> dict[str, Any]:
    actor = str(getattr(request.state, "user_id", "platform-operator"))
    try:
        return EnvironmentPromotionService().mark_healthy(environment, actor=actor)
    except EnvironmentPromotionError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
