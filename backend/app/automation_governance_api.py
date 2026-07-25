from __future__ import annotations

import hashlib
import json
import sqlite3
from typing import Any, Literal

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from .launch_api import _ensure_shadow_user, _require_role, init_launch_db
from .main import connect, decode_json, encode_json, make_id, now_iso

router = APIRouter(prefix="/v2/automation-governance", tags=["automation-governance"])

Scope = Literal["personal", "organization"]


class AlertRuleUpsert(BaseModel):
    actor_user_id: str
    scope: Scope = "personal"
    owner_user_id: str
    organization_id: str = ""
    name: str
    category: str
    condition: dict[str, Any] = Field(default_factory=dict)
    delivery_channels: list[str] = Field(default_factory=lambda: ["in_app"])
    enabled: bool = True
    cooldown_minutes: int = Field(default=60, ge=1, le=43200)
    metadata: dict[str, Any] = Field(default_factory=dict)


class ScheduledReportUpsert(BaseModel):
    actor_user_id: str
    scope: Scope = "personal"
    owner_user_id: str
    organization_id: str = ""
    title: str
    report_type: str
    source_route: str = ""
    schedule: str = "manual"
    delivery_channels: list[str] = Field(default_factory=lambda: ["in_app"])
    recipients: list[str] = Field(default_factory=list)
    filters: dict[str, Any] = Field(default_factory=dict)
    enabled: bool = True
    metadata: dict[str, Any] = Field(default_factory=dict)


class OrganizationInviteCreate(BaseModel):
    actor_user_id: str
    organization_id: str
    email: str
    role: Literal["viewer", "analyst", "reviewer", "admin"] = "analyst"
    expires_at: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class InviteAccept(BaseModel):
    actor_user_id: str
    display_name: str = "Organization Member"


class DataReleaseEventCreate(BaseModel):
    actor_user_id: str
    release_id: str
    stage: Literal["ingested", "validated", "certified", "published", "rolled_back"]
    source_manifest: dict[str, Any] = Field(default_factory=dict)
    validation: dict[str, Any] = Field(default_factory=dict)
    notes: str = ""


class ExportRequestCreate(BaseModel):
    actor_user_id: str
    scope: Scope = "personal"
    owner_user_id: str
    organization_id: str = ""
    export_type: Literal["account", "workspace", "transactions", "audit", "support", "full"]
    filters: dict[str, Any] = Field(default_factory=dict)
    format: Literal["json", "csv"] = "json"
    metadata: dict[str, Any] = Field(default_factory=dict)


class AccountDeletionRequest(BaseModel):
    actor_user_id: str
    owner_user_id: str
    reason: str = ""
    confirmation: str


class DeliveryJobCreate(BaseModel):
    actor_user_id: str
    organization_id: str = ""
    user_id: str = ""
    job_type: Literal["alert", "report", "export", "digest", "security"]
    channel: Literal["in_app", "email", "webhook"] = "in_app"
    payload: dict[str, Any] = Field(default_factory=dict)
    dedupe_key: str = ""
    scheduled_for: str = ""


