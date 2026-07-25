from __future__ import annotations

import hashlib
import os
import secrets
import sqlite3
from datetime import datetime, timedelta, timezone
from typing import Any, Literal

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from .launch_api import ROLE_RANK, _ensure_shadow_user, init_launch_db
from .main import connect, decode_json, encode_json, make_id, now_iso

router = APIRouter(prefix="/v2/customer-ops", tags=["customer-operations"])

ScopeType = Literal["personal", "organization"]


class SubscriptionUpsert(BaseModel):
    actor_user_id: str
    scope_type: ScopeType = "personal"
    scope_id: str
    plan_id: str
    status: str = "trialing"
    billing_period: str = "monthly"
    seat_count: int = Field(default=1, ge=1, le=10000)
    trial_ends_at: str = ""
    cancel_at_period_end: bool = False
    provider_customer_id: str = ""
    provider_subscription_id: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class OnboardingUpdate(BaseModel):
    actor_user_id: str
    scope_type: ScopeType = "personal"
    scope_id: str
    completed_steps: list[str] = Field(default_factory=list)
    dismissed_steps: list[str] = Field(default_factory=list)
    current_step: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class InvitationCreate(BaseModel):
    actor_user_id: str
    email: str
    role: str = "analyst"
    expires_in_days: int = Field(default=7, ge=1, le=30)
    message: str = ""


class InvitationAction(BaseModel):
    actor_user_id: str
    action: Literal["accept", "revoke", "expire", "resend"]
    accepting_user_id: str = ""


class SupportTicketCreate(BaseModel):
    actor_user_id: str
    scope_type: ScopeType = "personal"
    scope_id: str
    organization_id: str = ""
    category: str = "general"
    priority: str = "normal"
    subject: str
    body: str
    related_object_type: str = ""
    related_object_id: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class SupportTicketEventCreate(BaseModel):
    actor_user_id: str
    event_type: str
    message: str
    status: str = ""
    assigned_user_id: str = ""
    is_customer_visible: bool = True
    metadata: dict[str, Any] = Field(default_factory=dict)


class PrivacyRequestCreate(BaseModel):
    actor_user_id: str
    user_id: str
    organization_id: str = ""
    request_type: Literal[
        "access",
        "export",
        "correction",
        "deletion",
        "restriction",
        "objection",
    ]
    details: str = ""
    jurisdiction: str = "US"
    metadata: dict[str, Any] = Field(default_factory=dict)


class PrivacyRequestAction(BaseModel):
    actor_user_id: str
    action: Literal[
        "verify",
        "approve",
        "reject",
        "start",
        "complete",
        "cancel",
    ]
    note: str = ""
    export_location: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class NotificationCreate(BaseModel):
    actor_user_id: str
    user_id: str
    organization_id: str = ""
    kind: str = "product"
    title: str
    body: str
    channel: Literal["in_app", "email", "sms", "webhook"] = "in_app"
    metadata: dict[str, Any] = Field(default_factory=dict)


class NotificationAction(BaseModel):
    actor_user_id: str
    action: Literal["read", "unread", "archive", "retry"]


class ProviderOutboxAction(BaseModel):
    actor_user_id: str
    action: Literal["retry", "cancel", "deliver", "fail"]
    error: str = ""


class WebhookReceipt(BaseModel):
    external_event_id: str
    event_type: str
    payload: dict[str, Any] = Field(default_factory=dict)
    signature_valid: bool = False


class ServiceComponentUpsert(BaseModel):
    actor_user_id: str
    name: str
    status: Literal["operational", "degraded", "partial_outage", "major_outage", "maintenance"] = "operational"
    description: str = ""
    public_message: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class IncidentCreate(BaseModel):
    actor_user_id: str
    severity: Literal["sev1", "sev2", "sev3", "sev4"] = "sev3"
    title: str
    summary: str
    impact: str = ""
    component_ids: list[str] = Field(default_factory=list)
    status: str = "investigating"
    metadata: dict[str, Any] = Field(default_factory=dict)


class IncidentUpdateCreate(BaseModel):
    actor_user_id: str
    status: str
    message: str
    public_message: str = ""
    component_statuses: dict[str, str] = Field(default_factory=dict)
    metadata: dict[str, Any] = Field(default_factory=dict)


class BackupRunCreate(BaseModel):
    actor_user_id: str
    backup_type: str = "database"
    status: str = "started"
    location: str = ""
    checksum: str = ""
    size_bytes: int = Field(default=0, ge=0)
    restore_tested: bool = False
    metadata: dict[str, Any] = Field(default_factory=dict)


class RetentionPolicyUpsert(BaseModel):
    actor_user_id: str
    key: str
    retention_days: int = Field(ge=0, le=36500)
    action: Literal["retain", "archive", "anonymize", "delete"] = "archive"
    enabled: bool = True
    legal_basis: str = ""
    description: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


def _utc_after(days: int) -> str:
    return (datetime.now(timezone.utc) + timedelta(days=days)).isoformat()


def _scope_key(scope_type: str, scope_id: str) -> str:
    if scope_type not in {"personal", "organization"}:
        raise HTTPException(status_code=400, detail="Scope type must be personal or organization")
    if not scope_id:
        raise HTTPException(status_code=400, detail="Scope ID is required")
    return f"{scope_type}:{scope_id}"


def _user_role(connection: sqlite3.Connection, user_id: str) -> str:
    row = connection.execute("SELECT role FROM users WHERE id = ?", (user_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="User not found")
    return str(row["role"] or "analyst")


def _membership_role(connection: sqlite3.Connection, organization_id: str, user_id: str) -> str:
    row = connection.execute(
        "SELECT role FROM organization_memberships WHERE organization_id = ? AND user_id = ? AND status = 'active'",
        (organization_id, user_id),
    ).fetchone()
    if row is None:
        raise HTTPException(status_code=403, detail="Active organization membership is required")
    return str(row["role"] or "analyst")


def _require_self_or_operator(connection: sqlite3.Connection, actor_user_id: str, user_id: str) -> None:
    if actor_user_id == user_id:
        return
    if _user_role(connection, actor_user_id) == "platform_admin":
        return
    raise HTTPException(status_code=403, detail="Users may access only their own customer operations")


def _require_org_role(
    connection: sqlite3.Connection,
    organization_id: str,
    actor_user_id: str,
    minimum: str = "analyst",
) -> str:
    if _user_role(connection, actor_user_id) == "platform_admin":
        return "platform_admin"
    role = _membership_role(connection, organization_id, actor_user_id)
    if ROLE_RANK.get(role, 0) < ROLE_RANK.get(minimum, 0):
        raise HTTPException(status_code=403, detail=f"{minimum} role or higher is required")
    return role


def _require_scope_access(
    connection: sqlite3.Connection,
    actor_user_id: str,
    scope_type: str,
    scope_id: str,
    minimum_org_role: str = "analyst",
) -> None:
    if scope_type == "organization":
        _require_org_role(connection, scope_id, actor_user_id, minimum_org_role)
    else:
        _require_self_or_operator(connection, actor_user_id, scope_id)


def _audit(
    connection: sqlite3.Connection,
    *,
    actor_user_id: str,
    action: str,
    target_type: str,
    target_id: str,
    organization_id: str = "",
    payload: dict[str, Any] | None = None,
) -> None:
    connection.execute(
        "INSERT INTO customer_ops_audit_events (id, actor_user_id, organization_id, action, target_type, target_id, payload_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (
            make_id("audit"),
            actor_user_id,
            organization_id or None,
            action,
            target_type,
            target_id,
            encode_json(payload or {}),
            now_iso(),
        ),
    )


def _queue_provider_event(
    connection: sqlite3.Connection,
    *,
    provider_type: str,
    event_type: str,
    destination: str,
    payload: dict[str, Any],
    idempotency_key: str,
) -> str:
    existing = connection.execute(
        "SELECT id FROM provider_outbox WHERE idempotency_key = ?",
        (idempotency_key,),
    ).fetchone()
    if existing is not None:
        return str(existing["id"])
    event_id = make_id("outbox")
    timestamp = now_iso()
    connection.execute(
        "INSERT INTO provider_outbox (id, provider_type, event_type, destination, payload_json, status, attempt_count, last_error, next_attempt_at, idempotency_key, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 'pending', 0, '', ?, ?, ?, ?)",
        (
            event_id,
            provider_type,
            event_type,
            destination,
            encode_json(payload),
            timestamp,
            idempotency_key,
            timestamp,
            timestamp,
        ),
    )
    return event_id


def _json_item(row: sqlite3.Row, columns: dict[str, Any]) -> dict[str, Any]:
    item = dict(row)
    for column, fallback in columns.items():
        item[column.removesuffix("_json")] = decode_json(item.pop(column, None), fallback)
    for key in ("enabled", "cancel_at_period_end", "signature_valid", "restore_tested", "is_customer_visible"):
        if key in item:
            item[key] = bool(item[key])
    return item


