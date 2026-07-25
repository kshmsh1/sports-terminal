from __future__ import annotations

import sqlite3
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from .launch_api import _ensure_shadow_user, init_launch_db
from .main import connect, decode_json, encode_json, make_id, now_iso

router = APIRouter(prefix="/v2/workspaces", tags=["workspaces"])


class WorkspaceUpsert(BaseModel):
    actor_user_id: str
    scope: str = "personal"
    owner_user_id: str
    organization_id: str = ""
    title: str = "Sports Terminal Workbook"
    active_sheet: str = "Sheet 1"
    sheets: dict[str, dict[str, str]] = Field(default_factory=dict)
    expected_version: int | None = None


class WorkspaceRestore(BaseModel):
    actor_user_id: str
    owner_user_id: str
    scope: str = "personal"
    organization_id: str = ""
    version: int
    expected_current_version: int | None = None


class WorkspacePermissionUpsert(BaseModel):
    actor_user_id: str
    owner_user_id: str
    scope: str = "personal"
    organization_id: str = ""
    user_id: str
    permission: str = "viewer"


def init_workspace_db() -> None:
    init_launch_db()
    with connect() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS workspace_snapshots (
              scope_key TEXT PRIMARY KEY,
              owner_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              organization_id TEXT,
              title TEXT NOT NULL,
              active_sheet TEXT NOT NULL DEFAULT 'Sheet 1',
              sheets_json TEXT NOT NULL DEFAULT '{}',
              version INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS workspace_versions (
              id TEXT PRIMARY KEY,
              scope_key TEXT NOT NULL,
              version INTEGER NOT NULL,
              actor_user_id TEXT NOT NULL,
              snapshot_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS workspace_permissions (
              scope_key TEXT NOT NULL,
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              permission TEXT NOT NULL DEFAULT 'viewer',
              granted_by_user_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              PRIMARY KEY (scope_key, user_id)
            );

            CREATE INDEX IF NOT EXISTS idx_workspace_versions_scope
              ON workspace_versions(scope_key, version DESC);
            CREATE INDEX IF NOT EXISTS idx_workspace_permissions_scope
              ON workspace_permissions(scope_key, permission, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_workspace_permissions_user
              ON workspace_permissions(user_id, updated_at DESC);
            """
        )
        connection.commit()


def _scope_key(scope: str, owner_user_id: str, organization_id: str) -> str:
    if scope == "organization":
        if not organization_id:
            raise HTTPException(status_code=400, detail="Organization workspace requires an organization ID")
        return f"organization:{organization_id}"
    if not owner_user_id:
        raise HTTPException(status_code=400, detail="Personal workspace requires an owner user ID")
    return f"personal:{owner_user_id}"


def _normalized_sheets(value: dict[str, dict[str, str]]) -> dict[str, dict[str, str]]:
    output: dict[str, dict[str, str]] = {}
    for raw_sheet, raw_cells in value.items():
        sheet = str(raw_sheet).strip()[:31] or "Sheet 1"
        if sheet in output:
            suffix = 2
            base = sheet[:27]
            while f"{base} {suffix}" in output:
                suffix += 1
            sheet = f"{base} {suffix}"[:31]
        cells: dict[str, str] = {}
        for raw_ref, raw_value in raw_cells.items():
            cell_ref = str(raw_ref).strip().upper()
            if not cell_ref or len(cell_ref) > 12:
                continue
            value_text = str(raw_value)
            if value_text:
                cells[cell_ref] = value_text[:50_000]
        output[sheet] = cells
    return output or {"Sheet 1": {}}


def _serialize(row: sqlite3.Row, permissions: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    return {
        "id": row["scope_key"],
        "scope": "organization" if str(row["scope_key"]).startswith("organization:") else "personal",
        "owner_user_id": row["owner_user_id"],
        "organization_id": row["organization_id"] or "",
        "title": row["title"],
        "active_sheet": row["active_sheet"],
        "sheets": decode_json(row["sheets_json"], {"Sheet 1": {}}),
        "version": row["version"],
        "permissions": permissions or [],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def _permission_rows(connection: sqlite3.Connection, scope_key: str) -> list[dict[str, Any]]:
    rows = connection.execute(
        "SELECT user_id, permission, granted_by_user_id, created_at, updated_at FROM workspace_permissions WHERE scope_key = ? ORDER BY permission DESC, updated_at DESC",
        (scope_key,),
    ).fetchall()
    return [dict(row) for row in rows]


def _write_workspace(
    connection: sqlite3.Connection,
    *,
    scope_key: str,
    actor_user_id: str,
    owner_user_id: str,
    organization_id: str,
    title: str,
    active_sheet: str,
    sheets: dict[str, dict[str, str]],
    expected_version: int | None,
    restore_from_version: int | None = None,
) -> dict[str, Any]:
    timestamp = now_iso()
    _ensure_shadow_user(connection, owner_user_id, owner_user_id, "analyst")
    _ensure_shadow_user(connection, actor_user_id, actor_user_id, "analyst")
    existing = connection.execute(
        "SELECT version, created_at FROM workspace_snapshots WHERE scope_key = ?",
        (scope_key,),
    ).fetchone()
    current_version = 0 if existing is None else int(existing["version"])
    if expected_version is not None and expected_version != current_version:
        raise HTTPException(
            status_code=409,
            detail={
                "message": "Workspace version conflict",
                "expected_version": expected_version,
                "current_version": current_version,
            },
        )
    version = current_version + 1
    created_at = timestamp if existing is None else existing["created_at"]
    normalized = _normalized_sheets(sheets)
    selected_sheet = active_sheet.strip()[:31] or next(iter(normalized))
    if selected_sheet not in normalized:
        selected_sheet = next(iter(normalized))
    snapshot = {
        "scope": "organization" if scope_key.startswith("organization:") else "personal",
        "owner_user_id": owner_user_id,
        "organization_id": organization_id,
        "title": title,
        "active_sheet": selected_sheet,
        "sheets": normalized,
        "version": version,
        "restore_from_version": restore_from_version,
        "updated_at": timestamp,
    }
    connection.execute(
        """
        INSERT INTO workspace_snapshots (
          scope_key, owner_user_id, organization_id, title, active_sheet,
          sheets_json, version, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(scope_key) DO UPDATE SET owner_user_id = excluded.owner_user_id,
          organization_id = excluded.organization_id, title = excluded.title,
          active_sheet = excluded.active_sheet, sheets_json = excluded.sheets_json,
          version = excluded.version, updated_at = excluded.updated_at
        """,
        (
            scope_key,
            owner_user_id,
            organization_id or None,
            title.strip() or "Sports Terminal Workbook",
            selected_sheet,
            encode_json(normalized),
            version,
            created_at,
            timestamp,
        ),
    )
    connection.execute(
        "INSERT INTO workspace_versions (id, scope_key, version, actor_user_id, snapshot_json, created_at) VALUES (?, ?, ?, ?, ?, ?)",
        (
            f"{scope_key}:v{version}",
            scope_key,
            version,
            actor_user_id,
            encode_json(snapshot),
            timestamp,
        ),
    )
    connection.execute(
        """
        DELETE FROM workspace_versions
        WHERE scope_key = ? AND version NOT IN (
          SELECT version FROM workspace_versions
          WHERE scope_key = ? ORDER BY version DESC LIMIT 50
        )
        """,
        (scope_key, scope_key),
    )
    connection.commit()
    row = connection.execute(
        "SELECT * FROM workspace_snapshots WHERE scope_key = ?",
        (scope_key,),
    ).fetchone()
    assert row is not None
    return _serialize(row, _permission_rows(connection, scope_key))


@router.on_event("startup")
def startup_workspace_api() -> None:
    init_workspace_db()


@router.get("/primary")
def get_primary_workspace(
    owner_user_id: str,
    scope: str = "personal",
    organization_id: str = "",
) -> dict[str, Any]:
    init_workspace_db()
    scope_key = _scope_key(scope, owner_user_id, organization_id)
    with connect() as connection:
        row = connection.execute(
            "SELECT * FROM workspace_snapshots WHERE scope_key = ?",
            (scope_key,),
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Workspace has not been created yet")
        return _serialize(row, _permission_rows(connection, scope_key))


@router.put("/primary")
def upsert_primary_workspace(payload: WorkspaceUpsert) -> dict[str, Any]:
    init_workspace_db()
    if payload.scope not in {"personal", "organization"}:
        raise HTTPException(status_code=400, detail="Workspace scope must be personal or organization")
    scope_key = _scope_key(payload.scope, payload.owner_user_id, payload.organization_id)
    with connect() as connection:
        return _write_workspace(
            connection,
            scope_key=scope_key,
            actor_user_id=payload.actor_user_id,
            owner_user_id=payload.owner_user_id,
            organization_id=payload.organization_id,
            title=payload.title,
            active_sheet=payload.active_sheet,
            sheets=payload.sheets,
            expected_version=payload.expected_version,
        )


@router.post("/primary/restore")
def restore_primary_workspace(payload: WorkspaceRestore) -> dict[str, Any]:
    init_workspace_db()
    scope_key = _scope_key(payload.scope, payload.owner_user_id, payload.organization_id)
    with connect() as connection:
        version_row = connection.execute(
            "SELECT snapshot_json FROM workspace_versions WHERE scope_key = ? AND version = ?",
            (scope_key, payload.version),
        ).fetchone()
        if version_row is None:
            raise HTTPException(status_code=404, detail="Workspace version not found")
        snapshot = decode_json(version_row["snapshot_json"], {})
        if not isinstance(snapshot, dict):
            raise HTTPException(status_code=500, detail="Workspace version snapshot is invalid")
        sheets = snapshot.get("sheets")
        if not isinstance(sheets, dict):
            raise HTTPException(status_code=500, detail="Workspace version does not contain sheets")
        return _write_workspace(
            connection,
            scope_key=scope_key,
            actor_user_id=payload.actor_user_id,
            owner_user_id=payload.owner_user_id,
            organization_id=payload.organization_id,
            title=str(snapshot.get("title") or "Sports Terminal Workbook"),
            active_sheet=str(snapshot.get("active_sheet") or "Sheet 1"),
            sheets={str(key): value for key, value in sheets.items() if isinstance(value, dict)},
            expected_version=payload.expected_current_version,
            restore_from_version=payload.version,
        )


@router.get("/primary/versions")
def list_workspace_versions(
    owner_user_id: str,
    scope: str = "personal",
    organization_id: str = "",
) -> list[dict[str, Any]]:
    init_workspace_db()
    scope_key = _scope_key(scope, owner_user_id, organization_id)
    with connect() as connection:
        rows = connection.execute(
            "SELECT id, version, actor_user_id, snapshot_json, created_at FROM workspace_versions WHERE scope_key = ? ORDER BY version DESC LIMIT 50",
            (scope_key,),
        ).fetchall()
        return [
            {
                "id": row["id"],
                "version": row["version"],
                "actor_user_id": row["actor_user_id"],
                "snapshot": decode_json(row["snapshot_json"], {}),
                "created_at": row["created_at"],
            }
            for row in rows
        ]


@router.get("/primary/permissions")
def list_workspace_permissions(
    owner_user_id: str,
    scope: str = "personal",
    organization_id: str = "",
) -> list[dict[str, Any]]:
    init_workspace_db()
    scope_key = _scope_key(scope, owner_user_id, organization_id)
    with connect() as connection:
        return _permission_rows(connection, scope_key)


@router.put("/primary/permissions")
def upsert_workspace_permission(payload: WorkspacePermissionUpsert) -> dict[str, Any]:
    init_workspace_db()
    if payload.permission not in {"viewer", "editor", "owner"}:
        raise HTTPException(status_code=422, detail="Workspace permission must be viewer, editor or owner")
    scope_key = _scope_key(payload.scope, payload.owner_user_id, payload.organization_id)
    timestamp = now_iso()
    with connect() as connection:
        _ensure_shadow_user(connection, payload.actor_user_id, payload.actor_user_id, "analyst")
        _ensure_shadow_user(connection, payload.user_id, payload.user_id, "analyst")
        connection.execute(
            """
            INSERT INTO workspace_permissions (
              scope_key, user_id, permission, granted_by_user_id, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(scope_key, user_id) DO UPDATE SET permission = excluded.permission,
              granted_by_user_id = excluded.granted_by_user_id, updated_at = excluded.updated_at
            """,
            (scope_key, payload.user_id, payload.permission, payload.actor_user_id, timestamp, timestamp),
        )
        connection.commit()
    return {
        "id": make_id("permission_event"),
        "scope_key": scope_key,
        "user_id": payload.user_id,
        "permission": payload.permission,
        "granted_by_user_id": payload.actor_user_id,
        "updated_at": timestamp,
    }


@router.delete("/primary/permissions")
def remove_workspace_permission(
    actor_user_id: str,
    owner_user_id: str,
    user_id: str,
    scope: str = "personal",
    organization_id: str = "",
) -> dict[str, Any]:
    init_workspace_db()
    scope_key = _scope_key(scope, owner_user_id, organization_id)
    if actor_user_id == user_id:
        raise HTTPException(status_code=422, detail="Use account or organization controls to remove the current owner")
    with connect() as connection:
        connection.execute(
            "DELETE FROM workspace_permissions WHERE scope_key = ? AND user_id = ?",
            (scope_key, user_id),
        )
        connection.commit()
    return {"removed": True, "scope_key": scope_key, "user_id": user_id}
