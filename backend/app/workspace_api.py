from __future__ import annotations

import json
import sqlite3
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from .launch_api import _ensure_shadow_user, init_launch_db
from .main import connect, decode_json, encode_json, now_iso

router = APIRouter(prefix="/v2/workspaces", tags=["workspaces"])


class WorkspaceUpsert(BaseModel):
    actor_user_id: str
    scope: str = "personal"
    owner_user_id: str
    organization_id: str = ""
    title: str = "Sports Terminal Workbook"
    active_sheet: str = "Sheet 1"
    sheets: dict[str, dict[str, str]] = Field(default_factory=dict)


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

            CREATE INDEX IF NOT EXISTS idx_workspace_versions_scope
              ON workspace_versions(scope_key, version DESC);
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


def _serialize(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["scope_key"],
        "scope": "organization" if str(row["scope_key"]).startswith("organization:") else "personal",
        "owner_user_id": row["owner_user_id"],
        "organization_id": row["organization_id"] or "",
        "title": row["title"],
        "active_sheet": row["active_sheet"],
        "sheets": decode_json(row["sheets_json"], {"Sheet 1": {}}),
        "version": row["version"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


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
        return _serialize(row)


@router.put("/primary")
def upsert_primary_workspace(payload: WorkspaceUpsert) -> dict[str, Any]:
    init_workspace_db()
    if payload.scope not in {"personal", "organization"}:
        raise HTTPException(status_code=400, detail="Workspace scope must be personal or organization")
    scope_key = _scope_key(
        payload.scope,
        payload.owner_user_id,
        payload.organization_id,
    )
    timestamp = now_iso()
    sheets = _normalized_sheets(payload.sheets)
    with connect() as connection:
        _ensure_shadow_user(
            connection,
            payload.owner_user_id,
            payload.owner_user_id,
            "analyst",
        )
        _ensure_shadow_user(
            connection,
            payload.actor_user_id,
            payload.actor_user_id,
            "analyst",
        )
        existing = connection.execute(
            "SELECT version, created_at FROM workspace_snapshots WHERE scope_key = ?",
            (scope_key,),
        ).fetchone()
        version = 1 if existing is None else int(existing["version"]) + 1
        created_at = timestamp if existing is None else existing["created_at"]
        snapshot = {
            "scope": payload.scope,
            "owner_user_id": payload.owner_user_id,
            "organization_id": payload.organization_id,
            "title": payload.title,
            "active_sheet": payload.active_sheet,
            "sheets": sheets,
            "version": version,
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
                payload.owner_user_id,
                payload.organization_id or None,
                payload.title.strip() or "Sports Terminal Workbook",
                payload.active_sheet.strip()[:31] or "Sheet 1",
                encode_json(sheets),
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
                payload.actor_user_id,
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
        return _serialize(row)


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
