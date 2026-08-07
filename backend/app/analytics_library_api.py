from __future__ import annotations

import sqlite3
from typing import Any, Literal

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from .launch_api import _require_role, init_launch_db
from .main import connect, decode_json, encode_json, make_id, now_iso

router = APIRouter(prefix="/v2/analytics-library", tags=["analytics-library"])

Scope = Literal["personal", "organization"]
AssetType = Literal[
    "stats_view",
    "comparison_set",
    "team_board",
    "dashboard",
    "chart",
    "research_package",
]
Visibility = Literal["private", "organization", "shared"]


class AnalyticsAssetUpsert(BaseModel):
    actor_user_id: str
    scope: Scope = "personal"
    owner_user_id: str
    organization_id: str = ""
    asset_type: AssetType
    title: str
    description: str = ""
    visibility: Visibility = "private"
    configuration: dict[str, Any] = Field(default_factory=dict)
    source_snapshot: dict[str, Any] = Field(default_factory=dict)
    tags: list[str] = Field(default_factory=list)
    pinned: bool = False
    expected_version: int | None = None


class AnalyticsAssetClone(BaseModel):
    actor_user_id: str
    owner_user_id: str
    organization_id: str = ""
    scope: Scope = "personal"
    title: str = ""


class AnalyticsAssetShare(BaseModel):
    actor_user_id: str
    visibility: Visibility
    organization_id: str = ""


class AnalyticsRecentEvent(BaseModel):
    actor_user_id: str
    owner_user_id: str
    organization_id: str = ""
    scope: Scope = "personal"
    asset_id: str = ""
    route: str
    label: str
    context: dict[str, Any] = Field(default_factory=dict)


