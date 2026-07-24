from __future__ import annotations

import json
import os
import re
import sqlite3
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from .main import connect, decode_json, encode_json, ensure_user, make_id, now_iso, row_to_dict, rows_to_dicts

router = APIRouter(prefix="/v2", tags=["launch"])

ROLE_RANK = {
    "viewer": 10,
    "analyst": 20,
    "reviewer": 30,
    "admin": 40,
    "owner": 50,
    "platform_admin": 100,
}


class OrganizationCreate(BaseModel):
    id: str | None = None
    name: str
    slug: str | None = None
    created_by_user_id: str
    created_by_name: str = "Organization Owner"
    plan_id: str = "org"


class MembershipUpsert(BaseModel):
    actor_user_id: str
    user_id: str
    display_name: str = "Organization Member"
    role: str = "analyst"
    status: str = "active"


class CaseUpsert(BaseModel):
    actor_user_id: str
    scope: str = "personal"
    case: dict[str, Any]


class PayloadUpsert(BaseModel):
    payload: dict[str, Any]


class SavedObjectUpsert(BaseModel):
    actor_user_id: str
    payload: dict[str, Any]


class DataReleaseUpsert(BaseModel):
    actor_user_id: str = "system"
    release: dict[str, Any]


class LaunchCheckUpsert(BaseModel):
    key: str
    category: str
    status: str
    blocking: bool = False
    details: dict[str, Any] = Field(default_factory=dict)


