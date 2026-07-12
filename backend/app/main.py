from __future__ import annotations

import json
import os
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

BACKEND_ROOT = Path(__file__).resolve().parents[1]
DB_PATH = Path(os.getenv("SPORTS_TERMINAL_DB_PATH", BACKEND_ROOT / ".data" / "sports_terminal.db"))

app = FastAPI(
    title="Sports Terminal API",
    version="0.2.0",
    description="Durable local backend for users, profiles, favorites, workspaces, community, messaging, CMS, billing, admin, and data operations.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in os.getenv("SPORTS_TERMINAL_CORS_ORIGINS", "*").split(",")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def make_id(prefix: str) -> str:
    return f"{prefix}_{uuid4().hex[:12]}"


def connect() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    return connection


def row_to_dict(row: sqlite3.Row | None) -> dict[str, Any] | None:
    if row is None:
        return None
    return dict(row)


def rows_to_dicts(rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
    return [dict(row) for row in rows]


def encode_json(value: Any) -> str:
    return json.dumps(value, separators=(",", ":"), sort_keys=True)


def decode_json(value: str | None, fallback: Any) -> Any:
    if value is None or value == "":
        return fallback
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return fallback


def require_row(collection: str, item_id: str, row: sqlite3.Row | None) -> dict[str, Any]:
    item = row_to_dict(row)
    if item is None:
        raise HTTPException(status_code=404, detail=f"{collection} item not found: {item_id}")
    return item


def ensure_user(connection: sqlite3.Connection, user_id: str) -> None:
    row = connection.execute("SELECT id FROM users WHERE id = ?", (user_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="User not found")


def init_db() -> None:
    with connect() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
              id TEXT PRIMARY KEY,
              email TEXT UNIQUE NOT NULL,
              display_name TEXT NOT NULL,
              role TEXT NOT NULL DEFAULT 'user',
              status TEXT NOT NULL DEFAULT 'active',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS user_profiles (
              user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
              handle TEXT UNIQUE,
              bio TEXT,
              avatar_url TEXT,
              is_public INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS user_settings (
              user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
              dark_mode INTEGER NOT NULL DEFAULT 0,
              email_digest INTEGER NOT NULL DEFAULT 0,
              fantasy_alerts INTEGER NOT NULL DEFAULT 1,
              notification_preferences TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS favorite_teams (
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              team_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              PRIMARY KEY (user_id, team_id)
            );

            CREATE TABLE IF NOT EXISTS favorite_players (
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              player_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              PRIMARY KEY (user_id, player_id)
            );

            CREATE TABLE IF NOT EXISTS player_watchlists (
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              player_id TEXT NOT NULL,
              source TEXT NOT NULL DEFAULT 'manual',
              notes TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              PRIMARY KEY (user_id, player_id)
            );

            CREATE TABLE IF NOT EXISTS workbooks (
              id TEXT PRIMARY KEY,
              owner_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              title TEXT NOT NULL,
              visibility TEXT NOT NULL DEFAULT 'private',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS workbook_cells (
              workbook_id TEXT NOT NULL REFERENCES workbooks(id) ON DELETE CASCADE,
              sheet TEXT NOT NULL DEFAULT 'Sheet 1',
              cell_ref TEXT NOT NULL,
              raw_value TEXT NOT NULL DEFAULT '',
              updated_at TEXT NOT NULL,
              PRIMARY KEY (workbook_id, sheet, cell_ref)
            );

            CREATE TABLE IF NOT EXISTS posts (
              id TEXT PRIMARY KEY,
              author_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              board TEXT NOT NULL,
              title TEXT NOT NULL,
              body TEXT NOT NULL,
              entity_type TEXT,
              entity_id TEXT,
              status TEXT NOT NULL DEFAULT 'published',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS comments (
              id TEXT PRIMARY KEY,
              post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
              author_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              body TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'published',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS reactions (
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              target_type TEXT NOT NULL,
              target_id TEXT NOT NULL,
              kind TEXT NOT NULL DEFAULT 'like',
              created_at TEXT NOT NULL,
              PRIMARY KEY (user_id, target_type, target_id, kind)
            );

            CREATE TABLE IF NOT EXISTS reports (
              id TEXT PRIMARY KEY,
              reporter_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              target_type TEXT NOT NULL,
              target_id TEXT NOT NULL,
              reason TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'open',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS conversations (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS conversation_members (
              conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              muted INTEGER NOT NULL DEFAULT 0,
              last_read_at TEXT,
              created_at TEXT NOT NULL,
              PRIMARY KEY (conversation_id, user_id)
            );

            CREATE TABLE IF NOT EXISTS messages (
              id TEXT PRIMARY KEY,
              conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
              sender_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              body TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'sent',
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS articles (
              id TEXT PRIMARY KEY,
              author_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              title TEXT NOT NULL,
              body TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'draft',
              tags TEXT NOT NULL DEFAULT '[]',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS plans (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              price_cents INTEGER NOT NULL DEFAULT 0,
              features TEXT NOT NULL DEFAULT '[]'
            );

            CREATE TABLE IF NOT EXISTS subscriptions (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              plan_id TEXT NOT NULL REFERENCES plans(id),
              status TEXT NOT NULL DEFAULT 'trialing',
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS feature_flags (
              flag TEXT PRIMARY KEY,
              enabled INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS data_sources (
              id TEXT PRIMARY KEY,
              source_type TEXT NOT NULL,
              label TEXT NOT NULL,
              config TEXT NOT NULL DEFAULT '{}',
              enabled INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS pipeline_runs (
              id TEXT PRIMARY KEY,
              source TEXT NOT NULL,
              season TEXT,
              status TEXT NOT NULL,
              summary TEXT NOT NULL DEFAULT '{}',
              recorded_at TEXT NOT NULL
            );
            """
        )
        seed_defaults(connection)
        connection.commit()


def seed_defaults(connection: sqlite3.Connection) -> None:
    timestamp = now_iso()
    plans = [
        ("free", "Free", 0, ["NBA hub", "community read", "local workspace"]),
        ("pro", "Pro", 999, ["saved workspaces", "advanced fantasy", "alerts"]),
        ("org", "Organization", 4999, ["shared workspaces", "admin console", "team seats"]),
    ]
    for plan_id, name, price_cents, features in plans:
        connection.execute(
            "INSERT OR IGNORE INTO plans (id, name, price_cents, features) VALUES (?, ?, ?, ?)",
            (plan_id, name, price_cents, encode_json(features)),
        )
    for flag in ["community_write", "messaging", "billing", "current_season", "twitter_feed", "backend_sync"]:
        connection.execute(
            "INSERT OR IGNORE INTO feature_flags (flag, enabled, updated_at) VALUES (?, 0, ?)",
            (flag, timestamp),
        )


@app.on_event("startup")
def startup() -> None:
    init_db()


class UserCreate(BaseModel):
    email: str
    display_name: str
    role: str = "user"


class ProfileUpdate(BaseModel):
    handle: str | None = None
    bio: str | None = None
    avatar_url: str | None = None
    is_public: bool = True


class SettingsUpdate(BaseModel):
    dark_mode: bool = False
    email_digest: bool = False
    fantasy_alerts: bool = True
    notification_preferences: dict[str, Any] = Field(default_factory=dict)


class FavoriteUpdate(BaseModel):
    item_id: str


class WatchlistUpdate(BaseModel):
    player_id: str
    source: str = "manual"
    notes: str | None = None


class WorkbookCreate(BaseModel):
    owner_user_id: str
    title: str
    visibility: str = "private"


class CellUpdate(BaseModel):
    sheet: str = "Sheet 1"
    cell_ref: str
    raw_value: str


class PostCreate(BaseModel):
    author_user_id: str
    board: str
    title: str
    body: str
    entity_type: str | None = None
    entity_id: str | None = None


class CommentCreate(BaseModel):
    author_user_id: str
    body: str


class ReactionUpdate(BaseModel):
    user_id: str
    kind: str = "like"


class ReportCreate(BaseModel):
    reporter_user_id: str
    target_type: str
    target_id: str
    reason: str


class ConversationCreate(BaseModel):
    title: str
    member_user_ids: list[str]


class MessageCreate(BaseModel):
    sender_user_id: str
    body: str


class ArticleCreate(BaseModel):
    author_user_id: str
    title: str
    body: str
    status: str = "draft"
    tags: list[str] = Field(default_factory=list)


class ArticleStatusUpdate(BaseModel):
    status: str


class SubscriptionUpdate(BaseModel):
    user_id: str
    plan_id: str
    status: str = "trialing"


class FeatureFlagUpdate(BaseModel):
    enabled: bool


class DataSourceUpdate(BaseModel):
    source_type: str
    label: str
    config: dict[str, Any] = Field(default_factory=dict)
    enabled: bool = False


@app.get("/health")
def health() -> dict[str, Any]:
    init_db()
    return {"status": "ok", "service": "sports-terminal-api", "version": app.version, "database": str(DB_PATH), "timestamp": now_iso()}


@app.get("/launch/readiness")
def launch_readiness() -> dict[str, Any]:
    with connect() as connection:
        tables = rows_to_dicts(connection.execute("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name").fetchall())
    return {
        "status": "local-durable-prototype",
        "backend": "FastAPI + SQLite",
        "completed": [
            "durable local database",
            "users/profile/settings endpoints",
            "favorites/watchlists endpoints",
            "workspace cells endpoints",
            "community/comments/reactions/reporting endpoints",
            "messaging endpoints",
            "CMS/article endpoints",
            "billing placeholders",
            "admin feature flags and pipeline-run records",
        ],
        "production_blockers": [
            "real auth/session provider",
            "role-based authorization on every protected route",
            "managed Postgres or equivalent hosted database",
            "migration runner and backup policy",
            "billing provider integration",
            "moderation operations and audit workflow",
            "hosting, monitoring, logging, analytics, secrets, and rate limits",
            "legal review and data-source agreements before public launch",
        ],
        "tables": [table["name"] for table in tables],
    }


@app.post("/users")
def create_user(payload: UserCreate) -> dict[str, Any]:
    timestamp = now_iso()
    user_id = make_id("usr")
    with connect() as connection:
        existing = connection.execute("SELECT id FROM users WHERE email = ?", (payload.email,)).fetchone()
        if existing is not None:
            raise HTTPException(status_code=409, detail="Email already exists")
        connection.execute(
            "INSERT INTO users (id, email, display_name, role, status, created_at, updated_at) VALUES (?, ?, ?, ?, 'active', ?, ?)",
            (user_id, payload.email, payload.display_name, payload.role, timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO user_profiles (user_id, is_public, created_at, updated_at) VALUES (?, 1, ?, ?)",
            (user_id, timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO user_settings (user_id, dark_mode, email_digest, fantasy_alerts, notification_preferences, created_at, updated_at) VALUES (?, 0, 0, 1, '{}', ?, ?)",
            (user_id, timestamp, timestamp),
        )
        connection.commit()
        return get_user(user_id)


@app.get("/users")
def list_users() -> list[dict[str, Any]]:
    with connect() as connection:
        return rows_to_dicts(connection.execute("SELECT * FROM users ORDER BY created_at DESC").fetchall())


@app.get("/users/{user_id}")
def get_user(user_id: str) -> dict[str, Any]:
    with connect() as connection:
        return require_row("users", user_id, connection.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone())


@app.get("/users/{user_id}/profile")
def get_profile(user_id: str) -> dict[str, Any]:
    with connect() as connection:
        ensure_user(connection, user_id)
        profile = require_row("profiles", user_id, connection.execute("SELECT * FROM user_profiles WHERE user_id = ?", (user_id,)).fetchone())
        profile["is_public"] = bool(profile["is_public"])
        return profile


@app.put("/users/{user_id}/profile")
def update_profile(user_id: str, payload: ProfileUpdate) -> dict[str, Any]:
    timestamp = now_iso()
    with connect() as connection:
        ensure_user(connection, user_id)
        connection.execute(
            "UPDATE user_profiles SET handle = ?, bio = ?, avatar_url = ?, is_public = ?, updated_at = ? WHERE user_id = ?",
            (payload.handle, payload.bio, payload.avatar_url, int(payload.is_public), timestamp, user_id),
        )
        connection.commit()
    return get_profile(user_id)


@app.get("/users/{user_id}/settings")
def get_settings(user_id: str) -> dict[str, Any]:
    with connect() as connection:
        ensure_user(connection, user_id)
        settings = require_row("settings", user_id, connection.execute("SELECT * FROM user_settings WHERE user_id = ?", (user_id,)).fetchone())
        settings["dark_mode"] = bool(settings["dark_mode"])
        settings["email_digest"] = bool(settings["email_digest"])
        settings["fantasy_alerts"] = bool(settings["fantasy_alerts"])
        settings["notification_preferences"] = decode_json(settings["notification_preferences"], {})
        return settings


@app.put("/users/{user_id}/settings")
def update_settings(user_id: str, payload: SettingsUpdate) -> dict[str, Any]:
    timestamp = now_iso()
    with connect() as connection:
        ensure_user(connection, user_id)
        connection.execute(
            "UPDATE user_settings SET dark_mode = ?, email_digest = ?, fantasy_alerts = ?, notification_preferences = ?, updated_at = ? WHERE user_id = ?",
            (int(payload.dark_mode), int(payload.email_digest), int(payload.fantasy_alerts), encode_json(payload.notification_preferences), timestamp, user_id),
        )
        connection.commit()
    return get_settings(user_id)


@app.get("/users/{user_id}/personalization")
def get_personalization(user_id: str) -> dict[str, Any]:
    with connect() as connection:
        ensure_user(connection, user_id)
        favorite_teams = rows_to_dicts(connection.execute("SELECT team_id FROM favorite_teams WHERE user_id = ? ORDER BY team_id", (user_id,)).fetchall())
        favorite_players = rows_to_dicts(connection.execute("SELECT player_id FROM favorite_players WHERE user_id = ? ORDER BY player_id", (user_id,)).fetchall())
        watchlist = rows_to_dicts(connection.execute("SELECT player_id, source, notes, created_at, updated_at FROM player_watchlists WHERE user_id = ? ORDER BY updated_at DESC", (user_id,)).fetchall())
        return {
            "favorite_teams": [row["team_id"] for row in favorite_teams],
            "favorite_players": [row["player_id"] for row in favorite_players],
            "watchlist": watchlist,
        }


@app.post("/users/{user_id}/favorite-teams")
def add_favorite_team(user_id: str, payload: FavoriteUpdate) -> dict[str, Any]:
    with connect() as connection:
        ensure_user(connection, user_id)
        connection.execute("INSERT OR IGNORE INTO favorite_teams (user_id, team_id, created_at) VALUES (?, ?, ?)", (user_id, payload.item_id, now_iso()))
        connection.commit()
    return get_personalization(user_id)


@app.delete("/users/{user_id}/favorite-teams/{team_id}")
def remove_favorite_team(user_id: str, team_id: str) -> dict[str, Any]:
    with connect() as connection:
        ensure_user(connection, user_id)
        connection.execute("DELETE FROM favorite_teams WHERE user_id = ? AND team_id = ?", (user_id, team_id))
        connection.commit()
    return get_personalization(user_id)


@app.post("/users/{user_id}/favorite-players")
def add_favorite_player(user_id: str, payload: FavoriteUpdate) -> dict[str, Any]:
    with connect() as connection:
        ensure_user(connection, user_id)
        connection.execute("INSERT OR IGNORE INTO favorite_players (user_id, player_id, created_at) VALUES (?, ?, ?)", (user_id, payload.item_id, now_iso()))
        connection.commit()
    return get_personalization(user_id)


@app.delete("/users/{user_id}/favorite-players/{player_id}")
def remove_favorite_player(user_id: str, player_id: str) -> dict[str, Any]:
    with connect() as connection:
        ensure_user(connection, user_id)
        connection.execute("DELETE FROM favorite_players WHERE user_id = ? AND player_id = ?", (user_id, player_id))
        connection.commit()
    return get_personalization(user_id)


@app.post("/users/{user_id}/watchlist")
def add_watchlist_player(user_id: str, payload: WatchlistUpdate) -> dict[str, Any]:
    timestamp = now_iso()
    with connect() as connection:
        ensure_user(connection, user_id)
        connection.execute(
            """
            INSERT INTO player_watchlists (user_id, player_id, source, notes, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(user_id, player_id) DO UPDATE SET source = excluded.source, notes = excluded.notes, updated_at = excluded.updated_at
            """,
            (user_id, payload.player_id, payload.source, payload.notes, timestamp, timestamp),
        )
        connection.commit()
    return get_personalization(user_id)


@app.delete("/users/{user_id}/watchlist/{player_id}")
def remove_watchlist_player(user_id: str, player_id: str) -> dict[str, Any]:
    with connect() as connection:
        ensure_user(connection, user_id)
        connection.execute("DELETE FROM player_watchlists WHERE user_id = ? AND player_id = ?", (user_id, player_id))
        connection.commit()
    return get_personalization(user_id)


@app.post("/workbooks")
def create_workbook(payload: WorkbookCreate) -> dict[str, Any]:
    timestamp = now_iso()
    workbook_id = make_id("wb")
    with connect() as connection:
        ensure_user(connection, payload.owner_user_id)
        connection.execute(
            "INSERT INTO workbooks (id, owner_user_id, title, visibility, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
            (workbook_id, payload.owner_user_id, payload.title, payload.visibility, timestamp, timestamp),
        )
        connection.commit()
    return get_workbook(workbook_id)


@app.get("/workbooks/{workbook_id}")
def get_workbook(workbook_id: str) -> dict[str, Any]:
    with connect() as connection:
        workbook = require_row("workbooks", workbook_id, connection.execute("SELECT * FROM workbooks WHERE id = ?", (workbook_id,)).fetchone())
        cells = rows_to_dicts(connection.execute("SELECT sheet, cell_ref, raw_value, updated_at FROM workbook_cells WHERE workbook_id = ? ORDER BY sheet, cell_ref", (workbook_id,)).fetchall())
        sheets: dict[str, dict[str, str]] = {}
        for cell in cells:
            sheets.setdefault(cell["sheet"], {})[cell["cell_ref"]] = cell["raw_value"]
        workbook["sheets"] = sheets or {"Sheet 1": {}}
        return workbook


@app.put("/workbooks/{workbook_id}/cells")
def update_cell(workbook_id: str, payload: CellUpdate) -> dict[str, Any]:
    timestamp = now_iso()
    cell_ref = payload.cell_ref.strip().upper()
    with connect() as connection:
        require_row("workbooks", workbook_id, connection.execute("SELECT id FROM workbooks WHERE id = ?", (workbook_id,)).fetchone())
        if payload.raw_value == "":
            connection.execute("DELETE FROM workbook_cells WHERE workbook_id = ? AND sheet = ? AND cell_ref = ?", (workbook_id, payload.sheet, cell_ref))
        else:
            connection.execute(
                """
                INSERT INTO workbook_cells (workbook_id, sheet, cell_ref, raw_value, updated_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(workbook_id, sheet, cell_ref) DO UPDATE SET raw_value = excluded.raw_value, updated_at = excluded.updated_at
                """,
                (workbook_id, payload.sheet, cell_ref, payload.raw_value, timestamp),
            )
        connection.execute("UPDATE workbooks SET updated_at = ? WHERE id = ?", (timestamp, workbook_id))
        connection.commit()
    return get_workbook(workbook_id)


@app.get("/community/boards")
def get_boards() -> list[str]:
    return ["NBA General", "Team Rooms", "Fantasy", "Product Feedback", "Data Issues"]


@app.post("/community/posts")
def create_post(payload: PostCreate) -> dict[str, Any]:
    timestamp = now_iso()
    post_id = make_id("post")
    with connect() as connection:
        ensure_user(connection, payload.author_user_id)
        connection.execute(
            "INSERT INTO posts (id, author_user_id, board, title, body, entity_type, entity_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'published', ?, ?)",
            (post_id, payload.author_user_id, payload.board, payload.title, payload.body, payload.entity_type, payload.entity_id, timestamp, timestamp),
        )
        connection.commit()
    return get_post(post_id)


@app.get("/community/posts")
def list_posts(board: str | None = None, entity_type: str | None = None, entity_id: str | None = None) -> list[dict[str, Any]]:
    sql = "SELECT * FROM posts WHERE status != 'deleted'"
    params: list[Any] = []
    if board:
        sql += " AND board = ?"
        params.append(board)
    if entity_type:
        sql += " AND entity_type = ?"
        params.append(entity_type)
    if entity_id:
        sql += " AND entity_id = ?"
        params.append(entity_id)
    sql += " ORDER BY created_at DESC"
    with connect() as connection:
        posts = rows_to_dicts(connection.execute(sql, params).fetchall())
        for post in posts:
            post["comment_count"] = connection.execute("SELECT COUNT(*) AS count FROM comments WHERE post_id = ? AND status != 'deleted'", (post["id"],)).fetchone()["count"]
            post["like_count"] = connection.execute("SELECT COUNT(*) AS count FROM reactions WHERE target_type = 'post' AND target_id = ? AND kind = 'like'", (post["id"],)).fetchone()["count"]
        return posts


@app.get("/community/posts/{post_id}")
def get_post(post_id: str) -> dict[str, Any]:
    with connect() as connection:
        post = require_row("posts", post_id, connection.execute("SELECT * FROM posts WHERE id = ?", (post_id,)).fetchone())
        post["comments"] = rows_to_dicts(connection.execute("SELECT * FROM comments WHERE post_id = ? AND status != 'deleted' ORDER BY created_at ASC", (post_id,)).fetchall())
        post["like_count"] = connection.execute("SELECT COUNT(*) AS count FROM reactions WHERE target_type = 'post' AND target_id = ? AND kind = 'like'", (post_id,)).fetchone()["count"]
        return post


@app.post("/community/posts/{post_id}/comments")
def create_comment(post_id: str, payload: CommentCreate) -> dict[str, Any]:
    timestamp = now_iso()
    comment_id = make_id("cmt")
    with connect() as connection:
        require_row("posts", post_id, connection.execute("SELECT id FROM posts WHERE id = ?", (post_id,)).fetchone())
        ensure_user(connection, payload.author_user_id)
        connection.execute(
            "INSERT INTO comments (id, post_id, author_user_id, body, status, created_at, updated_at) VALUES (?, ?, ?, ?, 'published', ?, ?)",
            (comment_id, post_id, payload.author_user_id, payload.body, timestamp, timestamp),
        )
        connection.commit()
        return require_row("comments", comment_id, connection.execute("SELECT * FROM comments WHERE id = ?", (comment_id,)).fetchone())


@app.post("/community/posts/{post_id}/reactions")
def react_to_post(post_id: str, payload: ReactionUpdate) -> dict[str, Any]:
    with connect() as connection:
        require_row("posts", post_id, connection.execute("SELECT id FROM posts WHERE id = ?", (post_id,)).fetchone())
        ensure_user(connection, payload.user_id)
        connection.execute(
            "INSERT OR IGNORE INTO reactions (user_id, target_type, target_id, kind, created_at) VALUES (?, 'post', ?, ?, ?)",
            (payload.user_id, post_id, payload.kind, now_iso()),
        )
        connection.commit()
    return get_post(post_id)


@app.delete("/community/posts/{post_id}/reactions/{user_id}")
def remove_post_reaction(post_id: str, user_id: str, kind: str = "like") -> dict[str, Any]:
    with connect() as connection:
        connection.execute("DELETE FROM reactions WHERE user_id = ? AND target_type = 'post' AND target_id = ? AND kind = ?", (user_id, post_id, kind))
        connection.commit()
    return get_post(post_id)


@app.post("/moderation/reports")
def create_report(payload: ReportCreate) -> dict[str, Any]:
    timestamp = now_iso()
    report_id = make_id("rpt")
    with connect() as connection:
        ensure_user(connection, payload.reporter_user_id)
        connection.execute(
            "INSERT INTO reports (id, reporter_user_id, target_type, target_id, reason, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 'open', ?, ?)",
            (report_id, payload.reporter_user_id, payload.target_type, payload.target_id, payload.reason, timestamp, timestamp),
        )
        connection.commit()
        return require_row("reports", report_id, connection.execute("SELECT * FROM reports WHERE id = ?", (report_id,)).fetchone())


@app.get("/moderation/reports")
def list_reports(status: str | None = None) -> list[dict[str, Any]]:
    sql = "SELECT * FROM reports"
    params: list[Any] = []
    if status:
        sql += " WHERE status = ?"
        params.append(status)
    sql += " ORDER BY created_at DESC"
    with connect() as connection:
        return rows_to_dicts(connection.execute(sql, params).fetchall())


@app.post("/messages/conversations")
def create_conversation(payload: ConversationCreate) -> dict[str, Any]:
    timestamp = now_iso()
    conversation_id = make_id("conv")
    member_ids = sorted(set(payload.member_user_ids))
    with connect() as connection:
        for user_id in member_ids:
            ensure_user(connection, user_id)
        connection.execute("INSERT INTO conversations (id, title, created_at, updated_at) VALUES (?, ?, ?, ?)", (conversation_id, payload.title, timestamp, timestamp))
        for user_id in member_ids:
            connection.execute("INSERT INTO conversation_members (conversation_id, user_id, created_at) VALUES (?, ?, ?)", (conversation_id, user_id, timestamp))
        connection.commit()
    return get_conversation(conversation_id)


@app.get("/messages/conversations/{conversation_id}")
def get_conversation(conversation_id: str) -> dict[str, Any]:
    with connect() as connection:
        conversation = require_row("conversations", conversation_id, connection.execute("SELECT * FROM conversations WHERE id = ?", (conversation_id,)).fetchone())
        conversation["members"] = [row["user_id"] for row in connection.execute("SELECT user_id FROM conversation_members WHERE conversation_id = ? ORDER BY user_id", (conversation_id,)).fetchall()]
        conversation["message_count"] = connection.execute("SELECT COUNT(*) AS count FROM messages WHERE conversation_id = ?", (conversation_id,)).fetchone()["count"]
        return conversation


@app.get("/users/{user_id}/conversations")
def list_user_conversations(user_id: str) -> list[dict[str, Any]]:
    with connect() as connection:
        ensure_user(connection, user_id)
        rows = connection.execute(
            """
            SELECT conversations.* FROM conversations
            JOIN conversation_members ON conversations.id = conversation_members.conversation_id
            WHERE conversation_members.user_id = ?
            ORDER BY conversations.updated_at DESC
            """,
            (user_id,),
        ).fetchall()
        return rows_to_dicts(rows)


@app.post("/messages/conversations/{conversation_id}/messages")
def send_message(conversation_id: str, payload: MessageCreate) -> dict[str, Any]:
    timestamp = now_iso()
    message_id = make_id("msg")
    with connect() as connection:
        require_row("conversations", conversation_id, connection.execute("SELECT id FROM conversations WHERE id = ?", (conversation_id,)).fetchone())
        ensure_user(connection, payload.sender_user_id)
        membership = connection.execute("SELECT 1 FROM conversation_members WHERE conversation_id = ? AND user_id = ?", (conversation_id, payload.sender_user_id)).fetchone()
        if membership is None:
            raise HTTPException(status_code=403, detail="Sender is not a conversation member")
        connection.execute("INSERT INTO messages (id, conversation_id, sender_user_id, body, status, created_at) VALUES (?, ?, ?, ?, 'sent', ?)", (message_id, conversation_id, payload.sender_user_id, payload.body, timestamp))
        connection.execute("UPDATE conversations SET updated_at = ? WHERE id = ?", (timestamp, conversation_id))
        connection.commit()
        return require_row("messages", message_id, connection.execute("SELECT * FROM messages WHERE id = ?", (message_id,)).fetchone())


@app.get("/messages/conversations/{conversation_id}/messages")
def list_messages(conversation_id: str) -> list[dict[str, Any]]:
    with connect() as connection:
        require_row("conversations", conversation_id, connection.execute("SELECT id FROM conversations WHERE id = ?", (conversation_id,)).fetchone())
        return rows_to_dicts(connection.execute("SELECT * FROM messages WHERE conversation_id = ? ORDER BY created_at ASC", (conversation_id,)).fetchall())


@app.post("/cms/articles")
def create_article(payload: ArticleCreate) -> dict[str, Any]:
    timestamp = now_iso()
    article_id = make_id("art")
    with connect() as connection:
        ensure_user(connection, payload.author_user_id)
        connection.execute(
            "INSERT INTO articles (id, author_user_id, title, body, status, tags, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (article_id, payload.author_user_id, payload.title, payload.body, payload.status, encode_json(payload.tags), timestamp, timestamp),
        )
        connection.commit()
        return get_article(article_id)


@app.get("/cms/articles")
def list_articles(status: str | None = None) -> list[dict[str, Any]]:
    sql = "SELECT * FROM articles"
    params: list[Any] = []
    if status:
        sql += " WHERE status = ?"
        params.append(status)
    sql += " ORDER BY updated_at DESC"
    with connect() as connection:
        articles = rows_to_dicts(connection.execute(sql, params).fetchall())
        for article in articles:
            article["tags"] = decode_json(article.get("tags"), [])
        return articles


@app.get("/cms/articles/{article_id}")
def get_article(article_id: str) -> dict[str, Any]:
    with connect() as connection:
        article = require_row("articles", article_id, connection.execute("SELECT * FROM articles WHERE id = ?", (article_id,)).fetchone())
        article["tags"] = decode_json(article.get("tags"), [])
        return article


@app.put("/cms/articles/{article_id}/status")
def update_article_status(article_id: str, payload: ArticleStatusUpdate) -> dict[str, Any]:
    if payload.status not in {"draft", "published", "archived"}:
        raise HTTPException(status_code=400, detail="Invalid article status")
    with connect() as connection:
        require_row("articles", article_id, connection.execute("SELECT id FROM articles WHERE id = ?", (article_id,)).fetchone())
        connection.execute("UPDATE articles SET status = ?, updated_at = ? WHERE id = ?", (payload.status, now_iso(), article_id))
        connection.commit()
    return get_article(article_id)


@app.get("/billing/plans")
def list_plans() -> list[dict[str, Any]]:
    with connect() as connection:
        plans = rows_to_dicts(connection.execute("SELECT * FROM plans ORDER BY price_cents ASC").fetchall())
        for plan in plans:
            plan["features"] = decode_json(plan.get("features"), [])
        return plans


@app.put("/billing/subscriptions/{subscription_id}")
def upsert_subscription(subscription_id: str, payload: SubscriptionUpdate) -> dict[str, Any]:
    with connect() as connection:
        ensure_user(connection, payload.user_id)
        if connection.execute("SELECT id FROM plans WHERE id = ?", (payload.plan_id,)).fetchone() is None:
            raise HTTPException(status_code=404, detail="Plan not found")
        connection.execute(
            "INSERT OR REPLACE INTO subscriptions (id, user_id, plan_id, status, updated_at) VALUES (?, ?, ?, ?, ?)",
            (subscription_id, payload.user_id, payload.plan_id, payload.status, now_iso()),
        )
        connection.commit()
        return require_row("subscriptions", subscription_id, connection.execute("SELECT * FROM subscriptions WHERE id = ?", (subscription_id,)).fetchone())


@app.get("/admin/feature-flags")
def list_feature_flags() -> dict[str, bool]:
    with connect() as connection:
        rows = rows_to_dicts(connection.execute("SELECT flag, enabled FROM feature_flags ORDER BY flag").fetchall())
        return {row["flag"]: bool(row["enabled"]) for row in rows}


@app.put("/admin/feature-flags/{flag}")
def update_feature_flag(flag: str, payload: FeatureFlagUpdate) -> dict[str, bool]:
    with connect() as connection:
        if connection.execute("SELECT flag FROM feature_flags WHERE flag = ?", (flag,)).fetchone() is None:
            raise HTTPException(status_code=404, detail="Feature flag not found")
        connection.execute("UPDATE feature_flags SET enabled = ?, updated_at = ? WHERE flag = ?", (int(payload.enabled), now_iso(), flag))
        connection.commit()
    return list_feature_flags()


@app.get("/admin/data-sources")
def list_data_sources() -> list[dict[str, Any]]:
    with connect() as connection:
        rows = rows_to_dicts(connection.execute("SELECT * FROM data_sources ORDER BY source_type, label").fetchall())
        for row in rows:
            row["enabled"] = bool(row["enabled"])
            row["config"] = decode_json(row.get("config"), {})
        return rows


@app.put("/admin/data-sources/{source_id}")
def upsert_data_source(source_id: str, payload: DataSourceUpdate) -> dict[str, Any]:
    with connect() as connection:
        connection.execute(
            "INSERT OR REPLACE INTO data_sources (id, source_type, label, config, enabled, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
            (source_id, payload.source_type, payload.label, encode_json(payload.config), int(payload.enabled), now_iso()),
        )
        connection.commit()
        return require_row("data_sources", source_id, connection.execute("SELECT * FROM data_sources WHERE id = ?", (source_id,)).fetchone())


@app.get("/admin/data/pipeline-runs")
def list_pipeline_runs() -> list[dict[str, Any]]:
    with connect() as connection:
        rows = rows_to_dicts(connection.execute("SELECT * FROM pipeline_runs ORDER BY recorded_at DESC").fetchall())
        for row in rows:
            row["summary"] = decode_json(row.get("summary"), {})
        return rows


@app.post("/admin/data/pipeline-runs")
def record_pipeline_run(payload: dict[str, Any]) -> dict[str, Any]:
    run_id = make_id("run")
    with connect() as connection:
        connection.execute(
            "INSERT INTO pipeline_runs (id, source, season, status, summary, recorded_at) VALUES (?, ?, ?, ?, ?, ?)",
            (run_id, str(payload.get("source", "manual")), payload.get("season"), str(payload.get("status", "recorded")), encode_json(payload.get("summary", payload)), now_iso()),
        )
        connection.commit()
        run = connection.execute("SELECT * FROM pipeline_runs WHERE id = ?", (run_id,)).fetchone()
        item = require_row("pipeline_runs", run_id, run)
        item["summary"] = decode_json(item.get("summary"), {})
        return item