def init_analytics_library_db() -> None:
    init_launch_db()
    with connect() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS analytics_assets (
              id TEXT PRIMARY KEY,
              scope_key TEXT NOT NULL,
              owner_user_id TEXT NOT NULL,
              organization_id TEXT,
              asset_type TEXT NOT NULL,
              title TEXT NOT NULL,
              description TEXT,
              visibility TEXT NOT NULL DEFAULT 'private',
              configuration_json TEXT NOT NULL DEFAULT '{}',
              source_snapshot_json TEXT NOT NULL DEFAULT '{}',
              tags_json TEXT NOT NULL DEFAULT '[]',
              pinned INTEGER NOT NULL DEFAULT 0,
              version INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS analytics_asset_versions (
              id TEXT PRIMARY KEY,
              asset_id TEXT NOT NULL REFERENCES analytics_assets(id) ON DELETE CASCADE,
              version INTEGER NOT NULL,
              payload_json TEXT NOT NULL,
              actor_user_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              UNIQUE(asset_id, version)
            );
            CREATE TABLE IF NOT EXISTS analytics_recent_events (
              id TEXT PRIMARY KEY,
              scope_key TEXT NOT NULL,
              owner_user_id TEXT NOT NULL,
              organization_id TEXT,
              asset_id TEXT,
              route TEXT NOT NULL,
              label TEXT NOT NULL,
              context_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_analytics_assets_scope
              ON analytics_assets(scope_key, pinned DESC, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_analytics_assets_type
              ON analytics_assets(asset_type, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_analytics_versions_asset
              ON analytics_asset_versions(asset_id, version DESC);
            CREATE INDEX IF NOT EXISTS idx_analytics_recent_scope
              ON analytics_recent_events(scope_key, created_at DESC);
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


def _require_scope(
    connection: sqlite3.Connection,
    *,
    actor_user_id: str,
    scope: Scope,
    owner_user_id: str,
    organization_id: str,
    minimum_role: str = "analyst",
) -> None:
    if scope == "organization":
        _require_role(connection, organization_id, actor_user_id, minimum_role)
    elif actor_user_id != owner_user_id:
        raise HTTPException(status_code=403, detail="Users can access only their personal analytics library")


def _serialize(row: sqlite3.Row) -> dict[str, Any]:
    item = dict(row)
    item["configuration"] = decode_json(item.pop("configuration_json"), {})
    item["source_snapshot"] = decode_json(item.pop("source_snapshot_json"), {})
    item["tags"] = decode_json(item.pop("tags_json"), [])
    item["pinned"] = bool(item["pinned"])
    return item


def _payload(item: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": item["id"],
        "scope_key": item["scope_key"],
        "owner_user_id": item["owner_user_id"],
        "organization_id": item.get("organization_id"),
        "asset_type": item["asset_type"],
        "title": item["title"],
        "description": item.get("description") or "",
        "visibility": item["visibility"],
        "configuration": item.get("configuration") or {},
        "source_snapshot": item.get("source_snapshot") or {},
        "tags": item.get("tags") or [],
        "pinned": bool(item.get("pinned")),
        "version": item["version"],
        "created_at": item["created_at"],
        "updated_at": item["updated_at"],
    }


@router.on_event("startup")
def startup() -> None:
    init_analytics_library_db()


@router.get("/assets")
def list_assets(
    owner_user_id: str,
    scope: Scope = "personal",
    organization_id: str = "",
    asset_type: str = "",
    query: str = "",
    limit: int = Query(default=200, ge=1, le=1000),
) -> list[dict[str, Any]]:
    init_analytics_library_db()
    key = _scope_key(scope, owner_user_id, organization_id)
    sql = "SELECT * FROM analytics_assets WHERE scope_key = ?"
    values: list[Any] = [key]
    if asset_type:
        sql += " AND asset_type = ?"
        values.append(asset_type)
    if query:
        sql += " AND (LOWER(title) LIKE ? OR LOWER(description) LIKE ? OR LOWER(tags_json) LIKE ?)"
        token = f"%{query.lower()}%"
        values.extend([token, token, token])
    sql += " ORDER BY pinned DESC, updated_at DESC LIMIT ?"
    values.append(limit)
    with connect() as connection:
        return [_serialize(row) for row in connection.execute(sql, values).fetchall()]


@router.get("/assets/{asset_id}")
def get_asset(asset_id: str) -> dict[str, Any]:
    init_analytics_library_db()
    with connect() as connection:
        row = connection.execute("SELECT * FROM analytics_assets WHERE id = ?", (asset_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Analytics asset not found")
        return _serialize(row)


@router.put("/assets/{asset_id}")
def upsert_asset(asset_id: str, payload: AnalyticsAssetUpsert) -> dict[str, Any]:
    init_analytics_library_db()
    key = _scope_key(payload.scope, payload.owner_user_id, payload.organization_id)
    timestamp = now_iso()
    with connect() as connection:
        _require_scope(
            connection,
            actor_user_id=payload.actor_user_id,
            scope=payload.scope,
            owner_user_id=payload.owner_user_id,
            organization_id=payload.organization_id,
        )
        existing = connection.execute("SELECT * FROM analytics_assets WHERE id = ?", (asset_id,)).fetchone()
        if existing is not None and existing["scope_key"] != key:
            raise HTTPException(status_code=409, detail="Analytics asset cannot change ownership scope")
        current_version = 0 if existing is None else int(existing["version"])
        if payload.expected_version is not None and payload.expected_version != current_version:
            raise HTTPException(
                status_code=409,
                detail={"message": "Analytics asset version conflict", "current_version": current_version},
            )
        version = current_version + 1
        created_at = timestamp if existing is None else existing["created_at"]
        connection.execute(
            """
            INSERT INTO analytics_assets (
              id, scope_key, owner_user_id, organization_id, asset_type, title,
              description, visibility, configuration_json, source_snapshot_json,
              tags_json, pinned, version, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              asset_type=excluded.asset_type, title=excluded.title,
              description=excluded.description, visibility=excluded.visibility,
              configuration_json=excluded.configuration_json,
              source_snapshot_json=excluded.source_snapshot_json,
              tags_json=excluded.tags_json, pinned=excluded.pinned,
              version=excluded.version, updated_at=excluded.updated_at
            """,
            (
                asset_id,
                key,
                payload.owner_user_id,
                payload.organization_id or None,
                payload.asset_type,
                payload.title,
                payload.description,
                payload.visibility,
                encode_json(payload.configuration),
                encode_json(payload.source_snapshot),
                encode_json(sorted(set(payload.tags))),
                int(payload.pinned),
                version,
                created_at,
                timestamp,
            ),
        )
        saved = _serialize(connection.execute("SELECT * FROM analytics_assets WHERE id = ?", (asset_id,)).fetchone())
        connection.execute(
            "INSERT INTO analytics_asset_versions (id, asset_id, version, payload_json, actor_user_id, created_at) VALUES (?, ?, ?, ?, ?, ?)",
            (make_id("av"), asset_id, version, encode_json(_payload(saved)), payload.actor_user_id, timestamp),
        )
        connection.commit()
        return saved


@router.delete("/assets/{asset_id}")
def delete_asset(asset_id: str, actor_user_id: str = Query(...)) -> dict[str, Any]:
    init_analytics_library_db()
    with connect() as connection:
        row = connection.execute("SELECT * FROM analytics_assets WHERE id = ?", (asset_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Analytics asset not found")
        scope: Scope = "organization" if str(row["scope_key"]).startswith("organization:") else "personal"
        _require_scope(
            connection,
            actor_user_id=actor_user_id,
            scope=scope,
            owner_user_id=row["owner_user_id"],
            organization_id=row["organization_id"] or "",
        )
        connection.execute("DELETE FROM analytics_assets WHERE id = ?", (asset_id,))
        connection.commit()
    return {"deleted": True, "id": asset_id}


@router.post("/assets/{asset_id}/clone")
def clone_asset(asset_id: str, payload: AnalyticsAssetClone) -> dict[str, Any]:
    original = get_asset(asset_id)
    clone_id = make_id("analytics")
    return upsert_asset(
        clone_id,
        AnalyticsAssetUpsert(
            actor_user_id=payload.actor_user_id,
            scope=payload.scope,
            owner_user_id=payload.owner_user_id,
            organization_id=payload.organization_id,
            asset_type=original["asset_type"],
            title=payload.title or f"{original['title']} copy",
            description=original.get("description") or "",
            visibility="organization" if payload.scope == "organization" else "private",
            configuration=original.get("configuration") or {},
            source_snapshot=original.get("source_snapshot") or {},
            tags=original.get("tags") or [],
            pinned=False,
            expected_version=0,
        ),
    )


@router.put("/assets/{asset_id}/share")
def share_asset(asset_id: str, payload: AnalyticsAssetShare) -> dict[str, Any]:
    current = get_asset(asset_id)
    scope: Scope = "organization" if str(current["scope_key"]).startswith("organization:") else "personal"
    return upsert_asset(
        asset_id,
        AnalyticsAssetUpsert(
            actor_user_id=payload.actor_user_id,
            scope=scope,
            owner_user_id=current["owner_user_id"],
            organization_id=payload.organization_id or current.get("organization_id") or "",
            asset_type=current["asset_type"],
            title=current["title"],
            description=current.get("description") or "",
            visibility=payload.visibility,
            configuration=current.get("configuration") or {},
            source_snapshot=current.get("source_snapshot") or {},
            tags=current.get("tags") or [],
            pinned=bool(current.get("pinned")),
            expected_version=int(current["version"]),
        ),
    )


@router.get("/assets/{asset_id}/versions")
def list_versions(asset_id: str) -> list[dict[str, Any]]:
    init_analytics_library_db()
    with connect() as connection:
        rows = connection.execute(
            "SELECT * FROM analytics_asset_versions WHERE asset_id = ? ORDER BY version DESC LIMIT 100",
            (asset_id,),
        ).fetchall()
        return [
            {
                **dict(row),
                "payload": decode_json(row["payload_json"], {}),
            }
            for row in rows
        ]


@router.post("/recent")
def record_recent(payload: AnalyticsRecentEvent) -> dict[str, Any]:
    init_analytics_library_db()
    key = _scope_key(payload.scope, payload.owner_user_id, payload.organization_id)
    timestamp = now_iso()
    with connect() as connection:
        _require_scope(
            connection,
            actor_user_id=payload.actor_user_id,
            scope=payload.scope,
            owner_user_id=payload.owner_user_id,
            organization_id=payload.organization_id,
        )
        event_id = make_id("recent")
        connection.execute(
            "INSERT INTO analytics_recent_events (id, scope_key, owner_user_id, organization_id, asset_id, route, label, context_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                event_id,
                key,
                payload.owner_user_id,
                payload.organization_id or None,
                payload.asset_id or None,
                payload.route,
                payload.label,
                encode_json(payload.context),
                timestamp,
            ),
        )
        connection.execute(
            "DELETE FROM analytics_recent_events WHERE id IN (SELECT id FROM analytics_recent_events WHERE scope_key = ? ORDER BY created_at DESC LIMIT -1 OFFSET 100)",
            (key,),
        )
        connection.commit()
    return {"id": event_id, "created_at": timestamp}


@router.get("/recent")
def list_recent(
    owner_user_id: str,
    scope: Scope = "personal",
    organization_id: str = "",
    limit: int = Query(default=30, ge=1, le=100),
) -> list[dict[str, Any]]:
    init_analytics_library_db()
    key = _scope_key(scope, owner_user_id, organization_id)
    with connect() as connection:
        rows = connection.execute(
            "SELECT * FROM analytics_recent_events WHERE scope_key = ? ORDER BY created_at DESC LIMIT ?",
            (key, limit),
        ).fetchall()
        return [
            {
                **dict(row),
                "context": decode_json(row["context_json"], {}),
            }
            for row in rows
        ]


@router.get("/summary")
def analytics_summary(
    owner_user_id: str,
    scope: Scope = "personal",
    organization_id: str = "",
) -> dict[str, Any]:
    init_analytics_library_db()
    key = _scope_key(scope, owner_user_id, organization_id)
    with connect() as connection:
        by_type = {
            row["asset_type"]: int(row["count"])
            for row in connection.execute(
                "SELECT asset_type, COUNT(*) AS count FROM analytics_assets WHERE scope_key = ? GROUP BY asset_type",
                (key,),
            ).fetchall()
        }
        total = sum(by_type.values())
        pinned = connection.execute(
            "SELECT COUNT(*) AS count FROM analytics_assets WHERE scope_key = ? AND pinned = 1",
            (key,),
        ).fetchone()["count"]
        recent = connection.execute(
            "SELECT COUNT(*) AS count FROM analytics_recent_events WHERE scope_key = ?",
            (key,),
        ).fetchone()["count"]
        return {
            "scope_key": key,
            "total_assets": total,
            "pinned_assets": int(pinned),
            "recent_events": int(recent),
            "assets_by_type": by_type,
        }