def init_automation_governance_db() -> None:
    init_launch_db()
    with connect() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS alert_rules (
              id TEXT PRIMARY KEY,
              scope_key TEXT NOT NULL,
              owner_user_id TEXT NOT NULL,
              organization_id TEXT,
              name TEXT NOT NULL,
              category TEXT NOT NULL,
              condition_json TEXT NOT NULL DEFAULT '{}',
              delivery_channels_json TEXT NOT NULL DEFAULT '[]',
              enabled INTEGER NOT NULL DEFAULT 1,
              cooldown_minutes INTEGER NOT NULL DEFAULT 60,
              last_triggered_at TEXT,
              trigger_count INTEGER NOT NULL DEFAULT 0,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS scheduled_reports (
              id TEXT PRIMARY KEY,
              scope_key TEXT NOT NULL,
              owner_user_id TEXT NOT NULL,
              organization_id TEXT,
              title TEXT NOT NULL,
              report_type TEXT NOT NULL,
              source_route TEXT,
              schedule TEXT NOT NULL,
              delivery_channels_json TEXT NOT NULL DEFAULT '[]',
              recipients_json TEXT NOT NULL DEFAULT '[]',
              filters_json TEXT NOT NULL DEFAULT '{}',
              enabled INTEGER NOT NULL DEFAULT 1,
              last_run_at TEXT,
              next_run_at TEXT,
              run_count INTEGER NOT NULL DEFAULT 0,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS organization_invites (
              id TEXT PRIMARY KEY,
              organization_id TEXT NOT NULL,
              email TEXT NOT NULL,
              role TEXT NOT NULL,
              token_hash TEXT NOT NULL UNIQUE,
              status TEXT NOT NULL DEFAULT 'pending',
              invited_by_user_id TEXT NOT NULL,
              accepted_by_user_id TEXT,
              expires_at TEXT,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS data_release_events (
              id TEXT PRIMARY KEY,
              release_id TEXT NOT NULL,
              stage TEXT NOT NULL,
              source_manifest_json TEXT NOT NULL DEFAULT '{}',
              validation_json TEXT NOT NULL DEFAULT '{}',
              notes TEXT,
              actor_user_id TEXT NOT NULL,
              created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS export_requests (
              id TEXT PRIMARY KEY,
              scope_key TEXT NOT NULL,
              owner_user_id TEXT NOT NULL,
              organization_id TEXT,
              export_type TEXT NOT NULL,
              format TEXT NOT NULL,
              filters_json TEXT NOT NULL DEFAULT '{}',
              status TEXT NOT NULL DEFAULT 'queued',
              artifact_reference TEXT,
              checksum TEXT,
              record_count INTEGER NOT NULL DEFAULT 0,
              error TEXT,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              requested_at TEXT NOT NULL,
              completed_at TEXT,
              updated_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS account_deletion_requests (
              id TEXT PRIMARY KEY,
              owner_user_id TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'pending',
              reason TEXT,
              requested_at TEXT NOT NULL,
              cooling_off_ends_at TEXT,
              completed_at TEXT,
              audit_json TEXT NOT NULL DEFAULT '{}'
            );
            CREATE TABLE IF NOT EXISTS delivery_jobs (
              id TEXT PRIMARY KEY,
              organization_id TEXT,
              user_id TEXT,
              job_type TEXT NOT NULL,
              channel TEXT NOT NULL,
              payload_json TEXT NOT NULL DEFAULT '{}',
              dedupe_key TEXT,
              status TEXT NOT NULL DEFAULT 'queued',
              attempts INTEGER NOT NULL DEFAULT 0,
              scheduled_for TEXT,
              locked_at TEXT,
              delivered_at TEXT,
              last_error TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS governance_audit_events (
              id TEXT PRIMARY KEY,
              actor_user_id TEXT NOT NULL,
              organization_id TEXT,
              action TEXT NOT NULL,
              target_type TEXT NOT NULL,
              target_id TEXT NOT NULL,
              payload_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_alert_rules_scope ON alert_rules(scope_key, enabled, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_reports_scope ON scheduled_reports(scope_key, enabled, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_invites_org ON organization_invites(organization_id, status, created_at DESC);
            CREATE UNIQUE INDEX IF NOT EXISTS idx_invites_pending_email ON organization_invites(organization_id, email) WHERE status = 'pending';
            CREATE INDEX IF NOT EXISTS idx_release_events_release ON data_release_events(release_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_exports_scope ON export_requests(scope_key, requested_at DESC);
            CREATE INDEX IF NOT EXISTS idx_delivery_status ON delivery_jobs(status, scheduled_for, created_at);
            CREATE UNIQUE INDEX IF NOT EXISTS idx_delivery_dedupe ON delivery_jobs(dedupe_key) WHERE dedupe_key IS NOT NULL AND dedupe_key != '';
            CREATE INDEX IF NOT EXISTS idx_governance_audit_org ON governance_audit_events(organization_id, created_at DESC);
            """
        )
        connection.commit()


def _scope_key(scope: Scope, owner_user_id: str, organization_id: str) -> str:
    if scope == "organization":
        if not organization_id:
            raise HTTPException(status_code=400, detail="Organization scope requires organization_id")
        return f"organization:{organization_id}"
    if not owner_user_id:
        raise HTTPException(status_code=400, detail="Personal scope requires owner_user_id")
    return f"personal:{owner_user_id}"


def _require_scope(connection: sqlite3.Connection, *, actor: str, scope: Scope, owner: str, organization: str, role: str = "analyst") -> None:
    if scope == "organization":
        _require_role(connection, organization, actor, role)
    elif actor != owner:
        raise HTTPException(status_code=403, detail="Users can access only their personal automation scope")


def _audit(connection: sqlite3.Connection, *, actor: str, organization: str, action: str, target_type: str, target_id: str, payload: dict[str, Any] | None = None) -> None:
    connection.execute(
        "INSERT INTO governance_audit_events (id, actor_user_id, organization_id, action, target_type, target_id, payload_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (make_id("gov"), actor, organization or None, action, target_type, target_id, encode_json(payload or {}), now_iso()),
    )


def _row(row: sqlite3.Row) -> dict[str, Any]:
    item = dict(row)
    for key in list(item):
        if key.endswith("_json"):
            item[key[:-5]] = decode_json(item.pop(key), {} if key in {"condition_json", "filters_json", "metadata_json", "payload_json", "validation_json", "source_manifest_json", "audit_json"} else [])
    for key in ("enabled",):
        if key in item:
            item[key] = bool(item[key])
    return item


@router.on_event("startup")
def startup() -> None:
    init_automation_governance_db()


@router.get("/alert-rules")
def list_alert_rules(owner_user_id: str, scope: Scope = "personal", organization_id: str = "") -> list[dict[str, Any]]:
    init_automation_governance_db()
    key = _scope_key(scope, owner_user_id, organization_id)
    with connect() as connection:
        return [_row(row) for row in connection.execute("SELECT * FROM alert_rules WHERE scope_key = ? ORDER BY updated_at DESC", (key,)).fetchall()]


@router.put("/alert-rules/{rule_id}")
def upsert_alert_rule(rule_id: str, payload: AlertRuleUpsert) -> dict[str, Any]:
    init_automation_governance_db()
    key = _scope_key(payload.scope, payload.owner_user_id, payload.organization_id)
    timestamp = now_iso()
    with connect() as connection:
        _require_scope(connection, actor=payload.actor_user_id, scope=payload.scope, owner=payload.owner_user_id, organization=payload.organization_id)
        existing = connection.execute("SELECT created_at FROM alert_rules WHERE id = ?", (rule_id,)).fetchone()
        created = timestamp if existing is None else existing["created_at"]
        connection.execute("""
          INSERT INTO alert_rules (id, scope_key, owner_user_id, organization_id, name, category, condition_json, delivery_channels_json, enabled, cooldown_minutes, metadata_json, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET name=excluded.name, category=excluded.category, condition_json=excluded.condition_json, delivery_channels_json=excluded.delivery_channels_json, enabled=excluded.enabled, cooldown_minutes=excluded.cooldown_minutes, metadata_json=excluded.metadata_json, updated_at=excluded.updated_at
        """, (rule_id, key, payload.owner_user_id, payload.organization_id or None, payload.name, payload.category, encode_json(payload.condition), encode_json(payload.delivery_channels), int(payload.enabled), payload.cooldown_minutes, encode_json(payload.metadata), created, timestamp))
        _audit(connection, actor=payload.actor_user_id, organization=payload.organization_id, action="alert_rule_upserted", target_type="alert_rule", target_id=rule_id)
        connection.commit()
        return _row(connection.execute("SELECT * FROM alert_rules WHERE id = ?", (rule_id,)).fetchone())


@router.delete("/alert-rules/{rule_id}")
def delete_alert_rule(rule_id: str, actor_user_id: str = Query(...)) -> dict[str, Any]:
    init_automation_governance_db()
    with connect() as connection:
        row = connection.execute("SELECT * FROM alert_rules WHERE id = ?", (rule_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Alert rule not found")
        scope = "organization" if str(row["scope_key"]).startswith("organization:") else "personal"
        _require_scope(connection, actor=actor_user_id, scope=scope, owner=row["owner_user_id"], organization=row["organization_id"] or "")
        connection.execute("DELETE FROM alert_rules WHERE id = ?", (rule_id,))
        _audit(connection, actor=actor_user_id, organization=row["organization_id"] or "", action="alert_rule_deleted", target_type="alert_rule", target_id=rule_id)
        connection.commit()
    return {"deleted": True, "id": rule_id}


@router.get("/scheduled-reports")
def list_scheduled_reports(owner_user_id: str, scope: Scope = "personal", organization_id: str = "") -> list[dict[str, Any]]:
    init_automation_governance_db()
    key = _scope_key(scope, owner_user_id, organization_id)
    with connect() as connection:
        return [_row(row) for row in connection.execute("SELECT * FROM scheduled_reports WHERE scope_key = ? ORDER BY updated_at DESC", (key,)).fetchall()]


@router.put("/scheduled-reports/{report_id}")
def upsert_scheduled_report(report_id: str, payload: ScheduledReportUpsert) -> dict[str, Any]:
    init_automation_governance_db()
    key = _scope_key(payload.scope, payload.owner_user_id, payload.organization_id)
    timestamp = now_iso()
    with connect() as connection:
        _require_scope(connection, actor=payload.actor_user_id, scope=payload.scope, owner=payload.owner_user_id, organization=payload.organization_id)
        existing = connection.execute("SELECT created_at FROM scheduled_reports WHERE id = ?", (report_id,)).fetchone()
        created = timestamp if existing is None else existing["created_at"]
        connection.execute("""
          INSERT INTO scheduled_reports (id, scope_key, owner_user_id, organization_id, title, report_type, source_route, schedule, delivery_channels_json, recipients_json, filters_json, enabled, metadata_json, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET title=excluded.title, report_type=excluded.report_type, source_route=excluded.source_route, schedule=excluded.schedule, delivery_channels_json=excluded.delivery_channels_json, recipients_json=excluded.recipients_json, filters_json=excluded.filters_json, enabled=excluded.enabled, metadata_json=excluded.metadata_json, updated_at=excluded.updated_at
        """, (report_id, key, payload.owner_user_id, payload.organization_id or None, payload.title, payload.report_type, payload.source_route, payload.schedule, encode_json(payload.delivery_channels), encode_json(payload.recipients), encode_json(payload.filters), int(payload.enabled), encode_json(payload.metadata), created, timestamp))
        _audit(connection, actor=payload.actor_user_id, organization=payload.organization_id, action="scheduled_report_upserted", target_type="scheduled_report", target_id=report_id)
        connection.commit()
        return _row(connection.execute("SELECT * FROM scheduled_reports WHERE id = ?", (report_id,)).fetchone())


@router.post("/organizations/{organization_id}/invites")
def create_invite(organization_id: str, payload: OrganizationInviteCreate) -> dict[str, Any]:
    init_automation_governance_db()
    if organization_id != payload.organization_id:
        raise HTTPException(status_code=400, detail="Organization IDs do not match")
    timestamp = now_iso()
    invite_id = make_id("invite")
    raw_token = make_id("join") + make_id("token")
    token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
    with connect() as connection:
        _require_role(connection, organization_id, payload.actor_user_id, "admin")
        try:
            connection.execute("INSERT INTO organization_invites (id, organization_id, email, role, token_hash, status, invited_by_user_id, expires_at, metadata_json, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?, ?)", (invite_id, organization_id, payload.email.strip().lower(), payload.role, token_hash, payload.actor_user_id, payload.expires_at or None, encode_json(payload.metadata), timestamp, timestamp))
        except sqlite3.IntegrityError as error:
            raise HTTPException(status_code=409, detail="A pending invite already exists for this email") from error
        _audit(connection, actor=payload.actor_user_id, organization=organization_id, action="organization_invite_created", target_type="organization_invite", target_id=invite_id, payload={"email": payload.email, "role": payload.role})
        connection.commit()
    return {"id": invite_id, "organization_id": organization_id, "email": payload.email.strip().lower(), "role": payload.role, "status": "pending", "token": raw_token, "created_at": timestamp}


@router.get("/organizations/{organization_id}/invites")
def list_invites(organization_id: str, actor_user_id: str = Query(...)) -> list[dict[str, Any]]:
    init_automation_governance_db()
    with connect() as connection:
        _require_role(connection, organization_id, actor_user_id, "admin")
        return [_row(row) for row in connection.execute("SELECT id, organization_id, email, role, status, invited_by_user_id, accepted_by_user_id, expires_at, metadata_json, created_at, updated_at FROM organization_invites WHERE organization_id = ? ORDER BY created_at DESC", (organization_id,)).fetchall()]


@router.post("/invites/{token}/accept")
def accept_invite(token: str, payload: InviteAccept) -> dict[str, Any]:
    init_automation_governance_db()
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    with connect() as connection:
        row = connection.execute("SELECT * FROM organization_invites WHERE token_hash = ?", (token_hash,)).fetchone()
        if row is None or row["status"] != "pending":
            raise HTTPException(status_code=404, detail="Invite is invalid or no longer pending")
        _ensure_shadow_user(connection, payload.actor_user_id, payload.display_name, row["role"])
        timestamp = now_iso()
        connection.execute("INSERT INTO organization_memberships (organization_id, user_id, role, status, joined_at, updated_at) VALUES (?, ?, ?, 'active', ?, ?) ON CONFLICT(organization_id, user_id) DO UPDATE SET role=excluded.role, status='active', updated_at=excluded.updated_at", (row["organization_id"], payload.actor_user_id, row["role"], timestamp, timestamp))
        connection.execute("UPDATE organization_invites SET status='accepted', accepted_by_user_id=?, updated_at=? WHERE id=?", (payload.actor_user_id, timestamp, row["id"]))
        _audit(connection, actor=payload.actor_user_id, organization=row["organization_id"], action="organization_invite_accepted", target_type="organization_invite", target_id=row["id"])
        connection.commit()
        return {"accepted": True, "organization_id": row["organization_id"], "role": row["role"]}


@router.post("/data-releases/events")
def create_release_event(payload: DataReleaseEventCreate) -> dict[str, Any]:
    init_automation_governance_db()
    event_id = make_id("release_event")
    timestamp = now_iso()
    with connect() as connection:
        connection.execute("INSERT INTO data_release_events (id, release_id, stage, source_manifest_json, validation_json, notes, actor_user_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", (event_id, payload.release_id, payload.stage, encode_json(payload.source_manifest), encode_json(payload.validation), payload.notes, payload.actor_user_id, timestamp))
        _audit(connection, actor=payload.actor_user_id, organization="", action=f"data_release_{payload.stage}", target_type="data_release", target_id=payload.release_id, payload={"event_id": event_id})
        connection.commit()
    return {"id": event_id, "release_id": payload.release_id, "stage": payload.stage, "created_at": timestamp}


@router.get("/data-releases/{release_id}/lineage")
def release_lineage(release_id: str) -> list[dict[str, Any]]:
    init_automation_governance_db()
    with connect() as connection:
        return [_row(row) for row in connection.execute("SELECT * FROM data_release_events WHERE release_id = ? ORDER BY created_at", (release_id,)).fetchall()]


@router.post("/exports")
def request_export(payload: ExportRequestCreate) -> dict[str, Any]:
    init_automation_governance_db()
    key = _scope_key(payload.scope, payload.owner_user_id, payload.organization_id)
    export_id = make_id("export")
    timestamp = now_iso()
    with connect() as connection:
        _require_scope(connection, actor=payload.actor_user_id, scope=payload.scope, owner=payload.owner_user_id, organization=payload.organization_id, role="admin" if payload.export_type == "audit" else "analyst")
        connection.execute("INSERT INTO export_requests (id, scope_key, owner_user_id, organization_id, export_type, format, filters_json, status, metadata_json, requested_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'queued', ?, ?, ?)", (export_id, key, payload.owner_user_id, payload.organization_id or None, payload.export_type, payload.format, encode_json(payload.filters), encode_json(payload.metadata), timestamp, timestamp))
        _audit(connection, actor=payload.actor_user_id, organization=payload.organization_id, action="export_requested", target_type="export_request", target_id=export_id, payload={"type": payload.export_type, "format": payload.format})
        connection.commit()
    return {"id": export_id, "status": "queued", "requested_at": timestamp}


@router.get("/exports")
def list_exports(owner_user_id: str, scope: Scope = "personal", organization_id: str = "") -> list[dict[str, Any]]:
    init_automation_governance_db()
    key = _scope_key(scope, owner_user_id, organization_id)
    with connect() as connection:
        return [_row(row) for row in connection.execute("SELECT * FROM export_requests WHERE scope_key = ? ORDER BY requested_at DESC LIMIT 100", (key,)).fetchall()]


@router.post("/account-deletion")
def request_account_deletion(payload: AccountDeletionRequest) -> dict[str, Any]:
    init_automation_governance_db()
    if payload.actor_user_id != payload.owner_user_id:
        raise HTTPException(status_code=403, detail="Users can request deletion only for their own account")
    if payload.confirmation.strip().upper() != "DELETE MY SPORTS TERMINAL ACCOUNT":
        raise HTTPException(status_code=422, detail="Deletion confirmation phrase does not match")
    request_id = make_id("deletion")
    timestamp = now_iso()
    with connect() as connection:
        connection.execute("INSERT INTO account_deletion_requests (id, owner_user_id, status, reason, requested_at, audit_json) VALUES (?, ?, 'pending', ?, ?, ?)", (request_id, payload.owner_user_id, payload.reason, timestamp, encode_json({"requested_by": payload.actor_user_id})))
        _audit(connection, actor=payload.actor_user_id, organization="", action="account_deletion_requested", target_type="user", target_id=payload.owner_user_id, payload={"request_id": request_id})
        connection.commit()
    return {"id": request_id, "status": "pending", "requested_at": timestamp}


@router.post("/delivery-jobs")
def create_delivery_job(payload: DeliveryJobCreate) -> dict[str, Any]:
    init_automation_governance_db()
    if payload.organization_id:
        with connect() as connection:
            _require_role(connection, payload.organization_id, payload.actor_user_id, "admin")
    job_id = make_id("delivery")
    timestamp = now_iso()
    with connect() as connection:
        try:
            connection.execute("INSERT INTO delivery_jobs (id, organization_id, user_id, job_type, channel, payload_json, dedupe_key, status, scheduled_for, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'queued', ?, ?, ?)", (job_id, payload.organization_id or None, payload.user_id or None, payload.job_type, payload.channel, encode_json(payload.payload), payload.dedupe_key or None, payload.scheduled_for or None, timestamp, timestamp))
        except sqlite3.IntegrityError:
            existing = connection.execute("SELECT * FROM delivery_jobs WHERE dedupe_key = ?", (payload.dedupe_key,)).fetchone()
            return _row(existing)
        _audit(connection, actor=payload.actor_user_id, organization=payload.organization_id, action="delivery_job_created", target_type="delivery_job", target_id=job_id)
        connection.commit()
        return _row(connection.execute("SELECT * FROM delivery_jobs WHERE id = ?", (job_id,)).fetchone())


@router.get("/delivery-jobs")
def list_delivery_jobs(organization_id: str = "", user_id: str = "", status: str = "") -> list[dict[str, Any]]:
    init_automation_governance_db()
    clauses: list[str] = []
    values: list[Any] = []
    if organization_id:
        clauses.append("organization_id = ?")
        values.append(organization_id)
    if user_id:
        clauses.append("user_id = ?")
        values.append(user_id)
    if status:
        clauses.append("status = ?")
        values.append(status)
    sql = "SELECT * FROM delivery_jobs" + (" WHERE " + " AND ".join(clauses) if clauses else "") + " ORDER BY created_at DESC LIMIT 250"
    with connect() as connection:
        return [_row(row) for row in connection.execute(sql, values).fetchall()]


@router.get("/governance-audit")
def governance_audit(organization_id: str = "", limit: int = Query(default=250, ge=1, le=1000)) -> list[dict[str, Any]]:
    init_automation_governance_db()
    with connect() as connection:
        if organization_id:
            rows = connection.execute("SELECT * FROM governance_audit_events WHERE organization_id = ? ORDER BY created_at DESC LIMIT ?", (organization_id, limit)).fetchall()
        else:
            rows = connection.execute("SELECT * FROM governance_audit_events ORDER BY created_at DESC LIMIT ?", (limit,)).fetchall()
        return [_row(row) for row in rows]


@router.get("/snapshot")
def automation_snapshot(owner_user_id: str, scope: Scope = "personal", organization_id: str = "") -> dict[str, Any]:
    init_automation_governance_db()
    key = _scope_key(scope, owner_user_id, organization_id)
    with connect() as connection:
        count = lambda table, where, values: int(connection.execute(f"SELECT COUNT(*) AS count FROM {table} WHERE {where}", values).fetchone()["count"])
        return {
            "scope": scope,
            "owner_user_id": owner_user_id,
            "organization_id": organization_id,
            "alert_rules": count("alert_rules", "scope_key = ?", (key,)),
            "enabled_alert_rules": count("alert_rules", "scope_key = ? AND enabled = 1", (key,)),
            "scheduled_reports": count("scheduled_reports", "scope_key = ?", (key,)),
            "queued_exports": count("export_requests", "scope_key = ? AND status = 'queued'", (key,)),
            "pending_invites": count("organization_invites", "organization_id = ? AND status = 'pending'", (organization_id,)) if organization_id else 0,
            "queued_delivery_jobs": count("delivery_jobs", "organization_id = ? AND status = 'queued'", (organization_id,)) if organization_id else count("delivery_jobs", "user_id = ? AND status = 'queued'", (owner_user_id,)),
            "generated_at": now_iso(),
        }
