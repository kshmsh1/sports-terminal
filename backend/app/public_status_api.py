from __future__ import annotations

from typing import Any

from fastapi import APIRouter

from . import customer_ops_api as customer_ops
from .main import connect, decode_json, now_iso

router = APIRouter(prefix="/status", tags=["public-status"])


def _component(row: Any) -> dict[str, Any]:
    return {
        "id": row["id"],
        "name": row["name"],
        "status": row["status"],
        "description": row["description"] or "",
        "message": row["public_message"] or "",
        "updated_at": row["updated_at"],
    }


def _incident(row: Any, updates: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "id": row["id"],
        "severity": row["severity"],
        "status": row["status"],
        "title": row["title"],
        "summary": row["summary"],
        "impact": row["impact"] or "",
        "component_ids": decode_json(row["component_ids_json"], []),
        "started_at": row["started_at"],
        "updated_at": row["updated_at"],
        "resolved_at": row["resolved_at"] or "",
        "updates": updates,
    }


@router.get("")
def public_status() -> dict[str, Any]:
    customer_ops.init_customer_ops_db()
    with connect() as connection:
        components = [
            _component(row)
            for row in connection.execute(
                "SELECT * FROM service_components ORDER BY name"
            ).fetchall()
        ]
        active_incidents = connection.execute(
            "SELECT COUNT(*) AS count FROM service_incidents WHERE status NOT IN ('resolved', 'closed', 'postmortem')"
        ).fetchone()["count"]
    ranking = {
        "operational": 0,
        "maintenance": 1,
        "degraded": 2,
        "partial_outage": 3,
        "major_outage": 4,
    }
    overall = max(
        (str(item["status"]) for item in components),
        key=lambda status: ranking.get(status, 2),
        default="operational",
    )
    return {
        "product": "Sports Terminal",
        "status": overall,
        "active_incidents": int(active_incidents),
        "components": components,
        "generated_at": now_iso(),
    }


@router.get("/incidents")
def public_incidents(limit: int = 50) -> list[dict[str, Any]]:
    customer_ops.init_customer_ops_db()
    with connect() as connection:
        incidents = []
        for row in connection.execute(
            "SELECT * FROM service_incidents ORDER BY started_at DESC LIMIT ?",
            (max(1, min(limit, 250)),),
        ).fetchall():
            updates = [
                {
                    "status": update["status"],
                    "message": update["public_message"] or update["message"],
                    "created_at": update["created_at"],
                }
                for update in connection.execute(
                    "SELECT status, message, public_message, created_at FROM service_incident_updates WHERE incident_id = ? AND COALESCE(NULLIF(public_message, ''), message) != '' ORDER BY created_at",
                    (row["id"],),
                ).fetchall()
            ]
            incidents.append(_incident(row, updates))
        return incidents


@router.get("/incidents/{incident_id}")
def public_incident(incident_id: str) -> dict[str, Any]:
    customer_ops.init_customer_ops_db()
    with connect() as connection:
        row = connection.execute(
            "SELECT * FROM service_incidents WHERE id = ?",
            (incident_id,),
        ).fetchone()
        if row is None:
            return {
                "id": incident_id,
                "status": "not_found",
                "title": "Incident not found",
                "updates": [],
            }
        updates = [
            {
                "status": update["status"],
                "message": update["public_message"] or update["message"],
                "created_at": update["created_at"],
            }
            for update in connection.execute(
                "SELECT status, message, public_message, created_at FROM service_incident_updates WHERE incident_id = ? AND COALESCE(NULLIF(public_message, ''), message) != '' ORDER BY created_at",
                (incident_id,),
            ).fetchall()
        ]
        return _incident(row, updates)
