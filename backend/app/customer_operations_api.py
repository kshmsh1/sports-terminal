from __future__ import annotations

import sqlite3
from typing import Any, Literal

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from .launch_api import _ensure_shadow_user, _membership_role, _require_role, init_launch_db
from .main import connect, decode_json, encode_json, make_id, now_iso

router = APIRouter(prefix="/v2/customer-operations", tags=["customer-operations"])

Scope = Literal["personal", "organization"]


class OnboardingUpdate(BaseModel):
    actor_user_id: str
    scope: Scope = "personal"
    owner_user_id: str
    organization_id: str = ""
    completed_steps: list[str] = Field(default_factory=list)
    dismissed_steps: list[str] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)


class EntitlementUpdate(BaseModel):
    actor_user_id: str
    subject_type: Literal["user", "organization"]
    subject_id: str
    plan_id: str
    status: Literal["trialing", "active", "past_due", "suspended", "cancelled"] = "active"
    seats: int = Field(default=1, ge=1, le=10000)
    features: list[str] = Field(default_factory=list)
    limits: dict[str, int] = Field(default_factory=dict)
    trial_ends_at: str = ""
    renews_at: str = ""
    provider_reference: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class NotificationPreferenceUpdate(BaseModel):
    actor_user_id: str
    email_digest: bool = False
    product_updates: bool = True
    data_release_alerts: bool = True
    case_assignments: bool = True
    transaction_changes: bool = True
    community_activity: bool = True
    security_alerts: bool = True
    quiet_hours_start: str = ""
    quiet_hours_end: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class NotificationCreate(BaseModel):
    actor_user_id: str
    user_id: str
    organization_id: str = ""
    category: str
    title: str
    body: str
    severity: Literal["info", "success", "warning", "critical"] = "info"
    action_route: str = ""
    action_label: str = ""
    dedupe_key: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class SupportCaseCreate(BaseModel):
    actor_user_id: str
    scope: Scope = "personal"
    owner_user_id: str
    organization_id: str = ""
    category: str = "product"
    priority: Literal["low", "normal", "high", "urgent"] = "normal"
    subject: str
    description: str
    route_context: str = ""
    diagnostics: dict[str, Any] = Field(default_factory=dict)


class SupportCaseUpdate(BaseModel):
    actor_user_id: str
    status: Literal["open", "in_progress", "waiting_customer", "resolved", "closed"]
    assignee_user_id: str = ""
    resolution: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class SupportCommentCreate(BaseModel):
    actor_user_id: str
    body: str
    internal: bool = False


class IncidentCreate(BaseModel):
    actor_user_id: str
    organization_id: str
    title: str
    summary: str
    severity: Literal["minor", "major", "critical"] = "minor"
    status: Literal["investigating", "identified", "monitoring", "resolved"] = "investigating"
    affected_modules: list[str] = Field(default_factory=list)
    started_at: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class IncidentUpdate(BaseModel):
    actor_user_id: str
    status: Literal["investigating", "identified", "monitoring", "resolved"]
    summary: str = ""
    resolution: str = ""
    affected_modules: list[str] = Field(default_factory=list)
    resolved_at: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


