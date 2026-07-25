from __future__ import annotations

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from . import customer_ops_api as customer_ops
from .main import connect, decode_json, encode_json, now_iso

router = APIRouter(prefix="/v2/customer-ops/invitations", tags=["customer-invitations"])


class InvitationAccept(BaseModel):
    actor_user_id: str
    token: str = Field(min_length=20, max_length=512)


class InvitationRotate(BaseModel):
    actor_user_id: str
    expires_in_days: int = Field(default=7, ge=1, le=30)
    message: str = ""


def _subscription_seat_limit(connection: Any, organization_id: str) -> int:
    row = connection.execute(
        "SELECT seat_count FROM customer_subscriptions WHERE scope_key = ?",
        (f"organization:{organization_id}",),
    ).fetchone()
    if row is None:
        return 1
    return max(1, int(row["seat_count"] or 1))


def _active_seats(connection: Any, organization_id: str) -> int:
    row = connection.execute(
        "SELECT COUNT(*) AS count FROM organization_memberships WHERE organization_id = ? AND status = 'active'",
        (organization_id,),
    ).fetchone()
    return int(row["count"] if row is not None else 0)


@router.post("/accept")
def accept_invitation(payload: InvitationAccept) -> dict[str, Any]:
    customer_ops.init_customer_ops_db()
    token_hash = hashlib.sha256(payload.token.encode("utf-8")).hexdigest()
    timestamp = now_iso()
    with connect() as connection:
        user = connection.execute(
            "SELECT id, email, display_name FROM users WHERE id = ?",
            (payload.actor_user_id,),
        ).fetchone()
        if user is None:
            raise HTTPException(status_code=404, detail="User not found")
        invitation = connection.execute(
            "SELECT * FROM organization_invitations WHERE token_hash = ? AND status = 'pending'",
            (token_hash,),
        ).fetchone()
        if invitation is None:
            raise HTTPException(status_code=404, detail="Invitation token is invalid or no longer active")
        if str(invitation["expires_at"]) < timestamp:
            connection.execute(
                "UPDATE organization_invitations SET status = 'expired', updated_at = ? WHERE id = ?",
                (timestamp, invitation["id"]),
            )
            connection.commit()
            raise HTTPException(status_code=409, detail="Invitation has expired")
        invited_email = str(invitation["email"] or "").strip().lower()
        user_email = str(user["email"] or "").strip().lower()
        if invited_email and invited_email != user_email:
            raise HTTPException(
                status_code=403,
                detail="Invitation email does not match the authenticated account",
            )
        organization_id = str(invitation["organization_id"])
        existing = connection.execute(
            "SELECT status FROM organization_memberships WHERE organization_id = ? AND user_id = ?",
            (organization_id, payload.actor_user_id),
        ).fetchone()
        if existing is None or str(existing["status"]) != "active":
            seat_limit = _subscription_seat_limit(connection, organization_id)
            active_seats = _active_seats(connection, organization_id)
            if active_seats >= seat_limit:
                raise HTTPException(
                    status_code=409,
                    detail={
                        "message": "Organization seat limit has been reached",
                        "active_seats": active_seats,
                        "seat_limit": seat_limit,
                    },
                )
        connection.execute(
            "INSERT INTO organization_memberships (organization_id, user_id, role, status, joined_at, updated_at) VALUES (?, ?, ?, 'active', ?, ?) ON CONFLICT(organization_id, user_id) DO UPDATE SET role = excluded.role, status = 'active', updated_at = excluded.updated_at",
            (
                organization_id,
                payload.actor_user_id,
                invitation["role"],
                timestamp,
                timestamp,
            ),
        )
        connection.execute(
            "UPDATE organization_invitations SET status = 'accepted', accepting_user_id = ?, accepted_at = ?, updated_at = ? WHERE id = ?",
            (payload.actor_user_id, timestamp, timestamp, invitation["id"]),
        )
        customer_ops._audit(
            connection,
            actor_user_id=payload.actor_user_id,
            organization_id=organization_id,
            action="invitation.token_accepted",
            target_type="organization_invitation",
            target_id=str(invitation["id"]),
            payload={"role": invitation["role"], "email": invited_email},
        )
        connection.commit()
        organization = connection.execute(
            "SELECT id, name, slug, status, plan_id FROM organizations WHERE id = ?",
            (organization_id,),
        ).fetchone()
        return {
            "accepted": True,
            "invitation_id": invitation["id"],
            "organization": dict(organization) if organization is not None else {"id": organization_id},
            "membership": {
                "organization_id": organization_id,
                "user_id": payload.actor_user_id,
                "role": invitation["role"],
                "status": "active",
            },
            "accepted_at": timestamp,
        }


@router.post("/{invitation_id}/rotate")
def rotate_invitation_token(
    invitation_id: str,
    payload: InvitationRotate,
) -> dict[str, Any]:
    customer_ops.init_customer_ops_db()
    timestamp = now_iso()
    with connect() as connection:
        invitation = connection.execute(
            "SELECT * FROM organization_invitations WHERE id = ?",
            (invitation_id,),
        ).fetchone()
        if invitation is None:
            raise HTTPException(status_code=404, detail="Invitation not found")
        organization_id = str(invitation["organization_id"])
        customer_ops._require_org_role(
            connection,
            organization_id,
            payload.actor_user_id,
            "admin",
        )
        if str(invitation["status"]) == "accepted":
            raise HTTPException(status_code=409, detail="Accepted invitations cannot be rotated")
        raw_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw_token.encode("utf-8")).hexdigest()
        expires_at = (
            datetime.now(timezone.utc) + timedelta(days=payload.expires_in_days)
        ).isoformat()
        connection.execute(
            "UPDATE organization_invitations SET status = 'pending', token_hash = ?, message = ?, expires_at = ?, updated_at = ? WHERE id = ?",
            (
                token_hash,
                payload.message or invitation["message"],
                expires_at,
                timestamp,
                invitation_id,
            ),
        )
        outbox_id = customer_ops._queue_provider_event(
            connection,
            provider_type="email",
            event_type="organization.invitation_rotated",
            destination=str(invitation["email"]),
            payload={
                "invitation_id": invitation_id,
                "organization_id": organization_id,
                "role": invitation["role"],
                "token": raw_token,
                "message": payload.message or invitation["message"],
                "expires_at": expires_at,
            },
            idempotency_key=f"invitation:{invitation_id}:rotation:{token_hash[:16]}",
        )
        customer_ops._audit(
            connection,
            actor_user_id=payload.actor_user_id,
            organization_id=organization_id,
            action="invitation.token_rotated",
            target_type="organization_invitation",
            target_id=invitation_id,
            payload={"expires_at": expires_at, "outbox_id": outbox_id},
        )
        connection.commit()
        return {
            "invitation_id": invitation_id,
            "status": "pending",
            "expires_at": expires_at,
            "delivery_outbox_id": outbox_id,
            "token_preview": f"{raw_token[:6]}…",
        }
