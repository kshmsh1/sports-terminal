from __future__ import annotations

import os
import re
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from .launch_api import _ensure_shadow_user
from .main import connect, decode_json, encode_json, init_db, make_id, now_iso

router = APIRouter(prefix="/v2/trust", tags=["trust-safety"])

_ALLOWED_BOARDS = {"NBA General", "Team Rooms", "Fantasy", "Product Feedback", "Organization"}
_ALLOWED_ACTIONS = {"approve", "hide", "remove", "restore", "warn", "suspend", "ban", "close"}


class CommunityPostCreate(BaseModel):
    actor_user_id: str
    board: str
    title: str
    body: str
    entity_type: str = ""
    entity_id: str = ""


class CommunityCommentCreate(BaseModel):
    actor_user_id: str
    body: str


class ReactionToggle(BaseModel):
    actor_user_id: str
    kind: str = "like"


class ReportCreate(BaseModel):
    actor_user_id: str
    target_type: str
    target_id: str
    reason: str
    details: str = ""
    priority: str = "normal"


class RelationshipUpdate(BaseModel):
    actor_user_id: str
    target_user_id: str
    reason: str = ""


class ModerationActionCreate(BaseModel):
    actor_user_id: str
    action: str
    reason: str
    resolution: str = ""
    expires_at: str = ""
    payload: dict[str, Any] = Field(default_factory=dict)


class ConversationCreate(BaseModel):
    actor_user_id: str
    title: str = "Direct message"
    member_user_ids: list[str]


class MessageCreate(BaseModel):
    actor_user_id: str
    body: str