def init_customer_operations_db() -> None:
    init_launch_db()
    with connect() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS onboarding_states (
              scope_key TEXT PRIMARY KEY,
              owner_user_id TEXT NOT NULL,
              organization_id TEXT,
              completed_steps_json TEXT NOT NULL DEFAULT '[]',
              dismissed_steps_json TEXT NOT NULL DEFAULT '[]',
              metadata_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS entitlement_states (
              subject_type TEXT NOT NULL,
              subject_id TEXT NOT NULL,
              plan_id TEXT NOT NULL,
              status TEXT NOT NULL,
              seats INTEGER NOT NULL DEFAULT 1,
              features_json TEXT NOT NULL DEFAULT '[]',
              limits_json TEXT NOT NULL DEFAULT '{}',
              trial_ends_at TEXT,
              renews_at TEXT,
              provider_reference TEXT,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              PRIMARY KEY (subject_type, subject_id)
            );

            CREATE TABLE IF NOT EXISTS notification_preferences_v2 (
              user_id TEXT PRIMARY KEY,
              payload_json TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS customer_notifications (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              organization_id TEXT,
              category TEXT NOT NULL,
              title TEXT NOT NULL,
              body TEXT NOT NULL,
              severity TEXT NOT NULL DEFAULT 'info',
              action_route TEXT,
              action_label TEXT,
              dedupe_key TEXT,
              is_read INTEGER NOT NULL DEFAULT 0,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS support_cases (
              id TEXT PRIMARY KEY,
              scope_key TEXT NOT NULL,
              owner_user_id TEXT NOT NULL,
              organization_id TEXT,
              category TEXT NOT NULL,
              priority TEXT NOT NULL,
              subject TEXT NOT NULL,
              description TEXT NOT NULL,
              route_context TEXT,
              diagnostics_json TEXT NOT NULL DEFAULT '{}',
              status TEXT NOT NULL DEFAULT 'open',
              assignee_user_id TEXT,
              resolution TEXT,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS support_case_comments (
              id TEXT PRIMARY KEY,
              case_id TEXT NOT NULL REFERENCES support_cases(id) ON DELETE CASCADE,
              author_user_id TEXT NOT NULL,
              body TEXT NOT NULL,
              internal INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS service_incidents (
              id TEXT PRIMARY KEY,
              organization_id TEXT NOT NULL,
              title TEXT NOT NULL,
              summary TEXT NOT NULL,
              severity TEXT NOT NULL,
              status TEXT NOT NULL,
              affected_modules_json TEXT NOT NULL DEFAULT '[]',
              started_at TEXT NOT NULL,
              resolved_at TEXT,
              resolution TEXT,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              created_by_user_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_customer_notifications_user
              ON customer_notifications(user_id, is_read, created_at DESC);
            CREATE UNIQUE INDEX IF NOT EXISTS idx_customer_notifications_dedupe
              ON customer_notifications(user_id, dedupe_key)
              WHERE dedupe_key IS NOT NULL AND dedupe_key != '';
            CREATE INDEX IF NOT EXISTS idx_support_cases_scope
              ON support_cases(scope_key, status, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_support_comments_case
              ON support_case_comments(case_id, created_at);
            CREATE INDEX IF NOT EXISTS idx_service_incidents_org
              ON service_incidents(organization_id, status, updated_at DESC);
            """
        )
        connection.commit()


def _scope_key(scope: Scope, owner_user_id: str, organization_id: str) -> str:
    if scope == "organization":
        if not organization_id:
            raise HTTPException(status_code=400, detail="Organization scope requires an organization ID")
        return f"organization:{organization_id}"
    if not owner_user_id:
        raise HTTPException(status_code=400, detail="Personal scope requires an owner user ID")
    return f"personal:{owner_user_id}"


def _ensure_scope_access(
    connection: sqlite3.Connection,
    *,
    actor_user_id: str,
    scope: Scope,
    owner_user_id: str,
    organization_id: str,
    minimum_role: str = "analyst",
) -> str:
    if scope == "organization":
        return _require_role(connection, organization_id, actor_user_id, minimum_role)
    if actor_user_id != owner_user_id:
        raise HTTPException(status_code=403, detail="Users can access only their personal customer operations")
    return "owner"


def _json_map(value: str | None) -> dict[str, Any]:
    decoded = decode_json(value, {})
    return decoded if isinstance(decoded, dict) else {}


def _json_list(value: str | None) -> list[Any]:
    decoded = decode_json(value, [])
    return decoded if isinstance(decoded, list) else []


def _serialize_notification(row: sqlite3.Row) -> dict[str, Any]:
    item = dict(row)
    item["is_read"] = bool(item["is_read"])
    item["metadata"] = _json_map(item.pop("metadata_json"))
    return item


def _serialize_support_case(connection: sqlite3.Connection, row: sqlite3.Row) -> dict[str, Any]:
    item = dict(row)
    item["diagnostics"] = _json_map(item.pop("diagnostics_json"))
    item["metadata"] = _json_map(item.pop("metadata_json"))
    comments = connection.execute(
        "SELECT * FROM support_case_comments WHERE case_id = ? ORDER BY created_at",
        (item["id"],),
    ).fetchall()
    item["comments"] = [
        {**dict(comment), "internal": bool(comment["internal"])} for comment in comments
    ]
    return item


def _serialize_incident(row: sqlite3.Row) -> dict[str, Any]:
    item = dict(row)
    item["affected_modules"] = _json_list(item.pop("affected_modules_json"))
    item["metadata"] = _json_map(item.pop("metadata_json"))
    return item


@router.on_event("startup")
def startup_customer_operations_api() -> None:
    init_customer_operations_db()


@router.get("/snapshot")
def customer_operations_snapshot(
    actor_user_id: str,
    scope: Scope = "personal",
    owner_user_id: str = "",
    organization_id: str = "",
) -> dict[str, Any]:
    init_customer_operations_db()
    owner = owner_user_id or actor_user_id
    scope_key = _scope_key(scope, owner, organization_id)
    with connect() as connection:
        _ensure_scope_access(
            connection,
            actor_user_id=actor_user_id,
            scope=scope,
            owner_user_id=owner,
            organization_id=organization_id,
        )
        onboarding_row = connection.execute(
            "SELECT * FROM onboarding_states WHERE scope_key = ?", (scope_key,)
        ).fetchone()
        subject_type = "organization" if scope == "organization" else "user"
        subject_id = organization_id if scope == "organization" else owner
        entitlement_row = connection.execute(
            "SELECT * FROM entitlement_states WHERE subject_type = ? AND subject_id = ?",
            (subject_type, subject_id),
        ).fetchone()
        preference_row = connection.execute(
            "SELECT payload_json FROM notification_preferences_v2 WHERE user_id = ?",
            (actor_user_id,),
        ).fetchone()
        notification_rows = connection.execute(
            "SELECT * FROM customer_notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 100",
            (actor_user_id,),
        ).fetchall()
        support_rows = connection.execute(
            "SELECT * FROM support_cases WHERE scope_key = ? ORDER BY updated_at DESC LIMIT 100",
            (scope_key,),
        ).fetchall()
        incidents: list[dict[str, Any]] = []
        if scope == "organization":
            incident_rows = connection.execute(
                "SELECT * FROM service_incidents WHERE organization_id = ? ORDER BY updated_at DESC LIMIT 100",
                (organization_id,),
            ).fetchall()
            incidents = [_serialize_incident(row) for row in incident_rows]
        active_members = 1
        if scope == "organization":
            active_members = int(
                connection.execute(
                    "SELECT COUNT(*) AS count FROM organization_memberships WHERE organization_id = ? AND status = 'active'",
                    (organization_id,),
                ).fetchone()["count"]
            )

        if onboarding_row is None:
            onboarding = {
                "scope_key": scope_key,
                "completed_steps": [],
                "dismissed_steps": [],
                "metadata": {},
                "updated_at": "",
            }
        else:
            onboarding = dict(onboarding_row)
            onboarding["completed_steps"] = _json_list(onboarding.pop("completed_steps_json"))
            onboarding["dismissed_steps"] = _json_list(onboarding.pop("dismissed_steps_json"))
            onboarding["metadata"] = _json_map(onboarding.pop("metadata_json"))

        if entitlement_row is None:
            entitlement = {
                "subject_type": subject_type,
                "subject_id": subject_id,
                "plan_id": "organization" if scope == "organization" else "individual",
                "status": "trialing",
                "seats": 10 if scope == "organization" else 1,
                "features": _default_features(scope),
                "limits": _default_limits(scope),
                "trial_ends_at": "",
                "renews_at": "",
                "provider_reference": "",
                "metadata": {"source": "default_launch_entitlement"},
            }
        else:
            entitlement = dict(entitlement_row)
            entitlement["features"] = _json_list(entitlement.pop("features_json"))
            entitlement["limits"] = _json_map(entitlement.pop("limits_json"))
            entitlement["metadata"] = _json_map(entitlement.pop("metadata_json"))

        return {
            "scope": scope,
            "scope_key": scope_key,
            "onboarding": onboarding,
            "entitlement": entitlement,
            "notification_preferences": _json_map(
                None if preference_row is None else preference_row["payload_json"]
            ) or _default_notification_preferences(actor_user_id),
            "notifications": [_serialize_notification(row) for row in notification_rows],
            "support_cases": [_serialize_support_case(connection, row) for row in support_rows],
            "incidents": incidents,
            "usage": {
                "active_members": active_members,
                "seat_limit": int(entitlement.get("seats", 1)),
                "unread_notifications": sum(1 for row in notification_rows if not bool(row["is_read"])),
                "open_support_cases": sum(1 for row in support_rows if row["status"] not in {"resolved", "closed"}),
                "active_incidents": sum(1 for item in incidents if item["status"] != "resolved"),
            },
            "generated_at": now_iso(),
        }


@router.put("/onboarding")
def update_onboarding(payload: OnboardingUpdate) -> dict[str, Any]:
    init_customer_operations_db()
    scope_key = _scope_key(payload.scope, payload.owner_user_id, payload.organization_id)
    timestamp = now_iso()
    with connect() as connection:
        _ensure_shadow_user(connection, payload.owner_user_id, payload.owner_user_id, "analyst")
        _ensure_scope_access(
            connection,
            actor_user_id=payload.actor_user_id,
            scope=payload.scope,
            owner_user_id=payload.owner_user_id,
            organization_id=payload.organization_id,
        )
        existing = connection.execute(
            "SELECT created_at FROM onboarding_states WHERE scope_key = ?", (scope_key,)
        ).fetchone()
        created_at = timestamp if existing is None else existing["created_at"]
        connection.execute(
            """
            INSERT INTO onboarding_states (
              scope_key, owner_user_id, organization_id, completed_steps_json,
              dismissed_steps_json, metadata_json, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(scope_key) DO UPDATE SET
              completed_steps_json = excluded.completed_steps_json,
              dismissed_steps_json = excluded.dismissed_steps_json,
              metadata_json = excluded.metadata_json,
              updated_at = excluded.updated_at
            """,
            (
                scope_key,
                payload.owner_user_id,
                payload.organization_id or None,
                encode_json(sorted(set(payload.completed_steps))),
                encode_json(sorted(set(payload.dismissed_steps))),
                encode_json(payload.metadata),
                created_at,
                timestamp,
            ),
        )
        connection.commit()
    return {"scope_key": scope_key, "completed_steps": sorted(set(payload.completed_steps)), "updated_at": timestamp}


@router.put("/entitlements")
def update_entitlement(payload: EntitlementUpdate) -> dict[str, Any]:
    init_customer_operations_db()
    timestamp = now_iso()
    with connect() as connection:
        if payload.subject_type == "organization":
            _require_role(connection, payload.subject_id, payload.actor_user_id, "admin")
        elif payload.actor_user_id != payload.subject_id:
            role = connection.execute(
                "SELECT role FROM users WHERE id = ?", (payload.actor_user_id,)
            ).fetchone()
            if role is None or role["role"] != "platform_admin":
                raise HTTPException(status_code=403, detail="Only the subject or a platform administrator can change an entitlement")
        existing = connection.execute(
            "SELECT created_at FROM entitlement_states WHERE subject_type = ? AND subject_id = ?",
            (payload.subject_type, payload.subject_id),
        ).fetchone()
        created_at = timestamp if existing is None else existing["created_at"]
        connection.execute(
            """
            INSERT INTO entitlement_states (
              subject_type, subject_id, plan_id, status, seats, features_json,
              limits_json, trial_ends_at, renews_at, provider_reference,
              metadata_json, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(subject_type, subject_id) DO UPDATE SET
              plan_id = excluded.plan_id, status = excluded.status, seats = excluded.seats,
              features_json = excluded.features_json, limits_json = excluded.limits_json,
              trial_ends_at = excluded.trial_ends_at, renews_at = excluded.renews_at,
              provider_reference = excluded.provider_reference,
              metadata_json = excluded.metadata_json, updated_at = excluded.updated_at
            """,
            (
                payload.subject_type,
                payload.subject_id,
                payload.plan_id,
                payload.status,
                payload.seats,
                encode_json(sorted(set(payload.features))),
                encode_json(payload.limits),
                payload.trial_ends_at or None,
                payload.renews_at or None,
                payload.provider_reference or None,
                encode_json(payload.metadata),
                created_at,
                timestamp,
            ),
        )
        connection.commit()
    return {"subject_type": payload.subject_type, "subject_id": payload.subject_id, "plan_id": payload.plan_id, "status": payload.status, "updated_at": timestamp}


@router.put("/notification-preferences")
def update_notification_preferences(payload: NotificationPreferenceUpdate) -> dict[str, Any]:
    init_customer_operations_db()
    timestamp = now_iso()
    preferences = payload.model_dump()
    preferences.pop("actor_user_id", None)
    with connect() as connection:
        _ensure_shadow_user(connection, payload.actor_user_id, payload.actor_user_id, "analyst")
        existing = connection.execute(
            "SELECT created_at FROM notification_preferences_v2 WHERE user_id = ?",
            (payload.actor_user_id,),
        ).fetchone()
        created_at = timestamp if existing is None else existing["created_at"]
        connection.execute(
            """
            INSERT INTO notification_preferences_v2 (user_id, payload_json, created_at, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET payload_json = excluded.payload_json,
              updated_at = excluded.updated_at
            """,
            (payload.actor_user_id, encode_json(preferences), created_at, timestamp),
        )
        connection.commit()
    return {"user_id": payload.actor_user_id, **preferences, "updated_at": timestamp}


@router.post("/notifications")
def create_notification(payload: NotificationCreate) -> dict[str, Any]:
    init_customer_operations_db()
    timestamp = now_iso()
    notification_id = make_id("notification")
    with connect() as connection:
        _ensure_shadow_user(connection, payload.user_id, payload.user_id, "analyst")
        if payload.organization_id:
            _require_role(connection, payload.organization_id, payload.actor_user_id, "analyst")
        elif payload.actor_user_id != payload.user_id:
            actor = connection.execute("SELECT role FROM users WHERE id = ?", (payload.actor_user_id,)).fetchone()
            if actor is None or actor["role"] != "platform_admin":
                raise HTTPException(status_code=403, detail="Users can create only their own notifications")
        if payload.dedupe_key:
            existing = connection.execute(
                "SELECT * FROM customer_notifications WHERE user_id = ? AND dedupe_key = ?",
                (payload.user_id, payload.dedupe_key),
            ).fetchone()
            if existing is not None:
                return _serialize_notification(existing)
        connection.execute(
            """
            INSERT INTO customer_notifications (
              id, user_id, organization_id, category, title, body, severity,
              action_route, action_label, dedupe_key, is_read, metadata_json,
              created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
            """,
            (
                notification_id,
                payload.user_id,
                payload.organization_id or None,
                payload.category,
                payload.title,
                payload.body,
                payload.severity,
                payload.action_route or None,
                payload.action_label or None,
                payload.dedupe_key or None,
                encode_json(payload.metadata),
                timestamp,
                timestamp,
            ),
        )
        connection.commit()
        row = connection.execute("SELECT * FROM customer_notifications WHERE id = ?", (notification_id,)).fetchone()
        assert row is not None
        return _serialize_notification(row)


@router.post("/notifications/{notification_id}/read")
def mark_notification_read(notification_id: str, actor_user_id: str = Query(...)) -> dict[str, Any]:
    init_customer_operations_db()
    timestamp = now_iso()
    with connect() as connection:
        row = connection.execute(
            "SELECT user_id FROM customer_notifications WHERE id = ?", (notification_id,)
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Notification not found")
        if row["user_id"] != actor_user_id:
            raise HTTPException(status_code=403, detail="Users can read only their own notifications")
        connection.execute(
            "UPDATE customer_notifications SET is_read = 1, updated_at = ? WHERE id = ?",
            (timestamp, notification_id),
        )
        connection.commit()
    return {"id": notification_id, "is_read": True, "updated_at": timestamp}


@router.post("/notifications/read-all")
def mark_all_notifications_read(actor_user_id: str = Query(...)) -> dict[str, Any]:
    init_customer_operations_db()
    timestamp = now_iso()
    with connect() as connection:
        cursor = connection.execute(
            "UPDATE customer_notifications SET is_read = 1, updated_at = ? WHERE user_id = ? AND is_read = 0",
            (timestamp, actor_user_id),
        )
        connection.commit()
    return {"updated": cursor.rowcount, "updated_at": timestamp}


@router.post("/support-cases")
def create_support_case(payload: SupportCaseCreate) -> dict[str, Any]:
    init_customer_operations_db()
    scope_key = _scope_key(payload.scope, payload.owner_user_id, payload.organization_id)
    timestamp = now_iso()
    case_id = make_id("support")
    with connect() as connection:
        _ensure_scope_access(
            connection,
            actor_user_id=payload.actor_user_id,
            scope=payload.scope,
            owner_user_id=payload.owner_user_id,
            organization_id=payload.organization_id,
        )
        connection.execute(
            """
            INSERT INTO support_cases (
              id, scope_key, owner_user_id, organization_id, category, priority,
              subject, description, route_context, diagnostics_json, status,
              metadata_json, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'open', '{}', ?, ?)
            """,
            (
                case_id,
                scope_key,
                payload.owner_user_id,
                payload.organization_id or None,
                payload.category,
                payload.priority,
                payload.subject,
                payload.description,
                payload.route_context or None,
                encode_json(payload.diagnostics),
                timestamp,
                timestamp,
            ),
        )
        connection.commit()
        row = connection.execute("SELECT * FROM support_cases WHERE id = ?", (case_id,)).fetchone()
        assert row is not None
        return _serialize_support_case(connection, row)


@router.patch("/support-cases/{case_id}")
def update_support_case(case_id: str, payload: SupportCaseUpdate) -> dict[str, Any]:
    init_customer_operations_db()
    timestamp = now_iso()
    with connect() as connection:
        row = connection.execute("SELECT * FROM support_cases WHERE id = ?", (case_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Support case not found")
        if row["organization_id"]:
            _require_role(connection, row["organization_id"], payload.actor_user_id, "admin")
        elif row["owner_user_id"] != payload.actor_user_id:
            actor = connection.execute("SELECT role FROM users WHERE id = ?", (payload.actor_user_id,)).fetchone()
            if actor is None or actor["role"] != "platform_admin":
                raise HTTPException(status_code=403, detail="Only the owner or an administrator can update this support case")
        connection.execute(
            """
            UPDATE support_cases SET status = ?, assignee_user_id = ?, resolution = ?,
              metadata_json = ?, updated_at = ? WHERE id = ?
            """,
            (
                payload.status,
                payload.assignee_user_id or None,
                payload.resolution or None,
                encode_json(payload.metadata),
                timestamp,
                case_id,
            ),
        )
        connection.commit()
        updated = connection.execute("SELECT * FROM support_cases WHERE id = ?", (case_id,)).fetchone()
        assert updated is not None
        return _serialize_support_case(connection, updated)


@router.post("/support-cases/{case_id}/comments")
def add_support_comment(case_id: str, payload: SupportCommentCreate) -> dict[str, Any]:
    init_customer_operations_db()
    timestamp = now_iso()
    comment_id = make_id("support_comment")
    with connect() as connection:
        row = connection.execute("SELECT * FROM support_cases WHERE id = ?", (case_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Support case not found")
        is_admin = False
        if row["organization_id"]:
            role = _membership_role(connection, row["organization_id"], payload.actor_user_id)
            is_admin = role in {"admin", "owner", "platform_admin"}
            if role is None:
                raise HTTPException(status_code=403, detail="Organization membership is required")
        elif row["owner_user_id"] != payload.actor_user_id:
            actor = connection.execute("SELECT role FROM users WHERE id = ?", (payload.actor_user_id,)).fetchone()
            is_admin = actor is not None and actor["role"] == "platform_admin"
            if not is_admin:
                raise HTTPException(status_code=403, detail="Support case access denied")
        if payload.internal and not is_admin:
            raise HTTPException(status_code=403, detail="Only administrators can add internal comments")
        connection.execute(
            "INSERT INTO support_case_comments (id, case_id, author_user_id, body, internal, created_at) VALUES (?, ?, ?, ?, ?, ?)",
            (comment_id, case_id, payload.actor_user_id, payload.body, int(payload.internal), timestamp),
        )
        connection.execute("UPDATE support_cases SET updated_at = ? WHERE id = ?", (timestamp, case_id))
        connection.commit()
    return {"id": comment_id, "case_id": case_id, "author_user_id": payload.actor_user_id, "body": payload.body, "internal": payload.internal, "created_at": timestamp}


@router.post("/incidents")
def create_incident(payload: IncidentCreate) -> dict[str, Any]:
    init_customer_operations_db()
    timestamp = now_iso()
    incident_id = make_id("incident")
    with connect() as connection:
        _require_role(connection, payload.organization_id, payload.actor_user_id, "admin")
        connection.execute(
            """
            INSERT INTO service_incidents (
              id, organization_id, title, summary, severity, status,
              affected_modules_json, started_at, metadata_json, created_by_user_id,
              created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                incident_id,
                payload.organization_id,
                payload.title,
                payload.summary,
                payload.severity,
                payload.status,
                encode_json(payload.affected_modules),
                payload.started_at or timestamp,
                encode_json(payload.metadata),
                payload.actor_user_id,
                timestamp,
                timestamp,
            ),
        )
        connection.commit()
        row = connection.execute("SELECT * FROM service_incidents WHERE id = ?", (incident_id,)).fetchone()
        assert row is not None
        return _serialize_incident(row)


@router.patch("/incidents/{incident_id}")
def update_incident(incident_id: str, payload: IncidentUpdate) -> dict[str, Any]:
    init_customer_operations_db()
    timestamp = now_iso()
    with connect() as connection:
        row = connection.execute("SELECT * FROM service_incidents WHERE id = ?", (incident_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Incident not found")
        _require_role(connection, row["organization_id"], payload.actor_user_id, "admin")
        resolved_at = payload.resolved_at or (timestamp if payload.status == "resolved" else row["resolved_at"])
        affected = payload.affected_modules or _json_list(row["affected_modules_json"])
        summary = payload.summary or row["summary"]
        connection.execute(
            """
            UPDATE service_incidents SET status = ?, summary = ?, resolution = ?,
              affected_modules_json = ?, resolved_at = ?, metadata_json = ?, updated_at = ?
            WHERE id = ?
            """,
            (
                payload.status,
                summary,
                payload.resolution or row["resolution"],
                encode_json(affected),
                resolved_at,
                encode_json(payload.metadata),
                timestamp,
                incident_id,
            ),
        )
        connection.commit()
        updated = connection.execute("SELECT * FROM service_incidents WHERE id = ?", (incident_id,)).fetchone()
        assert updated is not None
        return _serialize_incident(updated)


def _default_features(scope: Scope) -> list[str]:
    common = [
        "nba_2025_26_data",
        "workspace",
        "python_runtime",
        "trade_machine",
        "front_office_registry",
        "community",
        "messaging",
        "support",
    ]
    if scope == "organization":
        return common + [
            "shared_cases",
            "workspace_permissions",
            "organization_admin",
            "trust_safety",
            "incident_management",
            "audit_exports",
        ]
    return common + ["personal_alerts", "saved_objects"]


def _default_limits(scope: Scope) -> dict[str, int]:
    if scope == "organization":
        return {
            "seats": 10,
            "saved_objects": 10000,
            "workspace_versions": 50,
            "python_rows_per_run": 500,
            "open_support_cases": 100,
        }
    return {
        "seats": 1,
        "saved_objects": 500,
        "workspace_versions": 50,
        "python_rows_per_run": 500,
        "open_support_cases": 10,
    }


def _default_notification_preferences(user_id: str) -> dict[str, Any]:
    return {
        "user_id": user_id,
        "email_digest": False,
        "product_updates": True,
        "data_release_alerts": True,
        "case_assignments": True,
        "transaction_changes": True,
        "community_activity": True,
        "security_alerts": True,
        "quiet_hours_start": "",
        "quiet_hours_end": "",
        "metadata": {"source": "launch_defaults"},
    }