def init_launch_db() -> None:
    with connect() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS organizations (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              slug TEXT UNIQUE NOT NULL,
              status TEXT NOT NULL DEFAULT 'active',
              plan_id TEXT NOT NULL DEFAULT 'org',
              created_by_user_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS organization_memberships (
              organization_id TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              role TEXT NOT NULL DEFAULT 'analyst',
              status TEXT NOT NULL DEFAULT 'active',
              joined_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              PRIMARY KEY (organization_id, user_id)
            );

            CREATE TABLE IF NOT EXISTS organization_member_records (
              organization_id TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              role_label TEXT NOT NULL DEFAULT 'Analyst',
              payload_json TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              PRIMARY KEY (organization_id, user_id)
            );

            CREATE TABLE IF NOT EXISTS transaction_case_snapshots (
              scope_key TEXT NOT NULL,
              case_id TEXT NOT NULL,
              organization_id TEXT,
              owner_user_id TEXT NOT NULL,
              status TEXT NOT NULL,
              priority TEXT NOT NULL,
              operating_season TEXT NOT NULL,
              title TEXT NOT NULL,
              source_payload_id TEXT,
              payload_json TEXT NOT NULL,
              version INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              PRIMARY KEY (scope_key, case_id)
            );

            CREATE TABLE IF NOT EXISTS transaction_workflow_activities (
              id TEXT PRIMARY KEY,
              organization_id TEXT NOT NULL,
              case_id TEXT,
              actor_user_id TEXT,
              kind TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS transaction_workflow_notifications (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              organization_id TEXT,
              case_id TEXT,
              is_read INTEGER NOT NULL DEFAULT 0,
              payload_json TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS saved_sports_objects (
              id TEXT PRIMARY KEY,
              owner_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              organization_id TEXT,
              visibility TEXT NOT NULL DEFAULT 'private',
              object_type TEXT NOT NULL,
              title TEXT NOT NULL,
              source_snapshot TEXT,
              payload_json TEXT NOT NULL,
              version INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS data_releases (
              id TEXT PRIMARY KEY,
              league TEXT NOT NULL DEFAULT 'NBA',
              season TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'draft',
              version TEXT NOT NULL,
              generated_at TEXT,
              published_at TEXT,
              manifest_json TEXT NOT NULL DEFAULT '{}',
              validation_json TEXT NOT NULL DEFAULT '{}',
              source_notes_json TEXT NOT NULL DEFAULT '[]',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS launch_checks (
              key TEXT PRIMARY KEY,
              category TEXT NOT NULL,
              status TEXT NOT NULL,
              blocking INTEGER NOT NULL DEFAULT 0,
              details_json TEXT NOT NULL DEFAULT '{}',
              updated_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_memberships_user ON organization_memberships(user_id, status);
            CREATE INDEX IF NOT EXISTS idx_cases_owner ON transaction_case_snapshots(owner_user_id, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_cases_org ON transaction_case_snapshots(organization_id, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_activities_org ON transaction_workflow_activities(organization_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_notifications_user ON transaction_workflow_notifications(user_id, is_read, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_saved_objects_owner ON saved_sports_objects(owner_user_id, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_saved_objects_org ON saved_sports_objects(organization_id, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_data_releases_season ON data_releases(league, season, status, updated_at DESC);
            """
        )
        connection.commit()


def _safe_identifier(value: str, fallback: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "-", value.strip().lower()).strip("-")
    return normalized or fallback


def _ensure_shadow_user(
    connection: sqlite3.Connection,
    user_id: str,
    display_name: str = "Sports Terminal User",
    role: str = "analyst",
) -> None:
    if not user_id:
        raise HTTPException(status_code=400, detail="A user ID is required")
    if connection.execute("SELECT id FROM users WHERE id = ?", (user_id,)).fetchone() is not None:
        return
    timestamp = now_iso()
    email_key = _safe_identifier(user_id, make_id("user"))
    email = f"{email_key}@shadow.sportsterminal.local"
    suffix = 1
    while connection.execute("SELECT 1 FROM users WHERE email = ?", (email,)).fetchone() is not None:
        suffix += 1
        email = f"{email_key}-{suffix}@shadow.sportsterminal.local"
    connection.execute(
        "INSERT INTO users (id, email, display_name, role, status, created_at, updated_at) VALUES (?, ?, ?, ?, 'active', ?, ?)",
        (user_id, email, display_name or "Sports Terminal User", role, timestamp, timestamp),
    )
    connection.execute(
        "INSERT INTO user_profiles (user_id, is_public, created_at, updated_at) VALUES (?, 0, ?, ?)",
        (user_id, timestamp, timestamp),
    )
    connection.execute(
        "INSERT INTO user_settings (user_id, dark_mode, email_digest, fantasy_alerts, notification_preferences, created_at, updated_at) VALUES (?, 0, 0, 1, '{}', ?, ?)",
        (user_id, timestamp, timestamp),
    )


def _ensure_organization(
    connection: sqlite3.Connection,
    organization_id: str,
    name: str,
    owner_user_id: str,
) -> None:
    if not organization_id:
        return
    timestamp = now_iso()
    row = connection.execute("SELECT id FROM organizations WHERE id = ?", (organization_id,)).fetchone()
    if row is None:
        slug = _safe_identifier(name or organization_id, organization_id)
        base_slug = slug
        suffix = 1
        while connection.execute("SELECT 1 FROM organizations WHERE slug = ?", (slug,)).fetchone() is not None:
            suffix += 1
            slug = f"{base_slug}-{suffix}"
        connection.execute(
            "INSERT INTO organizations (id, name, slug, status, plan_id, created_by_user_id, created_at, updated_at) VALUES (?, ?, ?, 'active', 'org', ?, ?, ?)",
            (organization_id, name or organization_id, slug, owner_user_id, timestamp, timestamp),
        )
    if owner_user_id:
        connection.execute(
            """
            INSERT INTO organization_memberships (organization_id, user_id, role, status, joined_at, updated_at)
            VALUES (?, ?, 'owner', 'active', ?, ?)
            ON CONFLICT(organization_id, user_id) DO NOTHING
            """,
            (organization_id, owner_user_id, timestamp, timestamp),
        )


def _membership_role(connection: sqlite3.Connection, organization_id: str, user_id: str) -> str | None:
    row = connection.execute(
        "SELECT role FROM organization_memberships WHERE organization_id = ? AND user_id = ? AND status = 'active'",
        (organization_id, user_id),
    ).fetchone()
    return None if row is None else str(row["role"])


def _require_role(
    connection: sqlite3.Connection,
    organization_id: str,
    user_id: str,
    minimum: str = "analyst",
) -> str:
    role = _membership_role(connection, organization_id, user_id)
    if role is None:
        raise HTTPException(status_code=403, detail="User is not an active organization member")
    if ROLE_RANK.get(role, 0) < ROLE_RANK.get(minimum, 0):
        raise HTTPException(status_code=403, detail=f"{minimum} role or higher is required")
    return role


def _decode_payload_rows(rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    for row in rows:
        payload = decode_json(row["payload_json"], {})
        if isinstance(payload, dict):
            output.append(payload)
    return output


def _scope_key(scope: str, owner_user_id: str, organization_id: str) -> str:
    if scope == "organization":
        if not organization_id:
            raise HTTPException(status_code=400, detail="Organization scope requires an organization ID")
        return f"organization:{organization_id}"
    return f"personal:{owner_user_id}"


def _latest_release(connection: sqlite3.Connection, season: str = "2025-26") -> dict[str, Any] | None:
    row = connection.execute(
        "SELECT * FROM data_releases WHERE league = 'NBA' AND season = ? ORDER BY CASE status WHEN 'published' THEN 0 WHEN 'validated' THEN 1 ELSE 2 END, updated_at DESC LIMIT 1",
        (season,),
    ).fetchone()
    if row is None:
        return None
    item = dict(row)
    item["manifest"] = decode_json(item.pop("manifest_json"), {})
    item["validation"] = decode_json(item.pop("validation_json"), {})
    item["source_notes"] = decode_json(item.pop("source_notes_json"), [])
    return item


@router.on_event("startup")
def startup_launch_api() -> None:
    init_launch_db()


@router.get("/launch/config")
def launch_config() -> dict[str, Any]:
    init_launch_db()
    with connect() as connection:
        release = _latest_release(connection)
    return {
        "product": "Sports Terminal",
        "launch_profile": "nba-2025-26-professional",
        "supported_seasons": ["2025-26"],
        "default_season": "2025-26",
        "modules": {
            "nba_hub": "launch",
            "stats": "launch",
            "workspace": "launch_candidate",
            "cap_lab": "launch",
            "trade_machine": "modeled_beta",
            "front_office": "modeled_beta",
            "transaction_cases": "launch_candidate",
            "organization_workflows": "launch_candidate",
            "data_studio": "launch_without_python_execution",
            "fantasy": "experimental",
            "community": "disabled_until_moderation",
            "messaging": "disabled_until_moderation",
        },
        "current_release": release,
    }


@router.get("/launch/readiness")
def launch_readiness_v2() -> dict[str, Any]:
    init_launch_db()
    with connect() as connection:
        release = _latest_release(connection)
        checks = rows_to_dicts(connection.execute("SELECT * FROM launch_checks ORDER BY category, key").fetchall())
        tables = [
            row["name"]
            for row in connection.execute("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name").fetchall()
        ]
    normalized_checks = [
        {
            "key": row["key"],
            "category": row["category"],
            "status": row["status"],
            "blocking": bool(row["blocking"]),
            "details": decode_json(row["details_json"], {}),
            "updated_at": row["updated_at"],
        }
        for row in checks
    ]
    data_ready = bool(
        release
        and release.get("status") in {"validated", "published"}
        and release.get("validation", {}).get("status") == "pass"
    )
    external = {
        "auth_provider": bool(os.getenv("SPORTS_TERMINAL_AUTH_PROVIDER")),
        "managed_database": bool(os.getenv("DATABASE_URL")),
        "payment_provider": bool(os.getenv("SPORTS_TERMINAL_PAYMENT_PROVIDER")),
        "data_rights_approved": os.getenv("SPORTS_TERMINAL_DATA_RIGHTS_APPROVED") == "true",
        "public_community_enabled": os.getenv("SPORTS_TERMINAL_PUBLIC_COMMUNITY") == "true",
    }
    blockers = [
        check["key"]
        for check in normalized_checks
        if check["blocking"] and check["status"] not in {"pass", "complete", "waived"}
    ]
    if not data_ready:
        blockers.append("nba_2025_26_data_release")
    if not external["auth_provider"]:
        blockers.append("external_auth_provider")
    if not external["managed_database"]:
        blockers.append("managed_database")
    if not external["data_rights_approved"]:
        blockers.append("data_rights_approval")
    status = "launch_ready" if not blockers else "launch_blocked"
    return {
        "status": status,
        "launch_profile": "nba-2025-26-professional",
        "supported_season": "2025-26",
        "data_release": release,
        "code_complete": [
            "organization and membership persistence",
            "server-backed transaction case snapshots",
            "server-backed workflow activity and notifications",
            "saved structured sports objects",
            "data release certification registry",
            "launch configuration and readiness API",
        ],
        "external_state": external,
        "checks": normalized_checks,
        "blocking_items": sorted(set(blockers)),
        "tables": tables,
    }


@router.put("/launch/checks/{key}")
def upsert_launch_check(key: str, payload: LaunchCheckUpsert) -> dict[str, Any]:
    if key != payload.key:
        raise HTTPException(status_code=400, detail="Path key and payload key must match")
    timestamp = now_iso()
    with connect() as connection:
        connection.execute(
            """
            INSERT INTO launch_checks (key, category, status, blocking, details_json, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(key) DO UPDATE SET category = excluded.category, status = excluded.status,
              blocking = excluded.blocking, details_json = excluded.details_json, updated_at = excluded.updated_at
            """,
            (payload.key, payload.category, payload.status, int(payload.blocking), encode_json(payload.details), timestamp),
        )
        connection.commit()
    return {"key": key, "status": payload.status, "updated_at": timestamp}


@router.post("/organizations")
def create_organization(payload: OrganizationCreate) -> dict[str, Any]:
    init_launch_db()
    timestamp = now_iso()
    organization_id = payload.id or make_id("org")
    with connect() as connection:
        _ensure_shadow_user(connection, payload.created_by_user_id, payload.created_by_name, "organization_admin")
        if connection.execute("SELECT 1 FROM organizations WHERE id = ?", (organization_id,)).fetchone() is not None:
            raise HTTPException(status_code=409, detail="Organization already exists")
        slug = _safe_identifier(payload.slug or payload.name, organization_id)
        if connection.execute("SELECT 1 FROM organizations WHERE slug = ?", (slug,)).fetchone() is not None:
            raise HTTPException(status_code=409, detail="Organization slug already exists")
        connection.execute(
            "INSERT INTO organizations (id, name, slug, status, plan_id, created_by_user_id, created_at, updated_at) VALUES (?, ?, ?, 'active', ?, ?, ?, ?)",
            (organization_id, payload.name, slug, payload.plan_id, payload.created_by_user_id, timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO organization_memberships (organization_id, user_id, role, status, joined_at, updated_at) VALUES (?, ?, 'owner', 'active', ?, ?)",
            (organization_id, payload.created_by_user_id, timestamp, timestamp),
        )
        connection.commit()
    return get_organization(organization_id)


@router.get("/organizations/{organization_id}")
def get_organization(organization_id: str) -> dict[str, Any]:
    init_launch_db()
    with connect() as connection:
        row = connection.execute("SELECT * FROM organizations WHERE id = ?", (organization_id,)).fetchone()
        item = row_to_dict(row)
        if item is None:
            raise HTTPException(status_code=404, detail="Organization not found")
        item["member_count"] = connection.execute(
            "SELECT COUNT(*) AS count FROM organization_memberships WHERE organization_id = ? AND status = 'active'",
            (organization_id,),
        ).fetchone()["count"]
        item["case_count"] = connection.execute(
            "SELECT COUNT(*) AS count FROM transaction_case_snapshots WHERE scope_key = ?",
            (f"organization:{organization_id}",),
        ).fetchone()["count"]
        return item


@router.get("/users/{user_id}/organizations")
def list_user_organizations(user_id: str) -> list[dict[str, Any]]:
    init_launch_db()
    with connect() as connection:
        return rows_to_dicts(
            connection.execute(
                """
                SELECT organizations.*, organization_memberships.role AS membership_role,
                       organization_memberships.status AS membership_status
                FROM organizations
                JOIN organization_memberships ON organizations.id = organization_memberships.organization_id
                WHERE organization_memberships.user_id = ?
                ORDER BY organizations.name
                """,
                (user_id,),
            ).fetchall()
        )


@router.get("/organizations/{organization_id}/memberships")
def list_memberships(organization_id: str) -> list[dict[str, Any]]:
    init_launch_db()
    with connect() as connection:
        return rows_to_dicts(
            connection.execute(
                """
                SELECT organization_memberships.*, users.display_name, users.email
                FROM organization_memberships
                JOIN users ON users.id = organization_memberships.user_id
                WHERE organization_memberships.organization_id = ?
                ORDER BY CASE organization_memberships.role WHEN 'owner' THEN 0 WHEN 'admin' THEN 1 WHEN 'reviewer' THEN 2 ELSE 3 END,
                         users.display_name
                """,
                (organization_id,),
            ).fetchall()
        )


@router.put("/organizations/{organization_id}/memberships/{user_id}")
def upsert_membership(organization_id: str, user_id: str, payload: MembershipUpsert) -> dict[str, Any]:
    if user_id != payload.user_id:
        raise HTTPException(status_code=400, detail="Path user and payload user must match")
    if payload.role not in ROLE_RANK:
        raise HTTPException(status_code=400, detail="Unsupported organization role")
    timestamp = now_iso()
    with connect() as connection:
        _require_role(connection, organization_id, payload.actor_user_id, "admin")
        _ensure_shadow_user(connection, user_id, payload.display_name, payload.role)
        connection.execute(
            """
            INSERT INTO organization_memberships (organization_id, user_id, role, status, joined_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(organization_id, user_id) DO UPDATE SET role = excluded.role,
              status = excluded.status, updated_at = excluded.updated_at
            """,
            (organization_id, user_id, payload.role, payload.status, timestamp, timestamp),
        )
        connection.commit()
    return {"organization_id": organization_id, "user_id": user_id, "role": payload.role, "status": payload.status}


@router.delete("/organizations/{organization_id}/memberships/{user_id}")
def remove_membership(organization_id: str, user_id: str, actor_user_id: str = Query(...)) -> dict[str, Any]:
    with connect() as connection:
        _require_role(connection, organization_id, actor_user_id, "admin")
        target_role = _membership_role(connection, organization_id, user_id)
        if target_role == "owner":
            raise HTTPException(status_code=409, detail="Organization owner cannot be removed")
        connection.execute(
            "DELETE FROM organization_memberships WHERE organization_id = ? AND user_id = ?",
            (organization_id, user_id),
        )
        connection.commit()
    return {"removed": True, "organization_id": organization_id, "user_id": user_id}


@router.get("/transaction-cases")
def list_transaction_cases(
    owner_user_id: str | None = None,
    organization_id: str | None = None,
    scope: str = "personal",
) -> list[dict[str, Any]]:
    init_launch_db()
    if scope == "organization":
        if not organization_id:
            raise HTTPException(status_code=400, detail="Organization ID is required")
        scope_key = f"organization:{organization_id}"
    else:
        if not owner_user_id:
            raise HTTPException(status_code=400, detail="Owner user ID is required")
        scope_key = f"personal:{owner_user_id}"
    with connect() as connection:
        rows = connection.execute(
            "SELECT payload_json FROM transaction_case_snapshots WHERE scope_key = ? ORDER BY updated_at DESC",
            (scope_key,),
        ).fetchall()
        return _decode_payload_rows(rows)


@router.put("/transaction-cases/{case_id}")
def upsert_transaction_case(case_id: str, payload: CaseUpsert) -> dict[str, Any]:
    init_launch_db()
    case = dict(payload.case)
    if case.get("id") not in {None, "", case_id}:
        raise HTTPException(status_code=400, detail="Path case ID and payload ID must match")
    case["id"] = case_id
    owner_user_id = str(case.get("ownerUserId") or payload.actor_user_id)
    owner_name = str(case.get("ownerName") or "Sports Terminal Analyst")
    organization_id = str(case.get("organizationId") or "")
    organization_name = str(case.get("organizationName") or organization_id)
    timestamp = str(case.get("updatedAtIso") or now_iso())
    created_at = str(case.get("createdAtIso") or timestamp)
    case["createdAtIso"] = created_at
    case["updatedAtIso"] = timestamp
    scope_key = _scope_key(payload.scope, owner_user_id, organization_id)
    with connect() as connection:
        _ensure_shadow_user(connection, owner_user_id, owner_name, "analyst")
        _ensure_shadow_user(connection, payload.actor_user_id, payload.actor_user_id, "analyst")
        _ensure_organization(connection, organization_id, organization_name, owner_user_id)
        if payload.scope == "organization":
            if _membership_role(connection, organization_id, payload.actor_user_id) is None:
                connection.execute(
                    "INSERT OR IGNORE INTO organization_memberships (organization_id, user_id, role, status, joined_at, updated_at) VALUES (?, ?, 'analyst', 'active', ?, ?)",
                    (organization_id, payload.actor_user_id, now_iso(), now_iso()),
                )
        existing = connection.execute(
            "SELECT version, created_at FROM transaction_case_snapshots WHERE scope_key = ? AND case_id = ?",
            (scope_key, case_id),
        ).fetchone()
        version = 1 if existing is None else int(existing["version"]) + 1
        database_created_at = created_at if existing is None else existing["created_at"]
        connection.execute(
            """
            INSERT INTO transaction_case_snapshots (
              scope_key, case_id, organization_id, owner_user_id, status, priority,
              operating_season, title, source_payload_id, payload_json, version, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(scope_key, case_id) DO UPDATE SET
              organization_id = excluded.organization_id,
              owner_user_id = excluded.owner_user_id,
              status = excluded.status,
              priority = excluded.priority,
              operating_season = excluded.operating_season,
              title = excluded.title,
              source_payload_id = excluded.source_payload_id,
              payload_json = excluded.payload_json,
              version = excluded.version,
              updated_at = excluded.updated_at
            """,
            (
                scope_key,
                case_id,
                organization_id or None,
                owner_user_id,
                str(case.get("status") or "draft"),
                str(case.get("priority") or "normal"),
                str(case.get("operatingSeason") or "2025-26"),
                str(case.get("title") or "Untitled transaction case"),
                str(case.get("sourcePayloadId") or "") or None,
                encode_json(case),
                version,
                database_created_at,
                timestamp,
            ),
        )
        connection.commit()
    return case


@router.delete("/transaction-cases/{case_id}")
def delete_transaction_case(
    case_id: str,
    actor_user_id: str = Query(...),
    scope: str = "personal",
    owner_user_id: str | None = None,
    organization_id: str | None = None,
) -> dict[str, Any]:
    if scope == "organization":
        if not organization_id:
            raise HTTPException(status_code=400, detail="Organization ID is required")
        scope_key = f"organization:{organization_id}"
        with connect() as connection:
            _require_role(connection, organization_id, actor_user_id, "analyst")
            connection.execute(
                "DELETE FROM transaction_case_snapshots WHERE scope_key = ? AND case_id = ?",
                (scope_key, case_id),
            )
            connection.commit()
    else:
        target_user = owner_user_id or actor_user_id
        if target_user != actor_user_id:
            raise HTTPException(status_code=403, detail="Users can remove only their own personal case")
        scope_key = f"personal:{target_user}"
        with connect() as connection:
            connection.execute(
                "DELETE FROM transaction_case_snapshots WHERE scope_key = ? AND case_id = ?",
                (scope_key, case_id),
            )
            connection.commit()
    return {"removed": True, "case_id": case_id, "scope": scope}


@router.get("/organizations/{organization_id}/activities")
def list_activities(organization_id: str) -> list[dict[str, Any]]:
    init_launch_db()
    with connect() as connection:
        rows = connection.execute(
            "SELECT payload_json FROM transaction_workflow_activities WHERE organization_id = ? ORDER BY created_at DESC LIMIT 250",
            (organization_id,),
        ).fetchall()
        return _decode_payload_rows(rows)


@router.put("/activities/{activity_id}")
def upsert_activity(activity_id: str, payload: PayloadUpsert) -> dict[str, Any]:
    item = dict(payload.payload)
    item["id"] = activity_id
    organization_id = str(item.get("organizationId") or "")
    actor_user_id = str(item.get("actorUserId") or "")
    if not organization_id:
        raise HTTPException(status_code=400, detail="Activity requires an organization ID")
    created_at = str(item.get("createdAtIso") or now_iso())
    with connect() as connection:
        _ensure_shadow_user(connection, actor_user_id or "system", str(item.get("actorName") or "System"), "analyst")
        _ensure_organization(connection, organization_id, organization_id, actor_user_id or "system")
        connection.execute(
            """
            INSERT INTO transaction_workflow_activities (id, organization_id, case_id, actor_user_id, kind, payload_json, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET payload_json = excluded.payload_json
            """,
            (
                activity_id,
                organization_id,
                str(item.get("caseId") or "") or None,
                actor_user_id or None,
                str(item.get("kind") or "status"),
                encode_json(item),
                created_at,
            ),
        )
        connection.commit()
    return item


@router.get("/users/{user_id}/notifications")
def list_notifications(user_id: str) -> list[dict[str, Any]]:
    init_launch_db()
    with connect() as connection:
        rows = connection.execute(
            "SELECT payload_json, is_read FROM transaction_workflow_notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 100",
            (user_id,),
        ).fetchall()
        output: list[dict[str, Any]] = []
        for row in rows:
            item = decode_json(row["payload_json"], {})
            if isinstance(item, dict):
                item["isRead"] = bool(row["is_read"])
                output.append(item)
        return output


@router.put("/notifications/{notification_id}")
def upsert_notification(notification_id: str, payload: PayloadUpsert) -> dict[str, Any]:
    item = dict(payload.payload)
    item["id"] = notification_id
    user_id = str(item.get("recipientUserId") or "")
    if not user_id:
        raise HTTPException(status_code=400, detail="Notification requires a recipient")
    created_at = str(item.get("createdAtIso") or now_iso())
    with connect() as connection:
        _ensure_shadow_user(connection, user_id, user_id, "analyst")
        connection.execute(
            """
            INSERT INTO transaction_workflow_notifications (
              id, user_id, organization_id, case_id, is_read, payload_json, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET is_read = excluded.is_read,
              payload_json = excluded.payload_json, updated_at = excluded.updated_at
            """,
            (
                notification_id,
                user_id,
                str(item.get("organizationId") or "") or None,
                str(item.get("caseId") or "") or None,
                int(item.get("isRead") is True),
                encode_json(item),
                created_at,
                now_iso(),
            ),
        )
        connection.commit()
    return item


@router.post("/users/{user_id}/notifications/read-all")
def mark_notifications_read(user_id: str) -> dict[str, Any]:
    timestamp = now_iso()
    with connect() as connection:
        rows = connection.execute(
            "SELECT id, payload_json FROM transaction_workflow_notifications WHERE user_id = ? AND is_read = 0",
            (user_id,),
        ).fetchall()
        for row in rows:
            item = decode_json(row["payload_json"], {})
            if isinstance(item, dict):
                item["isRead"] = True
            connection.execute(
                "UPDATE transaction_workflow_notifications SET is_read = 1, payload_json = ?, updated_at = ? WHERE id = ?",
                (encode_json(item), timestamp, row["id"]),
            )
        connection.commit()
    return {"user_id": user_id, "updated": len(rows)}


@router.get("/organizations/{organization_id}/member-records")
def list_member_records(organization_id: str) -> list[dict[str, Any]]:
    init_launch_db()
    with connect() as connection:
        rows = connection.execute(
            "SELECT payload_json FROM organization_member_records WHERE organization_id = ? ORDER BY role_label, user_id",
            (organization_id,),
        ).fetchall()
        return _decode_payload_rows(rows)


@router.put("/organizations/{organization_id}/member-records/{user_id}")
def upsert_member_record(organization_id: str, user_id: str, payload: PayloadUpsert) -> dict[str, Any]:
    item = dict(payload.payload)
    item["userId"] = user_id
    display_name = str(item.get("displayName") or user_id)
    role_label = str(item.get("roleLabel") or "Analyst")
    normalized_role = {
        "Admin": "admin",
        "Reviewer": "reviewer",
        "Owner": "owner",
    }.get(role_label, "analyst")
    with connect() as connection:
        _ensure_shadow_user(connection, user_id, display_name, normalized_role)
        _ensure_organization(connection, organization_id, organization_id, user_id)
        connection.execute(
            """
            INSERT INTO organization_member_records (organization_id, user_id, role_label, payload_json, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(organization_id, user_id) DO UPDATE SET role_label = excluded.role_label,
              payload_json = excluded.payload_json, updated_at = excluded.updated_at
            """,
            (organization_id, user_id, role_label, encode_json(item), now_iso()),
        )
        connection.execute(
            """
            INSERT INTO organization_memberships (organization_id, user_id, role, status, joined_at, updated_at)
            VALUES (?, ?, ?, 'active', ?, ?)
            ON CONFLICT(organization_id, user_id) DO UPDATE SET role = excluded.role,
              status = 'active', updated_at = excluded.updated_at
            """,
            (organization_id, user_id, normalized_role, now_iso(), now_iso()),
        )
        connection.commit()
    return item


@router.delete("/organizations/{organization_id}/member-records/{user_id}")
def remove_member_record(organization_id: str, user_id: str) -> dict[str, Any]:
    with connect() as connection:
        connection.execute(
            "DELETE FROM organization_member_records WHERE organization_id = ? AND user_id = ?",
            (organization_id, user_id),
        )
        connection.commit()
    return {"removed": True, "organization_id": organization_id, "user_id": user_id}


@router.get("/saved-objects")
def list_saved_objects(
    owner_user_id: str | None = None,
    organization_id: str | None = None,
) -> list[dict[str, Any]]:
    init_launch_db()
    sql = "SELECT payload_json, version, updated_at FROM saved_sports_objects WHERE 1 = 1"
    params: list[Any] = []
    if organization_id:
        sql += " AND organization_id = ?"
        params.append(organization_id)
    elif owner_user_id:
        sql += " AND owner_user_id = ?"
        params.append(owner_user_id)
    else:
        raise HTTPException(status_code=400, detail="Owner user ID or organization ID is required")
    sql += " ORDER BY updated_at DESC LIMIT 100"
    with connect() as connection:
        output: list[dict[str, Any]] = []
        for row in connection.execute(sql, params).fetchall():
            item = decode_json(row["payload_json"], {})
            if isinstance(item, dict):
                item["version"] = row["version"]
                item["serverUpdatedAt"] = row["updated_at"]
                output.append(item)
        return output


@router.put("/saved-objects/{object_id}")
def upsert_saved_object(object_id: str, payload: SavedObjectUpsert) -> dict[str, Any]:
    item = dict(payload.payload)
    item["id"] = object_id
    owner_user_id = str(item.get("ownerUserId") or payload.actor_user_id)
    organization_id = str(item.get("organizationId") or "")
    visibility = str(item.get("visibility") or ("organization" if organization_id else "private"))
    timestamp = now_iso()
    with connect() as connection:
        _ensure_shadow_user(connection, owner_user_id, str(item.get("ownerName") or owner_user_id), "analyst")
        _ensure_organization(connection, organization_id, organization_id, owner_user_id)
        existing = connection.execute("SELECT version, created_at FROM saved_sports_objects WHERE id = ?", (object_id,)).fetchone()
        version = 1 if existing is None else int(existing["version"]) + 1
        created_at = timestamp if existing is None else existing["created_at"]
        connection.execute(
            """
            INSERT INTO saved_sports_objects (
              id, owner_user_id, organization_id, visibility, object_type, title,
              source_snapshot, payload_json, version, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET owner_user_id = excluded.owner_user_id,
              organization_id = excluded.organization_id, visibility = excluded.visibility,
              object_type = excluded.object_type, title = excluded.title,
              source_snapshot = excluded.source_snapshot, payload_json = excluded.payload_json,
              version = excluded.version, updated_at = excluded.updated_at
            """,
            (
                object_id,
                owner_user_id,
                organization_id or None,
                visibility,
                str(item.get("objectType") or "sports_object"),
                str(item.get("title") or "Untitled object"),
                str(item.get("sourceSnapshot") or "") or None,
                encode_json(item),
                version,
                created_at,
                timestamp,
            ),
        )
        connection.commit()
    item["version"] = version
    item["serverUpdatedAt"] = timestamp
    return item


@router.get("/data-releases")
def list_data_releases(season: str | None = None) -> list[dict[str, Any]]:
    init_launch_db()
    sql = "SELECT * FROM data_releases"
    params: list[Any] = []
    if season:
        sql += " WHERE season = ?"
        params.append(season)
    sql += " ORDER BY updated_at DESC"
    with connect() as connection:
        output: list[dict[str, Any]] = []
        for row in connection.execute(sql, params).fetchall():
            item = dict(row)
            item["manifest"] = decode_json(item.pop("manifest_json"), {})
            item["validation"] = decode_json(item.pop("validation_json"), {})
            item["source_notes"] = decode_json(item.pop("source_notes_json"), [])
            output.append(item)
        return output


@router.get("/data-releases/current")
def current_data_release(season: str = "2025-26") -> dict[str, Any]:
    init_launch_db()
    with connect() as connection:
        item = _latest_release(connection, season)
    if item is None:
        raise HTTPException(status_code=404, detail="No data release exists for the requested season")
    return item


@router.put("/data-releases/{release_id}")
def upsert_data_release(release_id: str, payload: DataReleaseUpsert) -> dict[str, Any]:
    item = dict(payload.release)
    item["id"] = release_id
    season = str(item.get("season") or "2025-26")
    status = str(item.get("status") or "draft")
    validation = item.get("validation") if isinstance(item.get("validation"), dict) else {}
    if status in {"validated", "published"} and validation.get("status") != "pass":
        raise HTTPException(status_code=409, detail="A release cannot be validated or published without a passing validation report")
    timestamp = now_iso()
    with connect() as connection:
        existing = connection.execute("SELECT created_at FROM data_releases WHERE id = ?", (release_id,)).fetchone()
        created_at = timestamp if existing is None else existing["created_at"]
        published_at = str(item.get("publishedAt") or "") or (timestamp if status == "published" else None)
        connection.execute(
            """
            INSERT INTO data_releases (
              id, league, season, status, version, generated_at, published_at,
              manifest_json, validation_json, source_notes_json, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET league = excluded.league, season = excluded.season,
              status = excluded.status, version = excluded.version, generated_at = excluded.generated_at,
              published_at = excluded.published_at, manifest_json = excluded.manifest_json,
              validation_json = excluded.validation_json, source_notes_json = excluded.source_notes_json,
              updated_at = excluded.updated_at
            """,
            (
                release_id,
                str(item.get("league") or "NBA"),
                season,
                status,
                str(item.get("version") or "1"),
                str(item.get("generatedAt") or "") or None,
                published_at,
                encode_json(item.get("manifest") if isinstance(item.get("manifest"), dict) else {}),
                encode_json(validation),
                encode_json(item.get("sourceNotes") if isinstance(item.get("sourceNotes"), list) else []),
                created_at,
                timestamp,
            ),
        )
        connection.commit()
    return current_data_release(season)