def init_trust_safety_db() -> None:
    init_db()
    with connect() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS user_blocks (
              blocker_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              blocked_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              reason TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              PRIMARY KEY (blocker_user_id, blocked_user_id)
            );

            CREATE TABLE IF NOT EXISTS user_mutes (
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              muted_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              reason TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              PRIMARY KEY (user_id, muted_user_id)
            );

            CREATE TABLE IF NOT EXISTS moderation_cases (
              id TEXT PRIMARY KEY,
              reporter_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              target_type TEXT NOT NULL,
              target_id TEXT NOT NULL,
              target_user_id TEXT,
              reason TEXT NOT NULL,
              details TEXT NOT NULL DEFAULT '',
              priority TEXT NOT NULL DEFAULT 'normal',
              status TEXT NOT NULL DEFAULT 'open',
              assigned_user_id TEXT,
              resolution TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS moderation_actions (
              id TEXT PRIMARY KEY,
              case_id TEXT NOT NULL REFERENCES moderation_cases(id) ON DELETE CASCADE,
              actor_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              action TEXT NOT NULL,
              target_type TEXT NOT NULL,
              target_id TEXT NOT NULL,
              reason TEXT NOT NULL,
              expires_at TEXT,
              payload_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS moderation_audit_events (
              id TEXT PRIMARY KEY,
              actor_user_id TEXT NOT NULL,
              event_type TEXT NOT NULL,
              target_type TEXT NOT NULL,
              target_id TEXT NOT NULL,
              payload_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS user_sanctions (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              action TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'active',
              reason TEXT NOT NULL,
              starts_at TEXT NOT NULL,
              expires_at TEXT,
              created_by_user_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_moderation_cases_status
              ON moderation_cases(status, priority, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_moderation_cases_target
              ON moderation_cases(target_type, target_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_moderation_actions_case
              ON moderation_actions(case_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_moderation_audit
              ON moderation_audit_events(created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_user_sanctions
              ON user_sanctions(user_id, status, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_posts_status_board
              ON posts(status, board, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_comments_post_status
              ON comments(post_id, status, created_at ASC);
            CREATE INDEX IF NOT EXISTS idx_messages_conversation
              ON messages(conversation_id, created_at ASC);
            """
        )
        connection.commit()


def _ensure_user(connection: Any, user_id: str) -> None:
    _ensure_shadow_user(connection, user_id, user_id, "analyst")


def _active_sanction(connection: Any, user_id: str) -> dict[str, Any] | None:
    row = connection.execute(
        """
        SELECT * FROM user_sanctions
        WHERE user_id = ? AND status = 'active'
          AND (expires_at IS NULL OR expires_at = '' OR expires_at > ?)
        ORDER BY created_at DESC LIMIT 1
        """,
        (user_id, now_iso()),
    ).fetchone()
    return dict(row) if row is not None else None


def _assert_can_publish(connection: Any, user_id: str) -> None:
    sanction = _active_sanction(connection, user_id)
    if sanction is not None and sanction["action"] in {"suspend", "ban"}:
        raise HTTPException(status_code=403, detail="This account cannot publish while an active sanction is in effect")


def _is_blocked(connection: Any, first_user_id: str, second_user_id: str) -> bool:
    row = connection.execute(
        """
        SELECT 1 FROM user_blocks
        WHERE (blocker_user_id = ? AND blocked_user_id = ?)
           OR (blocker_user_id = ? AND blocked_user_id = ?)
        LIMIT 1
        """,
        (first_user_id, second_user_id, second_user_id, first_user_id),
    ).fetchone()
    return row is not None


def _scan_text(value: str) -> dict[str, Any]:
    text = value.strip()
    flags: list[str] = []
    severity = "clear"
    if not text:
        flags.append("empty")
        severity = "block"
    if any(ord(character) < 9 for character in text):
        flags.append("control_characters")
        severity = "block"
    links = len(re.findall(r"https?://|www\.", text, re.IGNORECASE))
    if links > 4:
        flags.append("excessive_links")
        severity = "review" if severity != "block" else severity
    if re.search(r"(.)\1{14,}", text):
        flags.append("repeated_characters")
        severity = "review" if severity != "block" else severity
    letters = [character for character in text if character.isalpha()]
    if len(letters) >= 40:
        uppercase_ratio = sum(1 for character in letters if character.isupper()) / len(letters)
        if uppercase_ratio > 0.85:
            flags.append("excessive_caps")
            severity = "review" if severity != "block" else severity
    blocked_terms = [
        item.strip().lower()
        for item in os.getenv("SPORTS_TERMINAL_BLOCKED_TERMS", "").split(",")
        if item.strip()
    ]
    lowered = text.lower()
    if any(term in lowered for term in blocked_terms):
        flags.append("configured_blocked_term")
        severity = "block"
    return {"severity": severity, "flags": flags, "links": links}


def _target_author(connection: Any, target_type: str, target_id: str) -> str:
    if target_type == "post":
        row = connection.execute("SELECT author_user_id FROM posts WHERE id = ?", (target_id,)).fetchone()
    elif target_type == "comment":
        row = connection.execute("SELECT author_user_id FROM comments WHERE id = ?", (target_id,)).fetchone()
    elif target_type == "message":
        row = connection.execute("SELECT sender_user_id AS author_user_id FROM messages WHERE id = ?", (target_id,)).fetchone()
    else:
        row = None
    return str(row["author_user_id"]) if row is not None else ""


def _audit(connection: Any, actor_user_id: str, event_type: str, target_type: str, target_id: str, payload: dict[str, Any]) -> None:
    connection.execute(
        "INSERT INTO moderation_audit_events (id, actor_user_id, event_type, target_type, target_id, payload_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
        (make_id("audit"), actor_user_id, event_type, target_type, target_id, encode_json(payload), now_iso()),
    )


def _serialize_post(connection: Any, row: Any, viewer_user_id: str = "") -> dict[str, Any]:
    reaction_count = connection.execute(
        "SELECT COUNT(*) AS count FROM reactions WHERE target_type = 'post' AND target_id = ? AND kind = 'like'",
        (row["id"],),
    ).fetchone()["count"]
    comment_count = connection.execute(
        "SELECT COUNT(*) AS count FROM comments WHERE post_id = ? AND status = 'published'",
        (row["id"],),
    ).fetchone()["count"]
    liked = False
    if viewer_user_id:
        liked = connection.execute(
            "SELECT 1 FROM reactions WHERE user_id = ? AND target_type = 'post' AND target_id = ? AND kind = 'like'",
            (viewer_user_id, row["id"]),
        ).fetchone() is not None
    return {
        "id": row["id"],
        "author_user_id": row["author_user_id"],
        "board": row["board"],
        "title": row["title"],
        "body": row["body"],
        "entity_type": row["entity_type"] or "",
        "entity_id": row["entity_id"] or "",
        "status": row["status"],
        "like_count": reaction_count,
        "comment_count": comment_count,
        "liked_by_viewer": liked,
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def create_community_post(payload: CommunityPostCreate) -> dict[str, Any]:
    init_trust_safety_db()
    board = payload.board.strip()
    if board not in _ALLOWED_BOARDS:
        raise HTTPException(status_code=422, detail="Unsupported community board")
    title = payload.title.strip()[:220]
    body = payload.body.strip()[:20_000]
    scan = _scan_text(f"{title}\n{body}")
    if scan["severity"] == "block":
        raise HTTPException(status_code=422, detail={"message": "Content did not pass automated submission checks", "scan": scan})
    post_id = make_id("post")
    timestamp = now_iso()
    status = "pending_review" if scan["severity"] == "review" else "published"
    with connect() as connection:
        _ensure_user(connection, payload.actor_user_id)
        _assert_can_publish(connection, payload.actor_user_id)
        connection.execute(
            "INSERT INTO posts (id, author_user_id, board, title, body, entity_type, entity_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (post_id, payload.actor_user_id, board, title, body, payload.entity_type or None, payload.entity_id or None, status, timestamp, timestamp),
        )
        _audit(connection, payload.actor_user_id, "community_post_created", "post", post_id, {"scan": scan, "status": status})
        connection.commit()
        row = connection.execute("SELECT * FROM posts WHERE id = ?", (post_id,)).fetchone()
        assert row is not None
        return _serialize_post(connection, row, payload.actor_user_id)


def list_community_posts(
    viewer_user_id: str = "",
    board: str = "",
    entity_type: str = "",
    entity_id: str = "",
    limit: int = 100,
) -> list[dict[str, Any]]:
    init_trust_safety_db()
    clauses = ["p.status = 'published'"]
    values: list[Any] = []
    if board:
        clauses.append("p.board = ?")
        values.append(board)
    if entity_type:
        clauses.append("p.entity_type = ?")
        values.append(entity_type)
    if entity_id:
        clauses.append("p.entity_id = ?")
        values.append(entity_id)
    if viewer_user_id:
        clauses.append("NOT EXISTS (SELECT 1 FROM user_blocks b WHERE (b.blocker_user_id = ? AND b.blocked_user_id = p.author_user_id) OR (b.blocker_user_id = p.author_user_id AND b.blocked_user_id = ?))")
        values.extend([viewer_user_id, viewer_user_id])
        clauses.append("NOT EXISTS (SELECT 1 FROM user_mutes m WHERE m.user_id = ? AND m.muted_user_id = p.author_user_id)")
        values.append(viewer_user_id)
    values.append(max(1, min(limit, 500)))
    with connect() as connection:
        rows = connection.execute(
            f"SELECT p.* FROM posts p WHERE {' AND '.join(clauses)} ORDER BY p.created_at DESC LIMIT ?",
            values,
        ).fetchall()
        return [_serialize_post(connection, row, viewer_user_id) for row in rows]


def create_report(payload: ReportCreate) -> dict[str, Any]:
    init_trust_safety_db()
    timestamp = now_iso()
    case_id = make_id("mod_case")
    with connect() as connection:
        _ensure_user(connection, payload.actor_user_id)
        target_user_id = _target_author(connection, payload.target_type, payload.target_id)
        connection.execute(
            "INSERT INTO moderation_cases (id, reporter_user_id, target_type, target_id, target_user_id, reason, details, priority, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'open', ?, ?)",
            (case_id, payload.actor_user_id, payload.target_type, payload.target_id, target_user_id or None, payload.reason[:160], payload.details[:4000], payload.priority[:40], timestamp, timestamp),
        )
        _audit(connection, payload.actor_user_id, "content_reported", payload.target_type, payload.target_id, {"case_id": case_id, "reason": payload.reason})
        connection.commit()
    return {"id": case_id, "reporter_user_id": payload.actor_user_id, "target_type": payload.target_type, "target_id": payload.target_id, "target_user_id": target_user_id, "reason": payload.reason, "details": payload.details, "priority": payload.priority, "status": "open", "created_at": timestamp, "updated_at": timestamp}


def list_moderation_queue(status: str = "open", limit: int = 250) -> list[dict[str, Any]]:
    init_trust_safety_db()
    with connect() as connection:
        rows = connection.execute(
            "SELECT * FROM moderation_cases WHERE (? = '' OR status = ?) ORDER BY CASE priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 ELSE 2 END, created_at ASC LIMIT ?",
            (status, status, max(1, min(limit, 1000))),
        ).fetchall()
        return [dict(row) for row in rows]


def apply_moderation_action(case_id: str, payload: ModerationActionCreate) -> dict[str, Any]:
    init_trust_safety_db()
    action = payload.action.strip().lower()
    if action not in _ALLOWED_ACTIONS:
        raise HTTPException(status_code=422, detail="Unsupported moderation action")
    timestamp = now_iso()
    action_id = make_id("mod_action")
    with connect() as connection:
        _ensure_user(connection, payload.actor_user_id)
        case = connection.execute("SELECT * FROM moderation_cases WHERE id = ?", (case_id,)).fetchone()
        if case is None:
            raise HTTPException(status_code=404, detail="Moderation case not found")
        target_type = str(case["target_type"])
        target_id = str(case["target_id"])
        target_user_id = str(case["target_user_id"] or "")
        if target_type in {"post", "comment", "message"}:
            table = {"post": "posts", "comment": "comments", "message": "messages"}[target_type]
            status_value = {
                "approve": "published" if target_type != "message" else "sent",
                "restore": "published" if target_type != "message" else "sent",
                "hide": "hidden",
                "remove": "removed",
                "close": "removed",
            }.get(action)
            if status_value:
                connection.execute(f"UPDATE {table} SET status = ? WHERE id = ?", (status_value, target_id))
        if action in {"warn", "suspend", "ban"} and target_user_id:
            connection.execute(
                "INSERT INTO user_sanctions (id, user_id, action, status, reason, starts_at, expires_at, created_by_user_id, created_at, updated_at) VALUES (?, ?, ?, 'active', ?, ?, ?, ?, ?, ?)",
                (make_id("sanction"), target_user_id, action, payload.reason[:2000], timestamp, payload.expires_at or None, payload.actor_user_id, timestamp, timestamp),
            )
        case_status = "resolved" if action not in {"hide"} else "monitoring"
        connection.execute(
            "UPDATE moderation_cases SET status = ?, assigned_user_id = ?, resolution = ?, updated_at = ? WHERE id = ?",
            (case_status, payload.actor_user_id, (payload.resolution or payload.reason)[:4000], timestamp, case_id),
        )
        connection.execute(
            "INSERT INTO moderation_actions (id, case_id, actor_user_id, action, target_type, target_id, reason, expires_at, payload_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (action_id, case_id, payload.actor_user_id, action, target_type, target_id, payload.reason[:2000], payload.expires_at or None, encode_json(payload.payload), timestamp),
        )
        _audit(connection, payload.actor_user_id, "moderation_action", target_type, target_id, {"case_id": case_id, "action": action, "reason": payload.reason})
        connection.commit()
    return {"id": action_id, "case_id": case_id, "actor_user_id": payload.actor_user_id, "action": action, "target_type": target_type, "target_id": target_id, "reason": payload.reason, "status": case_status, "created_at": timestamp}


@router.on_event("startup")
def startup_trust_safety_api() -> None:
    init_trust_safety_db()


@router.post("/community/posts")
def create_post(payload: CommunityPostCreate) -> dict[str, Any]:
    return create_community_post(payload)


@router.get("/community/posts")
def list_posts(
    viewer_user_id: str = "",
    board: str = "",
    entity_type: str = "",
    entity_id: str = "",
    limit: int = Query(default=100, ge=1, le=500),
) -> list[dict[str, Any]]:
    return list_community_posts(viewer_user_id, board, entity_type, entity_id, limit)


@router.post("/community/posts/{post_id}/comments")
def create_comment(post_id: str, payload: CommunityCommentCreate) -> dict[str, Any]:
    init_trust_safety_db()
    body = payload.body.strip()[:10_000]
    scan = _scan_text(body)
    if scan["severity"] == "block":
        raise HTTPException(status_code=422, detail={"message": "Comment did not pass automated submission checks", "scan": scan})
    timestamp = now_iso()
    comment_id = make_id("comment")
    status = "pending_review" if scan["severity"] == "review" else "published"
    with connect() as connection:
        _ensure_user(connection, payload.actor_user_id)
        _assert_can_publish(connection, payload.actor_user_id)
        post = connection.execute("SELECT author_user_id, status FROM posts WHERE id = ?", (post_id,)).fetchone()
        if post is None or post["status"] != "published":
            raise HTTPException(status_code=404, detail="Published post not found")
        if _is_blocked(connection, payload.actor_user_id, str(post["author_user_id"])):
            raise HTTPException(status_code=403, detail="A block relationship prevents this reply")
        connection.execute(
            "INSERT INTO comments (id, post_id, author_user_id, body, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (comment_id, post_id, payload.actor_user_id, body, status, timestamp, timestamp),
        )
        _audit(connection, payload.actor_user_id, "community_comment_created", "comment", comment_id, {"post_id": post_id, "scan": scan})
        connection.commit()
    return {"id": comment_id, "post_id": post_id, "author_user_id": payload.actor_user_id, "body": body, "status": status, "created_at": timestamp, "updated_at": timestamp}


@router.get("/community/posts/{post_id}/comments")
def list_comments(post_id: str, viewer_user_id: str = "") -> list[dict[str, Any]]:
    init_trust_safety_db()
    clauses = ["c.post_id = ?", "c.status = 'published'"]
    values: list[Any] = [post_id]
    if viewer_user_id:
        clauses.append("NOT EXISTS (SELECT 1 FROM user_blocks b WHERE (b.blocker_user_id = ? AND b.blocked_user_id = c.author_user_id) OR (b.blocker_user_id = c.author_user_id AND b.blocked_user_id = ?))")
        values.extend([viewer_user_id, viewer_user_id])
        clauses.append("NOT EXISTS (SELECT 1 FROM user_mutes m WHERE m.user_id = ? AND m.muted_user_id = c.author_user_id)")
        values.append(viewer_user_id)
    with connect() as connection:
        rows = connection.execute(f"SELECT c.* FROM comments c WHERE {' AND '.join(clauses)} ORDER BY c.created_at ASC LIMIT 1000", values).fetchall()
        return [dict(row) for row in rows]


@router.put("/community/posts/{post_id}/reaction")
def toggle_reaction(post_id: str, payload: ReactionToggle) -> dict[str, Any]:
    init_trust_safety_db()
    with connect() as connection:
        _ensure_user(connection, payload.actor_user_id)
        existing = connection.execute("SELECT 1 FROM reactions WHERE user_id = ? AND target_type = 'post' AND target_id = ? AND kind = ?", (payload.actor_user_id, post_id, payload.kind)).fetchone()
        active = existing is None
        if active:
            connection.execute("INSERT INTO reactions (user_id, target_type, target_id, kind, created_at) VALUES (?, 'post', ?, ?, ?)", (payload.actor_user_id, post_id, payload.kind, now_iso()))
        else:
            connection.execute("DELETE FROM reactions WHERE user_id = ? AND target_type = 'post' AND target_id = ? AND kind = ?", (payload.actor_user_id, post_id, payload.kind))
        connection.commit()
        count = connection.execute("SELECT COUNT(*) AS count FROM reactions WHERE target_type = 'post' AND target_id = ? AND kind = ?", (post_id, payload.kind)).fetchone()["count"]
        return {"active": active, "kind": payload.kind, "count": count}


@router.post("/reports")
def report_content(payload: ReportCreate) -> dict[str, Any]:
    return create_report(payload)


@router.put("/blocks")
def block_user(payload: RelationshipUpdate) -> dict[str, Any]:
    init_trust_safety_db()
    if payload.actor_user_id == payload.target_user_id:
        raise HTTPException(status_code=422, detail="A user cannot block themselves")
    timestamp = now_iso()
    with connect() as connection:
        _ensure_user(connection, payload.actor_user_id)
        _ensure_user(connection, payload.target_user_id)
        connection.execute("INSERT INTO user_blocks (blocker_user_id, blocked_user_id, reason, created_at) VALUES (?, ?, ?, ?) ON CONFLICT(blocker_user_id, blocked_user_id) DO UPDATE SET reason = excluded.reason", (payload.actor_user_id, payload.target_user_id, payload.reason[:1000], timestamp))
        connection.execute("DELETE FROM user_mutes WHERE user_id = ? AND muted_user_id = ?", (payload.actor_user_id, payload.target_user_id))
        _audit(connection, payload.actor_user_id, "user_blocked", "user", payload.target_user_id, {"reason": payload.reason})
        connection.commit()
    return {"blocker_user_id": payload.actor_user_id, "blocked_user_id": payload.target_user_id, "reason": payload.reason, "created_at": timestamp}


@router.delete("/blocks")
def unblock_user(actor_user_id: str, target_user_id: str) -> dict[str, Any]:
    init_trust_safety_db()
    with connect() as connection:
        connection.execute("DELETE FROM user_blocks WHERE blocker_user_id = ? AND blocked_user_id = ?", (actor_user_id, target_user_id))
        _audit(connection, actor_user_id, "user_unblocked", "user", target_user_id, {})
        connection.commit()
    return {"removed": True}


@router.put("/mutes")
def mute_user(payload: RelationshipUpdate) -> dict[str, Any]:
    init_trust_safety_db()
    if payload.actor_user_id == payload.target_user_id:
        raise HTTPException(status_code=422, detail="A user cannot mute themselves")
    timestamp = now_iso()
    with connect() as connection:
        _ensure_user(connection, payload.actor_user_id)
        _ensure_user(connection, payload.target_user_id)
        connection.execute("INSERT INTO user_mutes (user_id, muted_user_id, reason, created_at) VALUES (?, ?, ?, ?) ON CONFLICT(user_id, muted_user_id) DO UPDATE SET reason = excluded.reason", (payload.actor_user_id, payload.target_user_id, payload.reason[:1000], timestamp))
        _audit(connection, payload.actor_user_id, "user_muted", "user", payload.target_user_id, {"reason": payload.reason})
        connection.commit()
    return {"user_id": payload.actor_user_id, "muted_user_id": payload.target_user_id, "reason": payload.reason, "created_at": timestamp}


@router.delete("/mutes")
def unmute_user(actor_user_id: str, target_user_id: str) -> dict[str, Any]:
    init_trust_safety_db()
    with connect() as connection:
        connection.execute("DELETE FROM user_mutes WHERE user_id = ? AND muted_user_id = ?", (actor_user_id, target_user_id))
        _audit(connection, actor_user_id, "user_unmuted", "user", target_user_id, {})
        connection.commit()
    return {"removed": True}


@router.get("/relationships/{user_id}")
def list_relationships(user_id: str) -> dict[str, Any]:
    init_trust_safety_db()
    with connect() as connection:
        blocks = connection.execute("SELECT * FROM user_blocks WHERE blocker_user_id = ? ORDER BY created_at DESC", (user_id,)).fetchall()
        mutes = connection.execute("SELECT * FROM user_mutes WHERE user_id = ? ORDER BY created_at DESC", (user_id,)).fetchall()
        sanctions = connection.execute("SELECT * FROM user_sanctions WHERE user_id = ? ORDER BY created_at DESC LIMIT 100", (user_id,)).fetchall()
        return {"blocks": [dict(row) for row in blocks], "mutes": [dict(row) for row in mutes], "sanctions": [dict(row) for row in sanctions]}


@router.get("/moderation/queue")
def moderation_queue(status: str = "open", limit: int = Query(default=250, ge=1, le=1000)) -> list[dict[str, Any]]:
    return list_moderation_queue(status, limit)


@router.post("/moderation/cases/{case_id}/actions")
def moderation_action(case_id: str, payload: ModerationActionCreate) -> dict[str, Any]:
    return apply_moderation_action(case_id, payload)


@router.get("/moderation/audit")
def moderation_audit(limit: int = Query(default=250, ge=1, le=1000)) -> list[dict[str, Any]]:
    init_trust_safety_db()
    with connect() as connection:
        rows = connection.execute("SELECT * FROM moderation_audit_events ORDER BY created_at DESC LIMIT ?", (limit,)).fetchall()
        return [{**dict(row), "payload": decode_json(row["payload_json"], {})} for row in rows]


@router.post("/messages/conversations")
def create_conversation(payload: ConversationCreate) -> dict[str, Any]:
    init_trust_safety_db()
    members = list(dict.fromkeys([payload.actor_user_id, *payload.member_user_ids]))
    if len(members) < 2:
        raise HTTPException(status_code=422, detail="A conversation requires at least two distinct members")
    timestamp = now_iso()
    conversation_id = make_id("conversation")
    with connect() as connection:
        for member in members:
            _ensure_user(connection, member)
        for index, first in enumerate(members):
            for second in members[index + 1 :]:
                if _is_blocked(connection, first, second):
                    raise HTTPException(status_code=403, detail="A block relationship prevents this conversation")
        connection.execute("INSERT INTO conversations (id, title, created_at, updated_at) VALUES (?, ?, ?, ?)", (conversation_id, payload.title.strip()[:200] or "Direct message", timestamp, timestamp))
        for member in members:
            connection.execute("INSERT INTO conversation_members (conversation_id, user_id, muted, created_at) VALUES (?, ?, 0, ?)", (conversation_id, member, timestamp))
        _audit(connection, payload.actor_user_id, "conversation_created", "conversation", conversation_id, {"members": members})
        connection.commit()
    return {"id": conversation_id, "title": payload.title, "member_user_ids": members, "created_at": timestamp, "updated_at": timestamp}


@router.get("/messages/conversations")
def list_conversations(user_id: str) -> list[dict[str, Any]]:
    init_trust_safety_db()
    with connect() as connection:
        rows = connection.execute(
            """
            SELECT c.*, cm.muted, cm.last_read_at,
              (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id AND m.status = 'sent') AS message_count,
              (SELECT MAX(created_at) FROM messages m WHERE m.conversation_id = c.id AND m.status = 'sent') AS last_message_at
            FROM conversations c
            JOIN conversation_members cm ON cm.conversation_id = c.id
            WHERE cm.user_id = ?
            ORDER BY COALESCE(last_message_at, c.updated_at) DESC
            """,
            (user_id,),
        ).fetchall()
        return [dict(row) for row in rows]


@router.post("/messages/conversations/{conversation_id}")
def send_message(conversation_id: str, payload: MessageCreate) -> dict[str, Any]:
    init_trust_safety_db()
    body = payload.body.strip()[:20_000]
    scan = _scan_text(body)
    if scan["severity"] == "block":
        raise HTTPException(status_code=422, detail={"message": "Message did not pass automated submission checks", "scan": scan})
    timestamp = now_iso()
    message_id = make_id("message")
    status = "pending_review" if scan["severity"] == "review" else "sent"
    with connect() as connection:
        _ensure_user(connection, payload.actor_user_id)
        _assert_can_publish(connection, payload.actor_user_id)
        membership = connection.execute("SELECT 1 FROM conversation_members WHERE conversation_id = ? AND user_id = ?", (conversation_id, payload.actor_user_id)).fetchone()
        if membership is None:
            raise HTTPException(status_code=403, detail="User is not a member of this conversation")
        recipients = connection.execute("SELECT user_id FROM conversation_members WHERE conversation_id = ? AND user_id != ?", (conversation_id, payload.actor_user_id)).fetchall()
        for recipient in recipients:
            if _is_blocked(connection, payload.actor_user_id, str(recipient["user_id"])):
                raise HTTPException(status_code=403, detail="A block relationship prevents this message")
        connection.execute("INSERT INTO messages (id, conversation_id, sender_user_id, body, status, created_at) VALUES (?, ?, ?, ?, ?, ?)", (message_id, conversation_id, payload.actor_user_id, body, status, timestamp))
        connection.execute("UPDATE conversations SET updated_at = ? WHERE id = ?", (timestamp, conversation_id))
        _audit(connection, payload.actor_user_id, "message_sent", "message", message_id, {"conversation_id": conversation_id, "scan": scan})
        connection.commit()
    return {"id": message_id, "conversation_id": conversation_id, "sender_user_id": payload.actor_user_id, "body": body, "status": status, "created_at": timestamp}


@router.get("/messages/conversations/{conversation_id}")
def list_messages(conversation_id: str, user_id: str) -> list[dict[str, Any]]:
    init_trust_safety_db()
    with connect() as connection:
        membership = connection.execute("SELECT 1 FROM conversation_members WHERE conversation_id = ? AND user_id = ?", (conversation_id, user_id)).fetchone()
        if membership is None:
            raise HTTPException(status_code=403, detail="User is not a member of this conversation")
        rows = connection.execute("SELECT * FROM messages WHERE conversation_id = ? AND status = 'sent' ORDER BY created_at ASC LIMIT 2000", (conversation_id,)).fetchall()
        visible = [dict(row) for row in rows if not _is_blocked(connection, user_id, str(row["sender_user_id"]))]
        connection.execute("UPDATE conversation_members SET last_read_at = ? WHERE conversation_id = ? AND user_id = ?", (now_iso(), conversation_id, user_id))
        connection.commit()
        return visible