def _rows(connection: sqlite3.Connection, sql: str, values: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
    return [dict(row) for row in connection.execute(sql, values).fetchall()]


def init_customer_ops_db() -> None:
    init_launch_db()
    with connect() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS plan_entitlements (
              plan_id TEXT NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
              entitlement_key TEXT NOT NULL,
              enabled INTEGER NOT NULL DEFAULT 1,
              limit_value INTEGER,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              updated_at TEXT NOT NULL,
              PRIMARY KEY (plan_id, entitlement_key)
            );

            CREATE TABLE IF NOT EXISTS customer_subscriptions (
              scope_key TEXT PRIMARY KEY,
              scope_type TEXT NOT NULL,
              scope_id TEXT NOT NULL,
              plan_id TEXT NOT NULL REFERENCES plans(id),
              status TEXT NOT NULL DEFAULT 'trialing',
              billing_period TEXT NOT NULL DEFAULT 'monthly',
              seat_count INTEGER NOT NULL DEFAULT 1,
              trial_ends_at TEXT,
              cancel_at_period_end INTEGER NOT NULL DEFAULT 0,
              provider_customer_id TEXT,
              provider_subscription_id TEXT,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              version INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS onboarding_states (
              scope_key TEXT PRIMARY KEY,
              scope_type TEXT NOT NULL,
              scope_id TEXT NOT NULL,
              completed_steps_json TEXT NOT NULL DEFAULT '[]',
              dismissed_steps_json TEXT NOT NULL DEFAULT '[]',
              current_step TEXT,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS organization_invitations (
              id TEXT PRIMARY KEY,
              organization_id TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
              email TEXT NOT NULL,
              role TEXT NOT NULL DEFAULT 'analyst',
              status TEXT NOT NULL DEFAULT 'pending',
              token_hash TEXT NOT NULL,
              invited_by_user_id TEXT NOT NULL,
              accepting_user_id TEXT,
              message TEXT,
              expires_at TEXT NOT NULL,
              accepted_at TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS support_tickets (
              id TEXT PRIMARY KEY,
              scope_key TEXT NOT NULL,
              requester_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              organization_id TEXT,
              category TEXT NOT NULL,
              priority TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'open',
              subject TEXT NOT NULL,
              body TEXT NOT NULL,
              assigned_user_id TEXT,
              related_object_type TEXT,
              related_object_id TEXT,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              resolved_at TEXT
            );

            CREATE TABLE IF NOT EXISTS support_ticket_events (
              id TEXT PRIMARY KEY,
              ticket_id TEXT NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
              actor_user_id TEXT NOT NULL,
              event_type TEXT NOT NULL,
              message TEXT NOT NULL,
              is_customer_visible INTEGER NOT NULL DEFAULT 1,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS privacy_requests (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              organization_id TEXT,
              request_type TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'requested',
              jurisdiction TEXT NOT NULL DEFAULT 'US',
              details TEXT,
              verification_status TEXT NOT NULL DEFAULT 'pending',
              export_location TEXT,
              due_at TEXT NOT NULL,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              requested_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              completed_at TEXT
            );

            CREATE TABLE IF NOT EXISTS privacy_request_events (
              id TEXT PRIMARY KEY,
              request_id TEXT NOT NULL REFERENCES privacy_requests(id) ON DELETE CASCADE,
              actor_user_id TEXT NOT NULL,
              action TEXT NOT NULL,
              note TEXT,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS customer_notifications (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              organization_id TEXT,
              kind TEXT NOT NULL,
              title TEXT NOT NULL,
              body TEXT NOT NULL,
              channel TEXT NOT NULL DEFAULT 'in_app',
              status TEXT NOT NULL DEFAULT 'unread',
              payload_json TEXT NOT NULL DEFAULT '{}',
              provider_outbox_id TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS provider_outbox (
              id TEXT PRIMARY KEY,
              provider_type TEXT NOT NULL,
              event_type TEXT NOT NULL,
              destination TEXT,
              payload_json TEXT NOT NULL DEFAULT '{}',
              status TEXT NOT NULL DEFAULT 'pending',
              attempt_count INTEGER NOT NULL DEFAULT 0,
              last_error TEXT,
              next_attempt_at TEXT,
              idempotency_key TEXT UNIQUE NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              delivered_at TEXT
            );

            CREATE TABLE IF NOT EXISTS provider_webhook_events (
              id TEXT PRIMARY KEY,
              provider_type TEXT NOT NULL,
              external_event_id TEXT NOT NULL,
              event_type TEXT NOT NULL,
              payload_json TEXT NOT NULL DEFAULT '{}',
              signature_valid INTEGER NOT NULL DEFAULT 0,
              status TEXT NOT NULL DEFAULT 'received',
              received_at TEXT NOT NULL,
              processed_at TEXT,
              UNIQUE(provider_type, external_event_id)
            );

            CREATE TABLE IF NOT EXISTS service_components (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'operational',
              description TEXT,
              public_message TEXT,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS service_incidents (
              id TEXT PRIMARY KEY,
              severity TEXT NOT NULL,
              status TEXT NOT NULL,
              title TEXT NOT NULL,
              summary TEXT NOT NULL,
              impact TEXT,
              component_ids_json TEXT NOT NULL DEFAULT '[]',
              metadata_json TEXT NOT NULL DEFAULT '{}',
              created_by_user_id TEXT NOT NULL,
              started_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              resolved_at TEXT
            );

            CREATE TABLE IF NOT EXISTS service_incident_updates (
              id TEXT PRIMARY KEY,
              incident_id TEXT NOT NULL REFERENCES service_incidents(id) ON DELETE CASCADE,
              actor_user_id TEXT NOT NULL,
              status TEXT NOT NULL,
              message TEXT NOT NULL,
              public_message TEXT,
              component_statuses_json TEXT NOT NULL DEFAULT '{}',
              metadata_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS backup_runs (
              id TEXT PRIMARY KEY,
              backup_type TEXT NOT NULL,
              status TEXT NOT NULL,
              location TEXT,
              checksum TEXT,
              size_bytes INTEGER NOT NULL DEFAULT 0,
              restore_tested INTEGER NOT NULL DEFAULT 0,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              started_at TEXT NOT NULL,
              completed_at TEXT,
              created_by_user_id TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS retention_policies (
              key TEXT PRIMARY KEY,
              retention_days INTEGER NOT NULL,
              action TEXT NOT NULL,
              enabled INTEGER NOT NULL DEFAULT 1,
              legal_basis TEXT,
              description TEXT,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              updated_by_user_id TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS customer_ops_audit_events (
              id TEXT PRIMARY KEY,
              actor_user_id TEXT NOT NULL,
              organization_id TEXT,
              action TEXT NOT NULL,
              target_type TEXT NOT NULL,
              target_id TEXT NOT NULL,
              payload_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_customer_subscriptions_scope
              ON customer_subscriptions(scope_type, scope_id, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_invitations_org
              ON organization_invitations(organization_id, status, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_support_scope
              ON support_tickets(scope_key, status, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_privacy_user
              ON privacy_requests(user_id, status, requested_at DESC);
            CREATE INDEX IF NOT EXISTS idx_notifications_user
              ON customer_notifications(user_id, status, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_provider_outbox_status
              ON provider_outbox(status, next_attempt_at, created_at);
            CREATE INDEX IF NOT EXISTS idx_incidents_status
              ON service_incidents(status, severity, started_at DESC);
            CREATE INDEX IF NOT EXISTS idx_customer_ops_audit
              ON customer_ops_audit_events(organization_id, created_at DESC);
            """
        )
        _seed_customer_ops(connection)
        connection.commit()


def _seed_customer_ops(connection: sqlite3.Connection) -> None:
    timestamp = now_iso()
    entitlement_map: dict[str, dict[str, int | None]] = {
        "free": {
            "nba_hub": None,
            "stats": None,
            "community_read": None,
            "workspace_sheets": 3,
            "saved_objects": 10,
        },
        "pro": {
            "nba_hub": None,
            "stats": None,
            "advanced_nba": None,
            "trade_machine": None,
            "front_office": None,
            "python_runtime_rows": 500,
            "workspace_sheets": 25,
            "saved_objects": 500,
            "community_write": None,
            "messaging": None,
            "alerts": 100,
        },
        "org": {
            "nba_hub": None,
            "stats": None,
            "advanced_nba": None,
            "trade_machine": None,
            "front_office": None,
            "python_runtime_rows": 500,
            "workspace_sheets": 100,
            "saved_objects": 5000,
            "community_write": None,
            "messaging": None,
            "alerts": 1000,
            "organization_seats": 10,
            "shared_workspaces": None,
            "transaction_approvals": None,
            "trust_safety_console": None,
            "audit_exports": None,
        },
    }
    for plan_id, entitlements in entitlement_map.items():
        for key, limit_value in entitlements.items():
            connection.execute(
                "INSERT OR IGNORE INTO plan_entitlements (plan_id, entitlement_key, enabled, limit_value, metadata_json, updated_at) VALUES (?, ?, 1, ?, '{}', ?)",
                (plan_id, key, limit_value, timestamp),
            )
    components = (
        ("api", "Launch API", "Core account, organization and workflow API"),
        ("web", "Web Application", "Flutter web customer terminal"),
        ("nba-data", "NBA Data", "Certified 2025-26 NBA release and source registry"),
        ("workspace", "Workspace", "Shared multi-sheet modeling service"),
        ("python-runtime", "Python Runtime", "Bounded analytical execution workers"),
        ("notifications", "Notifications", "In-app and provider delivery pipeline"),
    )
    for component_id, name, description in components:
        connection.execute(
            "INSERT OR IGNORE INTO service_components (id, name, status, description, public_message, metadata_json, updated_at) VALUES (?, ?, 'operational', ?, '', '{}', ?)",
            (component_id, name, description, timestamp),
        )
    policies = (
        ("auth_sessions", 30, "delete", "Security and account access"),
        ("provider_outbox", 90, "archive", "Operational delivery evidence"),
        ("audit_events", 2555, "archive", "Security and compliance evidence"),
        ("support_tickets", 1095, "anonymize", "Customer support operations"),
        ("privacy_requests", 2555, "archive", "Privacy compliance evidence"),
        ("workspace_versions", 365, "archive", "Customer-controlled work history"),
    )
    for key, days, action, basis in policies:
        connection.execute(
            "INSERT OR IGNORE INTO retention_policies (key, retention_days, action, enabled, legal_basis, description, metadata_json, updated_by_user_id, updated_at) VALUES (?, ?, ?, 1, ?, ?, '{}', 'system', ?)",
            (key, days, action, basis, f"Default launch policy for {key}", timestamp),
        )


@router.on_event("startup")
def startup_customer_ops() -> None:
    init_customer_ops_db()


@router.get("/plans")
def list_customer_plans() -> list[dict[str, Any]]:
    init_customer_ops_db()
    with connect() as connection:
        plans = _rows(connection, "SELECT * FROM plans ORDER BY price_cents, name")
        for plan in plans:
            plan["features"] = decode_json(plan.get("features"), [])
            plan["entitlements"] = [
                {
                    **dict(row),
                    "enabled": bool(row["enabled"]),
                    "metadata": decode_json(row["metadata_json"], {}),
                }
                for row in connection.execute(
                    "SELECT * FROM plan_entitlements WHERE plan_id = ? ORDER BY entitlement_key",
                    (plan["id"],),
                ).fetchall()
            ]
        return plans


@router.get("/subscriptions/{scope_type}/{scope_id}")
def get_subscription(
    scope_type: ScopeType,
    scope_id: str,
    actor_user_id: str = Query(...),
) -> dict[str, Any]:
    init_customer_ops_db()
    scope_key = _scope_key(scope_type, scope_id)
    with connect() as connection:
        _require_scope_access(connection, actor_user_id, scope_type, scope_id)
        row = connection.execute(
            "SELECT * FROM customer_subscriptions WHERE scope_key = ?",
            (scope_key,),
        ).fetchone()
        if row is None:
            plan_id = "org" if scope_type == "organization" else "free"
            return {
                "scope_key": scope_key,
                "scope_type": scope_type,
                "scope_id": scope_id,
                "plan_id": plan_id,
                "status": "none",
                "billing_period": "monthly",
                "seat_count": 1,
                "version": 0,
                "metadata": {},
            }
        return _json_item(row, {"metadata_json": {}})


@router.put("/subscriptions/{scope_type}/{scope_id}")
def upsert_subscription(
    scope_type: ScopeType,
    scope_id: str,
    payload: SubscriptionUpsert,
) -> dict[str, Any]:
    if payload.scope_type != scope_type or payload.scope_id != scope_id:
        raise HTTPException(status_code=400, detail="Subscription path and payload scope must match")
    init_customer_ops_db()
    scope_key = _scope_key(scope_type, scope_id)
    timestamp = now_iso()
    with connect() as connection:
        _require_scope_access(connection, payload.actor_user_id, scope_type, scope_id, "admin")
        if connection.execute("SELECT 1 FROM plans WHERE id = ?", (payload.plan_id,)).fetchone() is None:
            raise HTTPException(status_code=404, detail="Plan not found")
        existing = connection.execute(
            "SELECT version, created_at FROM customer_subscriptions WHERE scope_key = ?",
            (scope_key,),
        ).fetchone()
        version = 1 if existing is None else int(existing["version"]) + 1
        created_at = timestamp if existing is None else existing["created_at"]
        connection.execute(
            """
            INSERT INTO customer_subscriptions (
              scope_key, scope_type, scope_id, plan_id, status, billing_period,
              seat_count, trial_ends_at, cancel_at_period_end, provider_customer_id,
              provider_subscription_id, metadata_json, version, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(scope_key) DO UPDATE SET plan_id = excluded.plan_id,
              status = excluded.status, billing_period = excluded.billing_period,
              seat_count = excluded.seat_count, trial_ends_at = excluded.trial_ends_at,
              cancel_at_period_end = excluded.cancel_at_period_end,
              provider_customer_id = excluded.provider_customer_id,
              provider_subscription_id = excluded.provider_subscription_id,
              metadata_json = excluded.metadata_json, version = excluded.version,
              updated_at = excluded.updated_at
            """,
            (
                scope_key,
                scope_type,
                scope_id,
                payload.plan_id,
                payload.status,
                payload.billing_period,
                payload.seat_count,
                payload.trial_ends_at or None,
                int(payload.cancel_at_period_end),
                payload.provider_customer_id or None,
                payload.provider_subscription_id or None,
                encode_json(payload.metadata),
                version,
                created_at,
                timestamp,
            ),
        )
        outbox_id = _queue_provider_event(
            connection,
            provider_type="billing",
            event_type="subscription.sync_requested",
            destination=scope_key,
            payload={
                "scope_type": scope_type,
                "scope_id": scope_id,
                "plan_id": payload.plan_id,
                "status": payload.status,
                "seat_count": payload.seat_count,
                "version": version,
            },
            idempotency_key=f"subscription:{scope_key}:v{version}",
        )
        _audit(
            connection,
            actor_user_id=payload.actor_user_id,
            organization_id=scope_id if scope_type == "organization" else "",
            action="subscription.updated",
            target_type="subscription",
            target_id=scope_key,
            payload={"plan_id": payload.plan_id, "status": payload.status, "outbox_id": outbox_id},
        )
        connection.commit()
    return get_subscription(scope_type, scope_id, payload.actor_user_id)


@router.get("/entitlements/{scope_type}/{scope_id}")
def get_entitlements(
    scope_type: ScopeType,
    scope_id: str,
    actor_user_id: str = Query(...),
) -> dict[str, Any]:
    subscription = get_subscription(scope_type, scope_id, actor_user_id)
    with connect() as connection:
        rows = connection.execute(
            "SELECT entitlement_key, enabled, limit_value, metadata_json FROM plan_entitlements WHERE plan_id = ? ORDER BY entitlement_key",
            (subscription["plan_id"],),
        ).fetchall()
    entitlements = {
        str(row["entitlement_key"]): {
            "enabled": bool(row["enabled"]),
            "limit": row["limit_value"],
            "metadata": decode_json(row["metadata_json"], {}),
        }
        for row in rows
    }
    return {
        "scope_type": scope_type,
        "scope_id": scope_id,
        "plan_id": subscription["plan_id"],
        "subscription_status": subscription["status"],
        "entitlements": entitlements,
    }


@router.get("/onboarding/{scope_type}/{scope_id}")
def get_onboarding(
    scope_type: ScopeType,
    scope_id: str,
    actor_user_id: str = Query(...),
) -> dict[str, Any]:
    init_customer_ops_db()
    scope_key = _scope_key(scope_type, scope_id)
    with connect() as connection:
        _require_scope_access(connection, actor_user_id, scope_type, scope_id)
        row = connection.execute(
            "SELECT * FROM onboarding_states WHERE scope_key = ?",
            (scope_key,),
        ).fetchone()
        if row is None:
            return {
                "scope_key": scope_key,
                "scope_type": scope_type,
                "scope_id": scope_id,
                "completed_steps": [],
                "dismissed_steps": [],
                "current_step": "profile",
                "metadata": {},
                "updated_at": "",
            }
        return _json_item(
            row,
            {
                "completed_steps_json": [],
                "dismissed_steps_json": [],
                "metadata_json": {},
            },
        )


@router.put("/onboarding/{scope_type}/{scope_id}")
def update_onboarding(
    scope_type: ScopeType,
    scope_id: str,
    payload: OnboardingUpdate,
) -> dict[str, Any]:
    if payload.scope_type != scope_type or payload.scope_id != scope_id:
        raise HTTPException(status_code=400, detail="Onboarding path and payload scope must match")
    init_customer_ops_db()
    scope_key = _scope_key(scope_type, scope_id)
    timestamp = now_iso()
    completed = sorted(set(payload.completed_steps))
    dismissed = sorted(set(payload.dismissed_steps) - set(completed))
    with connect() as connection:
        _require_scope_access(connection, payload.actor_user_id, scope_type, scope_id)
        connection.execute(
            """
            INSERT INTO onboarding_states (
              scope_key, scope_type, scope_id, completed_steps_json,
              dismissed_steps_json, current_step, metadata_json, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(scope_key) DO UPDATE SET
              completed_steps_json = excluded.completed_steps_json,
              dismissed_steps_json = excluded.dismissed_steps_json,
              current_step = excluded.current_step,
              metadata_json = excluded.metadata_json,
              updated_at = excluded.updated_at
            """,
            (
                scope_key,
                scope_type,
                scope_id,
                encode_json(completed),
                encode_json(dismissed),
                payload.current_step,
                encode_json(payload.metadata),
                timestamp,
            ),
        )
        _audit(
            connection,
            actor_user_id=payload.actor_user_id,
            organization_id=scope_id if scope_type == "organization" else "",
            action="onboarding.updated",
            target_type="onboarding",
            target_id=scope_key,
            payload={"completed_steps": completed, "current_step": payload.current_step},
        )
        connection.commit()
    return get_onboarding(scope_type, scope_id, payload.actor_user_id)


@router.get("/organizations/{organization_id}/invitations")
def list_invitations(
    organization_id: str,
    actor_user_id: str = Query(...),
    status: str = "",
) -> list[dict[str, Any]]:
    init_customer_ops_db()
    with connect() as connection:
        _require_org_role(connection, organization_id, actor_user_id, "admin")
        sql = "SELECT * FROM organization_invitations WHERE organization_id = ?"
        values: list[Any] = [organization_id]
        if status:
            sql += " AND status = ?"
            values.append(status)
        sql += " ORDER BY created_at DESC"
        return _rows(connection, sql, tuple(values))


@router.post("/organizations/{organization_id}/invitations")
def create_invitation(
    organization_id: str,
    payload: InvitationCreate,
) -> dict[str, Any]:
    init_customer_ops_db()
    timestamp = now_iso()
    invitation_id = make_id("invite")
    raw_token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(raw_token.encode("utf-8")).hexdigest()
    with connect() as connection:
        _require_org_role(connection, organization_id, payload.actor_user_id, "admin")
        pending = connection.execute(
            "SELECT id FROM organization_invitations WHERE organization_id = ? AND lower(email) = lower(?) AND status = 'pending'",
            (organization_id, payload.email.strip()),
        ).fetchone()
        if pending is not None:
            raise HTTPException(status_code=409, detail="A pending invitation already exists for this email")
        connection.execute(
            "INSERT INTO organization_invitations (id, organization_id, email, role, status, token_hash, invited_by_user_id, accepting_user_id, message, expires_at, accepted_at, created_at, updated_at) VALUES (?, ?, ?, ?, 'pending', ?, ?, NULL, ?, ?, NULL, ?, ?)",
            (
                invitation_id,
                organization_id,
                payload.email.strip().lower(),
                payload.role,
                token_hash,
                payload.actor_user_id,
                payload.message,
                _utc_after(payload.expires_in_days),
                timestamp,
                timestamp,
            ),
        )
        outbox_id = _queue_provider_event(
            connection,
            provider_type="email",
            event_type="organization.invitation",
            destination=payload.email.strip().lower(),
            payload={
                "invitation_id": invitation_id,
                "organization_id": organization_id,
                "role": payload.role,
                "token": raw_token,
                "message": payload.message,
            },
            idempotency_key=f"invitation:{invitation_id}:v1",
        )
        _audit(
            connection,
            actor_user_id=payload.actor_user_id,
            organization_id=organization_id,
            action="invitation.created",
            target_type="organization_invitation",
            target_id=invitation_id,
            payload={"email": payload.email.strip().lower(), "role": payload.role, "outbox_id": outbox_id},
        )
        connection.commit()
        row = connection.execute(
            "SELECT * FROM organization_invitations WHERE id = ?",
            (invitation_id,),
        ).fetchone()
        assert row is not None
        item = dict(row)
        item["delivery_outbox_id"] = outbox_id
        item["token_preview"] = f"{raw_token[:6]}…"
        return item


@router.post("/organizations/{organization_id}/invitations/{invitation_id}/action")
def act_on_invitation(
    organization_id: str,
    invitation_id: str,
    payload: InvitationAction,
) -> dict[str, Any]:
    init_customer_ops_db()
    timestamp = now_iso()
    with connect() as connection:
        row = connection.execute(
            "SELECT * FROM organization_invitations WHERE id = ? AND organization_id = ?",
            (invitation_id, organization_id),
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Invitation not found")
        if payload.action == "accept":
            accepting_user_id = payload.accepting_user_id or payload.actor_user_id
            _require_self_or_operator(connection, payload.actor_user_id, accepting_user_id)
            if str(row["expires_at"]) < timestamp:
                raise HTTPException(status_code=409, detail="Invitation has expired")
            _ensure_shadow_user(connection, accepting_user_id, accepting_user_id, str(row["role"]))
            connection.execute(
                "INSERT INTO organization_memberships (organization_id, user_id, role, status, joined_at, updated_at) VALUES (?, ?, ?, 'active', ?, ?) ON CONFLICT(organization_id, user_id) DO UPDATE SET role = excluded.role, status = 'active', updated_at = excluded.updated_at",
                (organization_id, accepting_user_id, row["role"], timestamp, timestamp),
            )
            status = "accepted"
            connection.execute(
                "UPDATE organization_invitations SET status = ?, accepting_user_id = ?, accepted_at = ?, updated_at = ? WHERE id = ?",
                (status, accepting_user_id, timestamp, timestamp, invitation_id),
            )
        else:
            _require_org_role(connection, organization_id, payload.actor_user_id, "admin")
            status = {
                "revoke": "revoked",
                "expire": "expired",
                "resend": "pending",
            }[payload.action]
            connection.execute(
                "UPDATE organization_invitations SET status = ?, updated_at = ? WHERE id = ?",
                (status, timestamp, invitation_id),
            )
            if payload.action == "resend":
                _queue_provider_event(
                    connection,
                    provider_type="email",
                    event_type="organization.invitation_reminder",
                    destination=str(row["email"]),
                    payload={"invitation_id": invitation_id, "organization_id": organization_id},
                    idempotency_key=f"invitation:{invitation_id}:reminder:{timestamp[:13]}",
                )
        _audit(
            connection,
            actor_user_id=payload.actor_user_id,
            organization_id=organization_id,
            action=f"invitation.{payload.action}",
            target_type="organization_invitation",
            target_id=invitation_id,
        )
        connection.commit()
        result = connection.execute(
            "SELECT * FROM organization_invitations WHERE id = ?",
            (invitation_id,),
        ).fetchone()
        assert result is not None
        return dict(result)


@router.get("/support/tickets")
def list_support_tickets(
    actor_user_id: str = Query(...),
    scope_type: ScopeType = "personal",
    scope_id: str = Query(...),
    status: str = "",
) -> list[dict[str, Any]]:
    init_customer_ops_db()
    scope_key = _scope_key(scope_type, scope_id)
    with connect() as connection:
        _require_scope_access(connection, actor_user_id, scope_type, scope_id)
        sql = "SELECT * FROM support_tickets WHERE scope_key = ?"
        values: list[Any] = [scope_key]
        if status:
            sql += " AND status = ?"
            values.append(status)
        sql += " ORDER BY updated_at DESC"
        items = []
        for row in connection.execute(sql, tuple(values)).fetchall():
            item = _json_item(row, {"metadata_json": {}})
            item["events"] = [
                _json_item(event, {"metadata_json": {}})
                for event in connection.execute(
                    "SELECT * FROM support_ticket_events WHERE ticket_id = ? ORDER BY created_at",
                    (item["id"],),
                ).fetchall()
            ]
            items.append(item)
        return items


@router.post("/support/tickets")
def create_support_ticket(payload: SupportTicketCreate) -> dict[str, Any]:
    init_customer_ops_db()
    scope_key = _scope_key(payload.scope_type, payload.scope_id)
    ticket_id = make_id("ticket")
    timestamp = now_iso()
    with connect() as connection:
        _require_scope_access(connection, payload.actor_user_id, payload.scope_type, payload.scope_id)
        _ensure_shadow_user(connection, payload.actor_user_id, payload.actor_user_id, "analyst")
        connection.execute(
            "INSERT INTO support_tickets (id, scope_key, requester_user_id, organization_id, category, priority, status, subject, body, assigned_user_id, related_object_type, related_object_id, metadata_json, created_at, updated_at, resolved_at) VALUES (?, ?, ?, ?, ?, ?, 'open', ?, ?, NULL, ?, ?, ?, ?, ?, NULL)",
            (
                ticket_id,
                scope_key,
                payload.actor_user_id,
                payload.organization_id or None,
                payload.category,
                payload.priority,
                payload.subject.strip(),
                payload.body.strip(),
                payload.related_object_type or None,
                payload.related_object_id or None,
                encode_json(payload.metadata),
                timestamp,
                timestamp,
            ),
        )
        connection.execute(
            "INSERT INTO support_ticket_events (id, ticket_id, actor_user_id, event_type, message, is_customer_visible, metadata_json, created_at) VALUES (?, ?, ?, 'created', ?, 1, '{}', ?)",
            (make_id("support_event"), ticket_id, payload.actor_user_id, payload.body.strip(), timestamp),
        )
        outbox_id = _queue_provider_event(
            connection,
            provider_type="email",
            event_type="support.ticket_created",
            destination="support-operations",
            payload={"ticket_id": ticket_id, "subject": payload.subject, "priority": payload.priority},
            idempotency_key=f"support:{ticket_id}:created",
        )
        _audit(
            connection,
            actor_user_id=payload.actor_user_id,
            organization_id=payload.organization_id,
            action="support.ticket_created",
            target_type="support_ticket",
            target_id=ticket_id,
            payload={"priority": payload.priority, "outbox_id": outbox_id},
        )
        connection.commit()
    return list_support_tickets(payload.actor_user_id, payload.scope_type, payload.scope_id)[0]


@router.post("/support/tickets/{ticket_id}/events")
def add_support_ticket_event(ticket_id: str, payload: SupportTicketEventCreate) -> dict[str, Any]:
    init_customer_ops_db()
    timestamp = now_iso()
    with connect() as connection:
        ticket = connection.execute("SELECT * FROM support_tickets WHERE id = ?", (ticket_id,)).fetchone()
        if ticket is None:
            raise HTTPException(status_code=404, detail="Support ticket not found")
        scope_type, scope_id = str(ticket["scope_key"]).split(":", 1)
        operator = _user_role(connection, payload.actor_user_id) == "platform_admin"
        if not operator:
            _require_scope_access(connection, payload.actor_user_id, scope_type, scope_id)
        next_status = payload.status or str(ticket["status"])
        resolved_at = timestamp if next_status in {"resolved", "closed"} else None
        connection.execute(
            "INSERT INTO support_ticket_events (id, ticket_id, actor_user_id, event_type, message, is_customer_visible, metadata_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                make_id("support_event"),
                ticket_id,
                payload.actor_user_id,
                payload.event_type,
                payload.message,
                int(payload.is_customer_visible),
                encode_json(payload.metadata),
                timestamp,
            ),
        )
        connection.execute(
            "UPDATE support_tickets SET status = ?, assigned_user_id = COALESCE(NULLIF(?, ''), assigned_user_id), updated_at = ?, resolved_at = COALESCE(?, resolved_at) WHERE id = ?",
            (next_status, payload.assigned_user_id, timestamp, resolved_at, ticket_id),
        )
        _audit(
            connection,
            actor_user_id=payload.actor_user_id,
            organization_id=str(ticket["organization_id"] or ""),
            action=f"support.{payload.event_type}",
            target_type="support_ticket",
            target_id=ticket_id,
            payload={"status": next_status},
        )
        connection.commit()
        row = connection.execute("SELECT * FROM support_tickets WHERE id = ?", (ticket_id,)).fetchone()
        assert row is not None
        return _json_item(row, {"metadata_json": {}})


@router.get("/privacy/requests")
def list_privacy_requests(
    actor_user_id: str = Query(...),
    user_id: str = Query(...),
    status: str = "",
) -> list[dict[str, Any]]:
    init_customer_ops_db()
    with connect() as connection:
        _require_self_or_operator(connection, actor_user_id, user_id)
        sql = "SELECT * FROM privacy_requests WHERE user_id = ?"
        values: list[Any] = [user_id]
        if status:
            sql += " AND status = ?"
            values.append(status)
        sql += " ORDER BY requested_at DESC"
        items = []
        for row in connection.execute(sql, tuple(values)).fetchall():
            item = _json_item(row, {"metadata_json": {}})
            item["events"] = [
                _json_item(event, {"metadata_json": {}})
                for event in connection.execute(
                    "SELECT * FROM privacy_request_events WHERE request_id = ? ORDER BY created_at",
                    (item["id"],),
                ).fetchall()
            ]
            items.append(item)
        return items


@router.post("/privacy/requests")
def create_privacy_request(payload: PrivacyRequestCreate) -> dict[str, Any]:
    init_customer_ops_db()
    request_id = make_id("privacy")
    timestamp = now_iso()
    with connect() as connection:
        _require_self_or_operator(connection, payload.actor_user_id, payload.user_id)
        pending = connection.execute(
            "SELECT id FROM privacy_requests WHERE user_id = ? AND request_type = ? AND status NOT IN ('completed', 'rejected', 'cancelled')",
            (payload.user_id, payload.request_type),
        ).fetchone()
        if pending is not None:
            raise HTTPException(status_code=409, detail="A matching privacy request is already active")
        connection.execute(
            "INSERT INTO privacy_requests (id, user_id, organization_id, request_type, status, jurisdiction, details, verification_status, export_location, due_at, metadata_json, requested_at, updated_at, completed_at) VALUES (?, ?, ?, ?, 'requested', ?, ?, 'pending', NULL, ?, ?, ?, ?, NULL)",
            (
                request_id,
                payload.user_id,
                payload.organization_id or None,
                payload.request_type,
                payload.jurisdiction,
                payload.details,
                _utc_after(30),
                encode_json(payload.metadata),
                timestamp,
                timestamp,
            ),
        )
        connection.execute(
            "INSERT INTO privacy_request_events (id, request_id, actor_user_id, action, note, metadata_json, created_at) VALUES (?, ?, ?, 'requested', ?, '{}', ?)",
            (make_id("privacy_event"), request_id, payload.actor_user_id, payload.details, timestamp),
        )
        outbox_id = _queue_provider_event(
            connection,
            provider_type="email",
            event_type="privacy.request_received",
            destination=payload.user_id,
            payload={"request_id": request_id, "request_type": payload.request_type, "due_at": _utc_after(30)},
            idempotency_key=f"privacy:{request_id}:received",
        )
        _audit(
            connection,
            actor_user_id=payload.actor_user_id,
            organization_id=payload.organization_id,
            action="privacy.request_created",
            target_type="privacy_request",
            target_id=request_id,
            payload={"type": payload.request_type, "outbox_id": outbox_id},
        )
        connection.commit()
    return list_privacy_requests(payload.actor_user_id, payload.user_id)[0]


@router.post("/privacy/requests/{request_id}/action")
def act_on_privacy_request(request_id: str, payload: PrivacyRequestAction) -> dict[str, Any]:
    init_customer_ops_db()
    timestamp = now_iso()
    status_map = {
        "verify": "verified",
        "approve": "approved",
        "reject": "rejected",
        "start": "in_progress",
        "complete": "completed",
        "cancel": "cancelled",
    }
    with connect() as connection:
        row = connection.execute("SELECT * FROM privacy_requests WHERE id = ?", (request_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Privacy request not found")
        if payload.action == "cancel":
            _require_self_or_operator(connection, payload.actor_user_id, str(row["user_id"]))
        elif _user_role(connection, payload.actor_user_id) != "platform_admin":
            raise HTTPException(status_code=403, detail="Privacy operator access is required")
        next_status = status_map[payload.action]
        verification_status = "verified" if payload.action == "verify" else str(row["verification_status"])
        completed_at = timestamp if next_status == "completed" else None
        connection.execute(
            "UPDATE privacy_requests SET status = ?, verification_status = ?, export_location = COALESCE(NULLIF(?, ''), export_location), updated_at = ?, completed_at = COALESCE(?, completed_at) WHERE id = ?",
            (next_status, verification_status, payload.export_location, timestamp, completed_at, request_id),
        )
        connection.execute(
            "INSERT INTO privacy_request_events (id, request_id, actor_user_id, action, note, metadata_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (
                make_id("privacy_event"),
                request_id,
                payload.actor_user_id,
                payload.action,
                payload.note,
                encode_json(payload.metadata),
                timestamp,
            ),
        )
        _audit(
            connection,
            actor_user_id=payload.actor_user_id,
            organization_id=str(row["organization_id"] or ""),
            action=f"privacy.{payload.action}",
            target_type="privacy_request",
            target_id=request_id,
            payload={"status": next_status},
        )
        connection.commit()
        result = connection.execute("SELECT * FROM privacy_requests WHERE id = ?", (request_id,)).fetchone()
        assert result is not None
        return _json_item(result, {"metadata_json": {}})


@router.get("/notifications/{user_id}")
def list_customer_notifications(
    user_id: str,
    actor_user_id: str = Query(...),
    status: str = "",
    limit: int = 100,
) -> list[dict[str, Any]]:
    init_customer_ops_db()
    with connect() as connection:
        _require_self_or_operator(connection, actor_user_id, user_id)
        sql = "SELECT * FROM customer_notifications WHERE user_id = ?"
        values: list[Any] = [user_id]
        if status:
            sql += " AND status = ?"
            values.append(status)
        sql += " ORDER BY created_at DESC LIMIT ?"
        values.append(max(1, min(limit, 500)))
        return [
            _json_item(row, {"payload_json": {}})
            for row in connection.execute(sql, tuple(values)).fetchall()
        ]


@router.post("/notifications")
def create_customer_notification(payload: NotificationCreate) -> dict[str, Any]:
    init_customer_ops_db()
    notification_id = make_id("notification")
    timestamp = now_iso()
    with connect() as connection:
        if payload.actor_user_id != payload.user_id and _user_role(connection, payload.actor_user_id) != "platform_admin":
            if payload.organization_id:
                _require_org_role(connection, payload.organization_id, payload.actor_user_id, "admin")
            else:
                raise HTTPException(status_code=403, detail="Notification operator access is required")
        outbox_id = ""
        if payload.channel != "in_app":
            outbox_id = _queue_provider_event(
                connection,
                provider_type=payload.channel,
                event_type=f"notification.{payload.kind}",
                destination=payload.user_id,
                payload={"title": payload.title, "body": payload.body, **payload.metadata},
                idempotency_key=f"notification:{notification_id}",
            )
        connection.execute(
            "INSERT INTO customer_notifications (id, user_id, organization_id, kind, title, body, channel, status, payload_json, provider_outbox_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'unread', ?, ?, ?, ?)",
            (
                notification_id,
                payload.user_id,
                payload.organization_id or None,
                payload.kind,
                payload.title,
                payload.body,
                payload.channel,
                encode_json(payload.metadata),
                outbox_id or None,
                timestamp,
                timestamp,
            ),
        )
        connection.commit()
        row = connection.execute("SELECT * FROM customer_notifications WHERE id = ?", (notification_id,)).fetchone()
        assert row is not None
        return _json_item(row, {"payload_json": {}})


@router.post("/notifications/{notification_id}/action")
def act_on_notification(notification_id: str, payload: NotificationAction) -> dict[str, Any]:
    init_customer_ops_db()
    timestamp = now_iso()
    status_map = {"read": "read", "unread": "unread", "archive": "archived", "retry": "unread"}
    with connect() as connection:
        row = connection.execute("SELECT * FROM customer_notifications WHERE id = ?", (notification_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Notification not found")
        _require_self_or_operator(connection, payload.actor_user_id, str(row["user_id"]))
        connection.execute(
            "UPDATE customer_notifications SET status = ?, updated_at = ? WHERE id = ?",
            (status_map[payload.action], timestamp, notification_id),
        )
        if payload.action == "retry" and row["provider_outbox_id"]:
            connection.execute(
                "UPDATE provider_outbox SET status = 'pending', next_attempt_at = ?, updated_at = ? WHERE id = ?",
                (timestamp, timestamp, row["provider_outbox_id"]),
            )
        connection.commit()
        result = connection.execute("SELECT * FROM customer_notifications WHERE id = ?", (notification_id,)).fetchone()
        assert result is not None
        return _json_item(result, {"payload_json": {}})


@router.get("/providers/outbox")
def list_provider_outbox(
    actor_user_id: str = Query(...),
    status: str = "",
    provider_type: str = "",
    limit: int = 250,
) -> list[dict[str, Any]]:
    init_customer_ops_db()
    with connect() as connection:
        if _user_role(connection, actor_user_id) != "platform_admin":
            raise HTTPException(status_code=403, detail="Platform operator access is required")
        clauses: list[str] = []
        values: list[Any] = []
        if status:
            clauses.append("status = ?")
            values.append(status)
        if provider_type:
            clauses.append("provider_type = ?")
            values.append(provider_type)
        sql = "SELECT * FROM provider_outbox"
        if clauses:
            sql += " WHERE " + " AND ".join(clauses)
        sql += " ORDER BY created_at DESC LIMIT ?"
        values.append(max(1, min(limit, 1000)))
        return [
            _json_item(row, {"payload_json": {}})
            for row in connection.execute(sql, tuple(values)).fetchall()
        ]


@router.post("/providers/outbox/{event_id}/action")
def act_on_provider_outbox(event_id: str, payload: ProviderOutboxAction) -> dict[str, Any]:
    init_customer_ops_db()
    timestamp = now_iso()
    with connect() as connection:
        if _user_role(connection, payload.actor_user_id) != "platform_admin":
            raise HTTPException(status_code=403, detail="Platform operator access is required")
        row = connection.execute("SELECT * FROM provider_outbox WHERE id = ?", (event_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Provider event not found")
        if payload.action == "retry":
            status = "pending"
            delivered_at = None
            attempts = int(row["attempt_count"])
        elif payload.action == "deliver":
            status = "delivered"
            delivered_at = timestamp
            attempts = int(row["attempt_count"]) + 1
        elif payload.action == "fail":
            status = "failed"
            delivered_at = None
            attempts = int(row["attempt_count"]) + 1
        else:
            status = "cancelled"
            delivered_at = None
            attempts = int(row["attempt_count"])
        connection.execute(
            "UPDATE provider_outbox SET status = ?, attempt_count = ?, last_error = ?, next_attempt_at = ?, delivered_at = ?, updated_at = ? WHERE id = ?",
            (status, attempts, payload.error, timestamp, delivered_at, timestamp, event_id),
        )
        _audit(
            connection,
            actor_user_id=payload.actor_user_id,
            action=f"provider_outbox.{payload.action}",
            target_type="provider_outbox",
            target_id=event_id,
            payload={"status": status, "error": payload.error},
        )
        connection.commit()
        result = connection.execute("SELECT * FROM provider_outbox WHERE id = ?", (event_id,)).fetchone()
        assert result is not None
        return _json_item(result, {"payload_json": {}})


@router.post("/providers/webhooks/{provider_type}")
def receive_provider_webhook(provider_type: str, payload: WebhookReceipt) -> dict[str, Any]:
    init_customer_ops_db()
    timestamp = now_iso()
    with connect() as connection:
        existing = connection.execute(
            "SELECT * FROM provider_webhook_events WHERE provider_type = ? AND external_event_id = ?",
            (provider_type, payload.external_event_id),
        ).fetchone()
        if existing is not None:
            return _json_item(existing, {"payload_json": {}})
        event_id = make_id("webhook")
        connection.execute(
            "INSERT INTO provider_webhook_events (id, provider_type, external_event_id, event_type, payload_json, signature_valid, status, received_at, processed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)",
            (
                event_id,
                provider_type,
                payload.external_event_id,
                payload.event_type,
                encode_json(payload.payload),
                int(payload.signature_valid),
                "received" if payload.signature_valid else "quarantined",
                timestamp,
            ),
        )
        connection.commit()
        row = connection.execute("SELECT * FROM provider_webhook_events WHERE id = ?", (event_id,)).fetchone()
        assert row is not None
        return _json_item(row, {"payload_json": {}})


@router.get("/reliability/components")
def list_service_components() -> list[dict[str, Any]]:
    init_customer_ops_db()
    with connect() as connection:
        return [
            _json_item(row, {"metadata_json": {}})
            for row in connection.execute("SELECT * FROM service_components ORDER BY name").fetchall()
        ]


@router.put("/reliability/components/{component_id}")
def upsert_service_component(component_id: str, payload: ServiceComponentUpsert) -> dict[str, Any]:
    init_customer_ops_db()
    timestamp = now_iso()
    with connect() as connection:
        if _user_role(connection, payload.actor_user_id) != "platform_admin":
            raise HTTPException(status_code=403, detail="Platform operator access is required")
        connection.execute(
            "INSERT INTO service_components (id, name, status, description, public_message, metadata_json, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET name = excluded.name, status = excluded.status, description = excluded.description, public_message = excluded.public_message, metadata_json = excluded.metadata_json, updated_at = excluded.updated_at",
            (
                component_id,
                payload.name,
                payload.status,
                payload.description,
                payload.public_message,
                encode_json(payload.metadata),
                timestamp,
            ),
        )
        _audit(
            connection,
            actor_user_id=payload.actor_user_id,
            action="service_component.updated",
            target_type="service_component",
            target_id=component_id,
            payload={"status": payload.status},
        )
        connection.commit()
        row = connection.execute("SELECT * FROM service_components WHERE id = ?", (component_id,)).fetchone()
        assert row is not None
        return _json_item(row, {"metadata_json": {}})


@router.get("/reliability/incidents")
def list_incidents(status: str = "", limit: int = 100) -> list[dict[str, Any]]:
    init_customer_ops_db()
    with connect() as connection:
        sql = "SELECT * FROM service_incidents"
        values: list[Any] = []
        if status:
            sql += " WHERE status = ?"
            values.append(status)
        sql += " ORDER BY started_at DESC LIMIT ?"
        values.append(max(1, min(limit, 500)))
        items = []
        for row in connection.execute(sql, tuple(values)).fetchall():
            item = _json_item(row, {"component_ids_json": [], "metadata_json": {}})
            item["updates"] = [
                _json_item(update, {"component_statuses_json": {}, "metadata_json": {}})
                for update in connection.execute(
                    "SELECT * FROM service_incident_updates WHERE incident_id = ? ORDER BY created_at",
                    (item["id"],),
                ).fetchall()
            ]
            items.append(item)
        return items


@router.post("/reliability/incidents")
def create_incident(payload: IncidentCreate) -> dict[str, Any]:
    init_customer_ops_db()
    incident_id = make_id("incident")
    timestamp = now_iso()
    with connect() as connection:
        if _user_role(connection, payload.actor_user_id) != "platform_admin":
            raise HTTPException(status_code=403, detail="Platform operator access is required")
        connection.execute(
            "INSERT INTO service_incidents (id, severity, status, title, summary, impact, component_ids_json, metadata_json, created_by_user_id, started_at, updated_at, resolved_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)",
            (
                incident_id,
                payload.severity,
                payload.status,
                payload.title,
                payload.summary,
                payload.impact,
                encode_json(payload.component_ids),
                encode_json(payload.metadata),
                payload.actor_user_id,
                timestamp,
                timestamp,
            ),
        )
        for component_id in payload.component_ids:
            connection.execute(
                "UPDATE service_components SET status = 'degraded', public_message = ?, updated_at = ? WHERE id = ?",
                (payload.summary, timestamp, component_id),
            )
        _audit(
            connection,
            actor_user_id=payload.actor_user_id,
            action="incident.created",
            target_type="service_incident",
            target_id=incident_id,
            payload={"severity": payload.severity, "components": payload.component_ids},
        )
        connection.commit()
    return list_incidents()[0]


@router.post("/reliability/incidents/{incident_id}/updates")
def add_incident_update(incident_id: str, payload: IncidentUpdateCreate) -> dict[str, Any]:
    init_customer_ops_db()
    timestamp = now_iso()
    with connect() as connection:
        if _user_role(connection, payload.actor_user_id) != "platform_admin":
            raise HTTPException(status_code=403, detail="Platform operator access is required")
        incident = connection.execute("SELECT * FROM service_incidents WHERE id = ?", (incident_id,)).fetchone()
        if incident is None:
            raise HTTPException(status_code=404, detail="Incident not found")
        connection.execute(
            "INSERT INTO service_incident_updates (id, incident_id, actor_user_id, status, message, public_message, component_statuses_json, metadata_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                make_id("incident_update"),
                incident_id,
                payload.actor_user_id,
                payload.status,
                payload.message,
                payload.public_message,
                encode_json(payload.component_statuses),
                encode_json(payload.metadata),
                timestamp,
            ),
        )
        resolved_at = timestamp if payload.status in {"resolved", "closed", "postmortem"} else None
        connection.execute(
            "UPDATE service_incidents SET status = ?, updated_at = ?, resolved_at = COALESCE(?, resolved_at) WHERE id = ?",
            (payload.status, timestamp, resolved_at, incident_id),
        )
        for component_id, status in payload.component_statuses.items():
            connection.execute(
                "UPDATE service_components SET status = ?, public_message = ?, updated_at = ? WHERE id = ?",
                (status, payload.public_message, timestamp, component_id),
            )
        _audit(
            connection,
            actor_user_id=payload.actor_user_id,
            action="incident.updated",
            target_type="service_incident",
            target_id=incident_id,
            payload={"status": payload.status},
        )
        connection.commit()
        return next(item for item in list_incidents() if item["id"] == incident_id)


@router.get("/reliability/backups")
def list_backup_runs(actor_user_id: str = Query(...), limit: int = 100) -> list[dict[str, Any]]:
    init_customer_ops_db()
    with connect() as connection:
        if _user_role(connection, actor_user_id) != "platform_admin":
            raise HTTPException(status_code=403, detail="Platform operator access is required")
        return [
            _json_item(row, {"metadata_json": {}})
            for row in connection.execute(
                "SELECT * FROM backup_runs ORDER BY started_at DESC LIMIT ?",
                (max(1, min(limit, 500)),),
            ).fetchall()
        ]


@router.post("/reliability/backups")
def record_backup_run(payload: BackupRunCreate) -> dict[str, Any]:
    init_customer_ops_db()
    backup_id = make_id("backup")
    timestamp = now_iso()
    completed_at = timestamp if payload.status in {"completed", "verified", "failed"} else None
    with connect() as connection:
        if _user_role(connection, payload.actor_user_id) != "platform_admin":
            raise HTTPException(status_code=403, detail="Platform operator access is required")
        connection.execute(
            "INSERT INTO backup_runs (id, backup_type, status, location, checksum, size_bytes, restore_tested, metadata_json, started_at, completed_at, created_by_user_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                backup_id,
                payload.backup_type,
                payload.status,
                payload.location,
                payload.checksum,
                payload.size_bytes,
                int(payload.restore_tested),
                encode_json(payload.metadata),
                timestamp,
                completed_at,
                payload.actor_user_id,
            ),
        )
        _audit(
            connection,
            actor_user_id=payload.actor_user_id,
            action="backup.recorded",
            target_type="backup_run",
            target_id=backup_id,
            payload={"status": payload.status, "restore_tested": payload.restore_tested},
        )
        connection.commit()
        row = connection.execute("SELECT * FROM backup_runs WHERE id = ?", (backup_id,)).fetchone()
        assert row is not None
        return _json_item(row, {"metadata_json": {}})


@router.get("/retention/policies")
def list_retention_policies(actor_user_id: str = Query(...)) -> list[dict[str, Any]]:
    init_customer_ops_db()
    with connect() as connection:
        if _user_role(connection, actor_user_id) != "platform_admin":
            raise HTTPException(status_code=403, detail="Platform operator access is required")
        return [
            _json_item(row, {"metadata_json": {}})
            for row in connection.execute("SELECT * FROM retention_policies ORDER BY key").fetchall()
        ]


@router.put("/retention/policies/{key}")
def upsert_retention_policy(key: str, payload: RetentionPolicyUpsert) -> dict[str, Any]:
    if key != payload.key:
        raise HTTPException(status_code=400, detail="Retention policy path and payload key must match")
    init_customer_ops_db()
    timestamp = now_iso()
    with connect() as connection:
        if _user_role(connection, payload.actor_user_id) != "platform_admin":
            raise HTTPException(status_code=403, detail="Platform operator access is required")
        connection.execute(
            "INSERT INTO retention_policies (key, retention_days, action, enabled, legal_basis, description, metadata_json, updated_by_user_id, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(key) DO UPDATE SET retention_days = excluded.retention_days, action = excluded.action, enabled = excluded.enabled, legal_basis = excluded.legal_basis, description = excluded.description, metadata_json = excluded.metadata_json, updated_by_user_id = excluded.updated_by_user_id, updated_at = excluded.updated_at",
            (
                key,
                payload.retention_days,
                payload.action,
                int(payload.enabled),
                payload.legal_basis,
                payload.description,
                encode_json(payload.metadata),
                payload.actor_user_id,
                timestamp,
            ),
        )
        _audit(
            connection,
            actor_user_id=payload.actor_user_id,
            action="retention_policy.updated",
            target_type="retention_policy",
            target_id=key,
            payload={"days": payload.retention_days, "action": payload.action, "enabled": payload.enabled},
        )
        connection.commit()
        row = connection.execute("SELECT * FROM retention_policies WHERE key = ?", (key,)).fetchone()
        assert row is not None
        return _json_item(row, {"metadata_json": {}})


@router.get("/audit")
def list_customer_ops_audit(
    actor_user_id: str = Query(...),
    organization_id: str = "",
    limit: int = 250,
) -> list[dict[str, Any]]:
    init_customer_ops_db()
    with connect() as connection:
        if organization_id:
            _require_org_role(connection, organization_id, actor_user_id, "admin")
            sql = "SELECT * FROM customer_ops_audit_events WHERE organization_id = ? ORDER BY created_at DESC LIMIT ?"
            values = (organization_id, max(1, min(limit, 1000)))
        else:
            if _user_role(connection, actor_user_id) != "platform_admin":
                raise HTTPException(status_code=403, detail="Platform operator access is required")
            sql = "SELECT * FROM customer_ops_audit_events ORDER BY created_at DESC LIMIT ?"
            values = (max(1, min(limit, 1000)),)
        return [
            _json_item(row, {"payload_json": {}})
            for row in connection.execute(sql, values).fetchall()
        ]


@router.get("/account/{user_id}/overview")
def account_overview(
    user_id: str,
    actor_user_id: str = Query(...),
    organization_id: str = "",
) -> dict[str, Any]:
    init_customer_ops_db()
    with connect() as connection:
        _require_self_or_operator(connection, actor_user_id, user_id)
        user = connection.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        if user is None:
            raise HTTPException(status_code=404, detail="User not found")
        memberships = _rows(
            connection,
            "SELECT organization_memberships.*, organizations.name AS organization_name FROM organization_memberships JOIN organizations ON organizations.id = organization_memberships.organization_id WHERE organization_memberships.user_id = ? AND organization_memberships.status = 'active' ORDER BY organizations.name",
            (user_id,),
        )
        personal_subscription = get_subscription("personal", user_id, actor_user_id)
        personal_entitlements = get_entitlements("personal", user_id, actor_user_id)
        onboarding = get_onboarding("personal", user_id, actor_user_id)
        support_count = connection.execute(
            "SELECT COUNT(*) AS count FROM support_tickets WHERE requester_user_id = ? AND status NOT IN ('resolved', 'closed')",
            (user_id,),
        ).fetchone()["count"]
        privacy_count = connection.execute(
            "SELECT COUNT(*) AS count FROM privacy_requests WHERE user_id = ? AND status NOT IN ('completed', 'rejected', 'cancelled')",
            (user_id,),
        ).fetchone()["count"]
        unread_count = connection.execute(
            "SELECT COUNT(*) AS count FROM customer_notifications WHERE user_id = ? AND status = 'unread'",
            (user_id,),
        ).fetchone()["count"]
        organization = None
        if organization_id:
            _require_org_role(connection, organization_id, user_id, "analyst")
            organization = organization_overview(organization_id, user_id)
        return {
            "user": dict(user),
            "memberships": memberships,
            "subscription": personal_subscription,
            "entitlements": personal_entitlements,
            "onboarding": onboarding,
            "open_support_tickets": support_count,
            "open_privacy_requests": privacy_count,
            "unread_notifications": unread_count,
            "organization": organization,
            "provider_state": _provider_state(),
            "generated_at": now_iso(),
        }


@router.get("/organizations/{organization_id}/overview")
def organization_overview(
    organization_id: str,
    actor_user_id: str = Query(...),
) -> dict[str, Any]:
    init_customer_ops_db()
    with connect() as connection:
        role = _require_org_role(connection, organization_id, actor_user_id, "analyst")
        organization = connection.execute("SELECT * FROM organizations WHERE id = ?", (organization_id,)).fetchone()
        if organization is None:
            raise HTTPException(status_code=404, detail="Organization not found")
        subscription = get_subscription("organization", organization_id, actor_user_id)
        entitlements = get_entitlements("organization", organization_id, actor_user_id)
        onboarding = get_onboarding("organization", organization_id, actor_user_id)
        members = _rows(
            connection,
            "SELECT organization_memberships.*, users.display_name, users.email FROM organization_memberships JOIN users ON users.id = organization_memberships.user_id WHERE organization_memberships.organization_id = ? ORDER BY users.display_name",
            (organization_id,),
        )
        invitations = connection.execute(
            "SELECT COUNT(*) AS count FROM organization_invitations WHERE organization_id = ? AND status = 'pending'",
            (organization_id,),
        ).fetchone()["count"]
        support = connection.execute(
            "SELECT COUNT(*) AS count FROM support_tickets WHERE organization_id = ? AND status NOT IN ('resolved', 'closed')",
            (organization_id,),
        ).fetchone()["count"]
        return {
            "organization": dict(organization),
            "viewer_role": role,
            "subscription": subscription,
            "entitlements": entitlements,
            "onboarding": onboarding,
            "members": members,
            "active_seats": len([item for item in members if item.get("status") == "active"]),
            "seat_limit": subscription.get("seat_count", 1),
            "pending_invitations": invitations,
            "open_support_tickets": support,
            "generated_at": now_iso(),
        }


def _provider_state() -> dict[str, Any]:
    return {
        "billing": {
            "configured": bool(os.getenv("SPORTS_TERMINAL_PAYMENT_PROVIDER")),
            "mode": "provider" if os.getenv("SPORTS_TERMINAL_PAYMENT_PROVIDER") else "outbox_only",
        },
        "email": {
            "configured": bool(os.getenv("SPORTS_TERMINAL_EMAIL_PROVIDER")),
            "mode": "provider" if os.getenv("SPORTS_TERMINAL_EMAIL_PROVIDER") else "outbox_only",
        },
        "sms": {
            "configured": bool(os.getenv("SPORTS_TERMINAL_SMS_PROVIDER")),
            "mode": "provider" if os.getenv("SPORTS_TERMINAL_SMS_PROVIDER") else "outbox_only",
        },
        "monitoring": {
            "configured": bool(os.getenv("SPORTS_TERMINAL_MONITORING_PROVIDER")),
            "mode": "provider" if os.getenv("SPORTS_TERMINAL_MONITORING_PROVIDER") else "internal_status_only",
        },
        "managed_database": bool(os.getenv("DATABASE_URL")),
        "object_storage": bool(os.getenv("SPORTS_TERMINAL_OBJECT_STORAGE")),
        "secret_manager": bool(os.getenv("SPORTS_TERMINAL_SECRET_MANAGER")),
    }


@router.get("/readiness")
def customer_ops_readiness() -> dict[str, Any]:
    init_customer_ops_db()
    with connect() as connection:
        counts = {
            "subscriptions": connection.execute("SELECT COUNT(*) AS count FROM customer_subscriptions").fetchone()["count"],
            "onboarding_states": connection.execute("SELECT COUNT(*) AS count FROM onboarding_states").fetchone()["count"],
            "pending_invitations": connection.execute("SELECT COUNT(*) AS count FROM organization_invitations WHERE status = 'pending'").fetchone()["count"],
            "open_support_tickets": connection.execute("SELECT COUNT(*) AS count FROM support_tickets WHERE status NOT IN ('resolved', 'closed')").fetchone()["count"],
            "open_privacy_requests": connection.execute("SELECT COUNT(*) AS count FROM privacy_requests WHERE status NOT IN ('completed', 'rejected', 'cancelled')").fetchone()["count"],
            "pending_provider_events": connection.execute("SELECT COUNT(*) AS count FROM provider_outbox WHERE status IN ('pending', 'failed')").fetchone()["count"],
            "active_incidents": connection.execute("SELECT COUNT(*) AS count FROM service_incidents WHERE status NOT IN ('resolved', 'closed', 'postmortem')").fetchone()["count"],
            "backup_evidence": connection.execute("SELECT COUNT(*) AS count FROM backup_runs").fetchone()["count"],
            "retention_policies": connection.execute("SELECT COUNT(*) AS count FROM retention_policies WHERE enabled = 1").fetchone()["count"],
        }
        components = [
            _json_item(row, {"metadata_json": {}})
            for row in connection.execute("SELECT * FROM service_components ORDER BY name").fetchall()
        ]
    providers = _provider_state()
    provider_blockers = [
        key
        for key in ("billing", "email", "monitoring")
        if not providers[key]["configured"]
    ]
    infrastructure_blockers = [
        key
        for key in ("managed_database", "object_storage", "secret_manager")
        if not providers[key]
    ]
    internal_modules = {
        "plan_entitlements": "implemented",
        "subscription_lifecycle": "implemented",
        "organization_invitations": "implemented",
        "seat_visibility": "implemented",
        "onboarding": "implemented",
        "support_tickets": "implemented",
        "privacy_requests": "implemented",
        "notification_center": "implemented",
        "provider_outbox": "implemented",
        "webhook_receipts": "implemented",
        "service_components": "implemented",
        "incident_management": "implemented",
        "backup_evidence": "implemented",
        "retention_policies": "implemented",
        "operating_audit": "implemented",
    }
    return {
        "status": "externally_blocked" if provider_blockers or infrastructure_blockers else "launch_candidate",
        "internal_ready": True,
        "internal_modules": internal_modules,
        "record_counts": counts,
        "components": components,
        "provider_state": providers,
        "provider_blockers": provider_blockers,
        "infrastructure_blockers": infrastructure_blockers,
        "generated_at": now_iso(),
    }
