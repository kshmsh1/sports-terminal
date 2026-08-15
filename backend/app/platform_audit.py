from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any

from fastapi import APIRouter

from .main import connect, make_id, now_iso, rows_to_dicts

router = APIRouter(prefix="/v2/operations/audit", tags=["platform-audit"])


@dataclass(frozen=True)
class AuditVerification:
    valid: bool
    events: int
    first_invalid_id: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "valid": self.valid,
            "events": self.events,
            "first_invalid_id": self.first_invalid_id,
        }


class PlatformAuditLog:
    def record(
        self,
        *,
        actor_type: str,
        action: str,
        actor_id: str | None = None,
        object_type: str | None = None,
        object_id: str | None = None,
        request_id: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        event_id = make_id("audit")
        recorded_at = now_iso()
        metadata_json = json.dumps(metadata or {}, separators=(",", ":"), sort_keys=True)
        with connect() as connection:
            previous = connection.execute(
                "SELECT event_sha256 FROM platform_audit_events ORDER BY recorded_at DESC, id DESC LIMIT 1"
            ).fetchone()
            previous_hash = previous["event_sha256"] if previous is not None else None
            event_hash = _event_hash(
                event_id=event_id,
                actor_type=actor_type,
                actor_id=actor_id,
                action=action,
                object_type=object_type,
                object_id=object_id,
                request_id=request_id,
                metadata_json=metadata_json,
                previous_hash=previous_hash,
                recorded_at=recorded_at,
            )
            connection.execute(
                "INSERT INTO platform_audit_events "
                "(id, actor_type, actor_id, action, object_type, object_id, request_id, metadata, "
                "previous_event_sha256, event_sha256, recorded_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    event_id,
                    actor_type,
                    actor_id,
                    action,
                    object_type,
                    object_id,
                    request_id,
                    metadata_json,
                    previous_hash,
                    event_hash,
                    recorded_at,
                ),
            )
            connection.commit()
            row = connection.execute(
                "SELECT * FROM platform_audit_events WHERE id = ?", (event_id,)
            ).fetchone()
            return dict(row) if row is not None else {}

    def verify(self, limit: int = 10_000) -> AuditVerification:
        with connect() as connection:
            rows = rows_to_dicts(
                connection.execute(
                    "SELECT * FROM platform_audit_events ORDER BY recorded_at, id LIMIT ?",
                    (max(1, min(limit, 100_000)),),
                ).fetchall()
            )
        previous_hash: str | None = None
        for row in rows:
            if row.get("previous_event_sha256") != previous_hash:
                return AuditVerification(False, len(rows), str(row.get("id")))
            expected = _event_hash(
                event_id=str(row["id"]),
                actor_type=str(row["actor_type"]),
                actor_id=row.get("actor_id"),
                action=str(row["action"]),
                object_type=row.get("object_type"),
                object_id=row.get("object_id"),
                request_id=row.get("request_id"),
                metadata_json=str(row.get("metadata") or "{}"),
                previous_hash=previous_hash,
                recorded_at=str(row["recorded_at"]),
            )
            if not hashlib.sha256(expected.encode()).digest() == hashlib.sha256(str(row["event_sha256"]).encode()).digest():
                # Constant-sized comparison avoids leaking hash-prefix information through timing.
                if expected != row["event_sha256"]:
                    return AuditVerification(False, len(rows), str(row.get("id")))
            previous_hash = str(row["event_sha256"])
        return AuditVerification(True, len(rows))

    def recent(self, limit: int = 100) -> list[dict[str, Any]]:
        with connect() as connection:
            return rows_to_dicts(
                connection.execute(
                    "SELECT * FROM platform_audit_events ORDER BY recorded_at DESC, id DESC LIMIT ?",
                    (max(1, min(limit, 1000)),),
                ).fetchall()
            )


def _event_hash(
    *,
    event_id: str,
    actor_type: str,
    actor_id: Any,
    action: str,
    object_type: Any,
    object_id: Any,
    request_id: Any,
    metadata_json: str,
    previous_hash: Any,
    recorded_at: str,
) -> str:
    canonical = json.dumps(
        {
            "id": event_id,
            "actor_type": actor_type,
            "actor_id": actor_id,
            "action": action,
            "object_type": object_type,
            "object_id": object_id,
            "request_id": request_id,
            "metadata": json.loads(metadata_json or "{}"),
            "previous_event_sha256": previous_hash,
            "recorded_at": recorded_at,
        },
        separators=(",", ":"),
        sort_keys=True,
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


@router.get("/verify")
def verify_audit_chain() -> dict[str, Any]:
    return PlatformAuditLog().verify().to_dict()


@router.get("/recent")
def recent_audit_events(limit: int = 100) -> list[dict[str, Any]]:
    return PlatformAuditLog().recent(limit)
