from __future__ import annotations

import math
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from .launch_api import _ensure_shadow_user
from .main import connect, decode_json, encode_json, init_db, make_id, now_iso
from .trust_safety_api import (
    _assert_can_publish,
    _audit,
    _is_blocked,
    _scan_text,
    init_trust_safety_db,
)

router = APIRouter(prefix="/v2/community", tags=["community-network"])


class CommunityFollowUpdate(BaseModel):
    actor_user_id: str
    followed: bool = True


class CommunitySaveUpdate(BaseModel):
    actor_user_id: str
    saved: bool = True


class CommunityVoteUpdate(BaseModel):
    actor_user_id: str
    direction: int = Field(ge=-1, le=1)


class CommunityThreadCreate(BaseModel):
    actor_user_id: str
    community_slug: str
    title: str
    body: str
    flair: str = "Discussion"
    entity_type: str = ""
    entity_id: str = ""


class CommunityReplyCreate(BaseModel):
    actor_user_id: str
    body: str
    parent_comment_id: str = ""


GENERAL_COMMUNITIES: tuple[tuple[str, str, str, str], ...] = (
    ("nba", "NBA", "League-wide discussion, analysis, news and games.", "League"),
    ("nba-stats", "NBA Stats & Analytics", "Metrics, models, research, historical comparisons and data questions.", "Analysis"),
    ("nba-trades", "NBA Trades", "Trade ideas, transaction analysis, CBA mechanics and front-office debate.", "Transactions"),
    ("nba-draft", "NBA Draft", "Prospects, scouting, draft history, picks and team-building strategy.", "Draft"),
    ("nba-history", "NBA History", "Historical seasons, players, teams, awards, records and eras.", "History"),
    ("fantasy-basketball", "Fantasy Basketball", "Fantasy strategy, player value, leagues and roster decisions.", "Fantasy"),
)

NBA_TEAMS: tuple[tuple[str, str], ...] = (
    ("ATL", "Atlanta Hawks"), ("BOS", "Boston Celtics"), ("BKN", "Brooklyn Nets"),
    ("CHA", "Charlotte Hornets"), ("CHI", "Chicago Bulls"), ("CLE", "Cleveland Cavaliers"),
    ("DAL", "Dallas Mavericks"), ("DEN", "Denver Nuggets"), ("DET", "Detroit Pistons"),
    ("GSW", "Golden State Warriors"), ("HOU", "Houston Rockets"), ("IND", "Indiana Pacers"),
    ("LAC", "LA Clippers"), ("LAL", "Los Angeles Lakers"), ("MEM", "Memphis Grizzlies"),
    ("MIA", "Miami Heat"), ("MIL", "Milwaukee Bucks"), ("MIN", "Minnesota Timberwolves"),
    ("NOP", "New Orleans Pelicans"), ("NYK", "New York Knicks"), ("OKC", "Oklahoma City Thunder"),
    ("ORL", "Orlando Magic"), ("PHI", "Philadelphia 76ers"), ("PHX", "Phoenix Suns"),
    ("POR", "Portland Trail Blazers"), ("SAC", "Sacramento Kings"), ("SAS", "San Antonio Spurs"),
    ("TOR", "Toronto Raptors"), ("UTA", "Utah Jazz"), ("WAS", "Washington Wizards"),
)

DEFAULT_RULES = [
    "Discuss the community topic in good faith and keep titles descriptive.",
    "No harassment, hate, threats, doxxing, impersonation or targeted abuse.",
    "Do not manipulate votes, spam, brigade, evade moderation or coordinate deceptive activity.",
    "Label rumors, satire and speculation clearly; do not present fabricated sourcing as fact.",
    "Respect intellectual-property, privacy and Sports Terminal platform rules.",
]


def init_community_db() -> None:
    init_db()
    init_trust_safety_db()
    with connect() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS community_boards (
              slug TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT NOT NULL,
              category TEXT NOT NULL,
              sport TEXT NOT NULL DEFAULT 'NBA',
              team_abbreviation TEXT,
              rules_json TEXT NOT NULL DEFAULT '[]',
              status TEXT NOT NULL DEFAULT 'active',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS community_memberships (
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              community_slug TEXT NOT NULL REFERENCES community_boards(slug) ON DELETE CASCADE,
              role TEXT NOT NULL DEFAULT 'member',
              flair TEXT NOT NULL DEFAULT '',
              joined_at TEXT NOT NULL,
              PRIMARY KEY(user_id, community_slug)
            );
            CREATE TABLE IF NOT EXISTS community_saved_posts (
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
              saved_at TEXT NOT NULL,
              PRIMARY KEY(user_id, post_id)
            );
            CREATE TABLE IF NOT EXISTS community_comment_edges (
              comment_id TEXT PRIMARY KEY REFERENCES comments(id) ON DELETE CASCADE,
              parent_comment_id TEXT REFERENCES comments(id) ON DELETE CASCADE,
              depth INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS community_post_metadata (
              post_id TEXT PRIMARY KEY REFERENCES posts(id) ON DELETE CASCADE,
              flair TEXT NOT NULL DEFAULT 'Discussion',
              pinned INTEGER NOT NULL DEFAULT 0,
              locked INTEGER NOT NULL DEFAULT 0,
              spoiler INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_community_memberships_board
              ON community_memberships(community_slug, role, joined_at);
            CREATE INDEX IF NOT EXISTS idx_community_saved_user
              ON community_saved_posts(user_id, saved_at DESC);
            CREATE INDEX IF NOT EXISTS idx_community_edges_parent
              ON community_comment_edges(parent_comment_id, depth);
            """
        )
        timestamp = now_iso()
        for slug, name, description, category in GENERAL_COMMUNITIES:
            connection.execute(
                """
                INSERT INTO community_boards(slug,name,description,category,sport,team_abbreviation,rules_json,status,created_at,updated_at)
                VALUES (?,?,?,?, 'NBA', NULL, ?, 'active', ?, ?)
                ON CONFLICT(slug) DO UPDATE SET name=excluded.name,description=excluded.description,
                  category=excluded.category,rules_json=excluded.rules_json,updated_at=excluded.updated_at
                """,
                (slug, name, description, category, encode_json(DEFAULT_RULES), timestamp, timestamp),
            )
        for abbreviation, name in NBA_TEAMS:
            slug = f"team-{abbreviation.lower()}"
            connection.execute(
                """
                INSERT INTO community_boards(slug,name,description,category,sport,team_abbreviation,rules_json,status,created_at,updated_at)
                VALUES (?,?,?,'Team','NBA',?,?, 'active', ?, ?)
                ON CONFLICT(slug) DO UPDATE SET name=excluded.name,description=excluded.description,
                  team_abbreviation=excluded.team_abbreviation,rules_json=excluded.rules_json,updated_at=excluded.updated_at
                """,
                (
                    slug,
                    f"{name} Community",
                    f"Dedicated {name} discussion, roster analysis, games, transactions and team history.",
                    abbreviation,
                    encode_json(DEFAULT_RULES),
                    timestamp,
                    timestamp,
                ),
            )
        connection.commit()


def _ensure_user(connection: Any, user_id: str) -> None:
    _ensure_shadow_user(connection, user_id, user_id, "analyst")


def _reaction_count(connection: Any, post_id: str, kind: str) -> int:
    row = connection.execute(
        "SELECT COUNT(*) AS count FROM reactions WHERE target_type='post' AND target_id=? AND kind=?",
        (post_id, kind),
    ).fetchone()
    return int(row["count"] if row else 0)


def _comment_count(connection: Any, post_id: str) -> int:
    row = connection.execute(
        "SELECT COUNT(*) AS count FROM comments WHERE post_id=? AND status='published'",
        (post_id,),
    ).fetchone()
    return int(row["count"] if row else 0)


def _viewer_reaction(connection: Any, user_id: str, post_id: str) -> int:
    if not user_id:
        return 0
    row = connection.execute(
        """
        SELECT kind FROM reactions
        WHERE user_id=? AND target_type='post' AND target_id=? AND kind IN ('upvote','downvote')
        ORDER BY CASE kind WHEN 'upvote' THEN 0 ELSE 1 END LIMIT 1
        """,
        (user_id, post_id),
    ).fetchone()
    if row is None:
        return 0
    return 1 if row["kind"] == "upvote" else -1


def _post_payload(connection: Any, row: Any, viewer_user_id: str = "") -> dict[str, Any]:
    post_id = str(row["id"])
    upvotes = _reaction_count(connection, post_id, "upvote") + _reaction_count(connection, post_id, "like")
    downvotes = _reaction_count(connection, post_id, "downvote")
    comments = _comment_count(connection, post_id)
    metadata = connection.execute(
        "SELECT * FROM community_post_metadata WHERE post_id=?",
        (post_id,),
    ).fetchone()
    author = connection.execute(
        "SELECT display_name FROM users WHERE id=?",
        (row["author_user_id"],),
    ).fetchone()
    profile = connection.execute(
        "SELECT handle,avatar_url FROM user_profiles WHERE user_id=?",
        (row["author_user_id"],),
    ).fetchone()
    saved = False
    following = False
    if viewer_user_id:
        saved = connection.execute(
            "SELECT 1 FROM community_saved_posts WHERE user_id=? AND post_id=?",
            (viewer_user_id, post_id),
        ).fetchone() is not None
        following = connection.execute(
            "SELECT 1 FROM community_memberships WHERE user_id=? AND community_slug=?",
            (viewer_user_id, row["board"]),
        ).fetchone() is not None
    created = str(row["created_at"])
    try:
        age_hours = max(
            0.0,
            (datetime.now(timezone.utc) - datetime.fromisoformat(created.replace("Z", "+00:00"))).total_seconds() / 3600,
        )
    except ValueError:
        age_hours = 0.0
    score = upvotes - downvotes
    hot_score = math.log10(max(abs(score), 1)) + score / 50.0 + comments / 25.0 - age_hours / 72.0
    controversial = min(upvotes, downvotes) * 2 + min(upvotes + downvotes, 25) / 25.0
    return {
        "id": post_id,
        "community_slug": row["board"],
        "title": row["title"],
        "body": row["body"],
        "author_user_id": row["author_user_id"],
        "author_display_name": author["display_name"] if author else str(row["author_user_id"]),
        "author_handle": profile["handle"] if profile and profile["handle"] else "",
        "author_avatar_url": profile["avatar_url"] if profile and profile["avatar_url"] else "",
        "entity_type": row["entity_type"] or "",
        "entity_id": row["entity_id"] or "",
        "status": row["status"],
        "flair": metadata["flair"] if metadata else "Discussion",
        "pinned": bool(metadata["pinned"]) if metadata else False,
        "locked": bool(metadata["locked"]) if metadata else False,
        "upvotes": upvotes,
        "downvotes": downvotes,
        "score": score,
        "comment_count": comments,
        "viewer_vote": _viewer_reaction(connection, viewer_user_id, post_id),
        "saved_by_viewer": saved,
        "following_community": following,
        "hot_score": hot_score,
        "controversy_score": controversial,
        "created_at": created,
        "updated_at": row["updated_at"],
    }


def _reputation(connection: Any, user_id: str) -> dict[str, Any]:
    posts = int(connection.execute(
        "SELECT COUNT(*) FROM posts WHERE author_user_id=? AND status='published'", (user_id,)
    ).fetchone()[0])
    comments = int(connection.execute(
        "SELECT COUNT(*) FROM comments WHERE author_user_id=? AND status='published'", (user_id,)
    ).fetchone()[0])
    received_up = int(connection.execute(
        """
        SELECT COUNT(*) FROM reactions r
        JOIN posts p ON p.id=r.target_id
        WHERE r.target_type='post' AND p.author_user_id=? AND r.kind IN ('upvote','like')
        """,
        (user_id,),
    ).fetchone()[0])
    received_down = int(connection.execute(
        """
        SELECT COUNT(*) FROM reactions r
        JOIN posts p ON p.id=r.target_id
        WHERE r.target_type='post' AND p.author_user_id=? AND r.kind='downvote'
        """,
        (user_id,),
    ).fetchone()[0])
    score = max(0, received_up - received_down) + posts * 2 + comments
    badges: list[str] = []
    if posts >= 1:
        badges.append("Contributor")
    if comments >= 10:
        badges.append("Conversation Builder")
    if received_up >= 25:
        badges.append("Quality Contributor")
    if score >= 100:
        badges.append("Trusted Voice")
    if posts >= 50:
        badges.append("Community Veteran")
    return {
        "reputation": score,
        "posts": posts,
        "comments": comments,
        "received_upvotes": received_up,
        "received_downvotes": received_down,
        "badges": badges,
    }


@router.on_event("startup")
def startup_community_api() -> None:
    init_community_db()


@router.get("/boards")
def list_boards(viewer_user_id: str = "", category: str = "") -> list[dict[str, Any]]:
    init_community_db()
    with connect() as connection:
        clauses = ["status='active'"]
        params: list[Any] = []
        if category:
            clauses.append("category=?")
            params.append(category)
        rows = connection.execute(
            f"SELECT * FROM community_boards WHERE {' AND '.join(clauses)} ORDER BY CASE category WHEN 'League' THEN 0 WHEN 'Analysis' THEN 1 WHEN 'Transactions' THEN 2 WHEN 'Draft' THEN 3 WHEN 'History' THEN 4 WHEN 'Fantasy' THEN 5 ELSE 6 END,name",
            params,
        ).fetchall()
        result = []
        for row in rows:
            member_count = int(connection.execute(
                "SELECT COUNT(*) FROM community_memberships WHERE community_slug=?",
                (row["slug"],),
            ).fetchone()[0])
            post_count = int(connection.execute(
                "SELECT COUNT(*) FROM posts WHERE board=? AND status='published'",
                (row["slug"],),
            ).fetchone()[0])
            following = bool(viewer_user_id and connection.execute(
                "SELECT 1 FROM community_memberships WHERE user_id=? AND community_slug=?",
                (viewer_user_id, row["slug"]),
            ).fetchone())
            result.append({
                **dict(row),
                "rules": decode_json(row["rules_json"], []),
                "member_count": member_count,
                "post_count": post_count,
                "following": following,
            })
        return result


@router.put("/boards/{slug}/follow")
def follow_board(slug: str, payload: CommunityFollowUpdate) -> dict[str, Any]:
    init_community_db()
    with connect() as connection:
        _ensure_user(connection, payload.actor_user_id)
        if connection.execute("SELECT 1 FROM community_boards WHERE slug=?", (slug,)).fetchone() is None:
            raise HTTPException(status_code=404, detail="Community not found")
        if payload.followed:
            connection.execute(
                "INSERT OR IGNORE INTO community_memberships(user_id,community_slug,role,flair,joined_at) VALUES (?,?,'member','',?)",
                (payload.actor_user_id, slug, now_iso()),
            )
        else:
            connection.execute(
                "DELETE FROM community_memberships WHERE user_id=? AND community_slug=? AND role='member'",
                (payload.actor_user_id, slug),
            )
        connection.commit()
    return {"community_slug": slug, "following": payload.followed}


@router.post("/posts")
def create_thread(payload: CommunityThreadCreate) -> dict[str, Any]:
    init_community_db()
    title = payload.title.strip()[:220]
    body = payload.body.strip()[:20_000]
    scan = _scan_text(f"{title}\n{body}")
    if scan["severity"] == "block":
        raise HTTPException(status_code=422, detail={"message": "Thread did not pass submission checks", "scan": scan})
    timestamp = now_iso()
    post_id = make_id("post")
    with connect() as connection:
        _ensure_user(connection, payload.actor_user_id)
        _assert_can_publish(connection, payload.actor_user_id)
        if connection.execute("SELECT 1 FROM community_boards WHERE slug=? AND status='active'", (payload.community_slug,)).fetchone() is None:
            raise HTTPException(status_code=404, detail="Community not found")
        status = "pending_review" if scan["severity"] == "review" else "published"
        connection.execute(
            "INSERT INTO posts(id,author_user_id,board,title,body,entity_type,entity_id,status,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
            (post_id, payload.actor_user_id, payload.community_slug, title, body, payload.entity_type or None, payload.entity_id or None, status, timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO community_post_metadata(post_id,flair,pinned,locked,spoiler,created_at,updated_at) VALUES (?,?,0,0,0,?,?)",
            (post_id, payload.flair.strip()[:80] or "Discussion", timestamp, timestamp),
        )
        _audit(connection, payload.actor_user_id, "community_thread_created_v2", "post", post_id, {"community": payload.community_slug, "scan": scan})
        connection.commit()
        row = connection.execute("SELECT * FROM posts WHERE id=?", (post_id,)).fetchone()
        assert row is not None
        return _post_payload(connection, row, payload.actor_user_id)


@router.get("/feed")
def community_feed(
    viewer_user_id: str = "",
    community_slug: str = "",
    sort: str = "hot",
    followed_only: bool = False,
    saved_only: bool = False,
    limit: int = Query(default=100, ge=1, le=500),
) -> dict[str, Any]:
    init_community_db()
    sort_key = sort.strip().lower()
    if sort_key not in {"hot", "new", "top", "controversial"}:
        raise HTTPException(status_code=422, detail="Sort must be hot, new, top, or controversial")
    with connect() as connection:
        clauses = ["p.status='published'"]
        params: list[Any] = []
        if community_slug:
            clauses.append("p.board=?")
            params.append(community_slug)
        if viewer_user_id:
            clauses.append("NOT EXISTS (SELECT 1 FROM user_blocks b WHERE (b.blocker_user_id=? AND b.blocked_user_id=p.author_user_id) OR (b.blocker_user_id=p.author_user_id AND b.blocked_user_id=?))")
            params.extend([viewer_user_id, viewer_user_id])
            clauses.append("NOT EXISTS (SELECT 1 FROM user_mutes m WHERE m.user_id=? AND m.muted_user_id=p.author_user_id)")
            params.append(viewer_user_id)
        if followed_only:
            clauses.append("EXISTS (SELECT 1 FROM community_memberships cm WHERE cm.user_id=? AND cm.community_slug=p.board)")
            params.append(viewer_user_id)
        if saved_only:
            clauses.append("EXISTS (SELECT 1 FROM community_saved_posts sp WHERE sp.user_id=? AND sp.post_id=p.id)")
            params.append(viewer_user_id)
        # Fetch a bounded candidate pool before ranking. Hot/controversial are calculated
        # from vote/comment state in Python to keep the formula explicit and testable.
        candidate_limit = min(max(limit * 5, 250), 2000)
        params.append(candidate_limit)
        rows = connection.execute(
            f"SELECT p.* FROM posts p WHERE {' AND '.join(clauses)} ORDER BY p.created_at DESC LIMIT ?",
            params,
        ).fetchall()
        posts = [_post_payload(connection, row, viewer_user_id) for row in rows]
    if sort_key == "new":
        posts.sort(key=lambda item: str(item["created_at"]), reverse=True)
    elif sort_key == "top":
        posts.sort(key=lambda item: (int(item["score"]), int(item["comment_count"]), str(item["created_at"])), reverse=True)
    elif sort_key == "controversial":
        posts.sort(key=lambda item: (float(item["controversy_score"]), int(item["comment_count"])), reverse=True)
    else:
        posts.sort(key=lambda item: (bool(item["pinned"]), float(item["hot_score"])), reverse=True)
    return {"sort": sort_key, "community_slug": community_slug or None, "rows": posts[:limit]}


@router.put("/posts/{post_id}/vote")
def vote_post(post_id: str, payload: CommunityVoteUpdate) -> dict[str, Any]:
    init_community_db()
    with connect() as connection:
        _ensure_user(connection, payload.actor_user_id)
        row = connection.execute("SELECT * FROM posts WHERE id=? AND status='published'", (post_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Published thread not found")
        if str(row["author_user_id"]) == payload.actor_user_id and payload.direction < 0:
            raise HTTPException(status_code=422, detail="A user cannot downvote their own thread")
        connection.execute(
            "DELETE FROM reactions WHERE user_id=? AND target_type='post' AND target_id=? AND kind IN ('upvote','downvote')",
            (payload.actor_user_id, post_id),
        )
        if payload.direction != 0:
            connection.execute(
                "INSERT INTO reactions(user_id,target_type,target_id,kind,created_at) VALUES (?,'post',?,?,?)",
                (payload.actor_user_id, post_id, "upvote" if payload.direction > 0 else "downvote", now_iso()),
            )
        connection.commit()
        refreshed = connection.execute("SELECT * FROM posts WHERE id=?", (post_id,)).fetchone()
        assert refreshed is not None
        return _post_payload(connection, refreshed, payload.actor_user_id)


@router.put("/posts/{post_id}/save")
def save_post(post_id: str, payload: CommunitySaveUpdate) -> dict[str, Any]:
    init_community_db()
    with connect() as connection:
        _ensure_user(connection, payload.actor_user_id)
        if connection.execute("SELECT 1 FROM posts WHERE id=?", (post_id,)).fetchone() is None:
            raise HTTPException(status_code=404, detail="Thread not found")
        if payload.saved:
            connection.execute(
                "INSERT OR REPLACE INTO community_saved_posts(user_id,post_id,saved_at) VALUES (?,?,?)",
                (payload.actor_user_id, post_id, now_iso()),
            )
        else:
            connection.execute(
                "DELETE FROM community_saved_posts WHERE user_id=? AND post_id=?",
                (payload.actor_user_id, post_id),
            )
        connection.commit()
    return {"post_id": post_id, "saved": payload.saved}


@router.post("/posts/{post_id}/comments")
def create_threaded_comment(post_id: str, payload: CommunityReplyCreate) -> dict[str, Any]:
    init_community_db()
    body = payload.body.strip()[:10_000]
    scan = _scan_text(body)
    if scan["severity"] == "block":
        raise HTTPException(status_code=422, detail={"message": "Comment did not pass submission checks", "scan": scan})
    timestamp = now_iso()
    comment_id = make_id("comment")
    with connect() as connection:
        _ensure_user(connection, payload.actor_user_id)
        _assert_can_publish(connection, payload.actor_user_id)
        post = connection.execute("SELECT * FROM posts WHERE id=? AND status='published'", (post_id,)).fetchone()
        if post is None:
            raise HTTPException(status_code=404, detail="Published thread not found")
        if _is_blocked(connection, payload.actor_user_id, str(post["author_user_id"])):
            raise HTTPException(status_code=403, detail="A block relationship prevents this reply")
        parent_depth = -1
        if payload.parent_comment_id:
            parent = connection.execute(
                "SELECT c.id,e.depth FROM comments c LEFT JOIN community_comment_edges e ON e.comment_id=c.id WHERE c.id=? AND c.post_id=? AND c.status='published'",
                (payload.parent_comment_id, post_id),
            ).fetchone()
            if parent is None:
                raise HTTPException(status_code=404, detail="Parent comment not found")
            parent_depth = int(parent["depth"] or 0)
        depth = min(parent_depth + 1, 12)
        status = "pending_review" if scan["severity"] == "review" else "published"
        connection.execute(
            "INSERT INTO comments(id,post_id,author_user_id,body,status,created_at,updated_at) VALUES (?,?,?,?,?,?,?)",
            (comment_id, post_id, payload.actor_user_id, body, status, timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO community_comment_edges(comment_id,parent_comment_id,depth) VALUES (?,?,?)",
            (comment_id, payload.parent_comment_id or None, depth),
        )
        _audit(connection, payload.actor_user_id, "community_threaded_comment_created", "comment", comment_id, {"post_id": post_id, "parent": payload.parent_comment_id, "depth": depth, "scan": scan})
        connection.commit()
    return {"id": comment_id, "post_id": post_id, "author_user_id": payload.actor_user_id, "body": body, "status": status, "parent_comment_id": payload.parent_comment_id or None, "depth": depth, "created_at": timestamp}


@router.get("/posts/{post_id}/comments")
def threaded_comments(post_id: str, viewer_user_id: str = "") -> list[dict[str, Any]]:
    init_community_db()
    with connect() as connection:
        clauses = ["c.post_id=?", "c.status='published'"]
        params: list[Any] = [post_id]
        if viewer_user_id:
            clauses.append("NOT EXISTS (SELECT 1 FROM user_blocks b WHERE (b.blocker_user_id=? AND b.blocked_user_id=c.author_user_id) OR (b.blocker_user_id=c.author_user_id AND b.blocked_user_id=?))")
            params.extend([viewer_user_id, viewer_user_id])
            clauses.append("NOT EXISTS (SELECT 1 FROM user_mutes m WHERE m.user_id=? AND m.muted_user_id=c.author_user_id)")
            params.append(viewer_user_id)
        rows = connection.execute(
            f"""
            SELECT c.*,e.parent_comment_id,COALESCE(e.depth,0) AS depth,u.display_name,
                   p.handle,p.avatar_url
            FROM comments c
            LEFT JOIN community_comment_edges e ON e.comment_id=c.id
            LEFT JOIN users u ON u.id=c.author_user_id
            LEFT JOIN user_profiles p ON p.user_id=c.author_user_id
            WHERE {' AND '.join(clauses)}
            ORDER BY c.created_at ASC LIMIT 2000
            """,
            params,
        ).fetchall()
        return [dict(row) for row in rows]


@router.get("/users/{user_id}")
def community_user_profile(user_id: str) -> dict[str, Any]:
    init_community_db()
    with connect() as connection:
        user = connection.execute(
            """
            SELECT u.id,u.display_name,u.created_at,p.handle,p.bio,p.avatar_url,p.is_public
            FROM users u LEFT JOIN user_profiles p ON p.user_id=u.id WHERE u.id=?
            """,
            (user_id,),
        ).fetchone()
        if user is None:
            raise HTTPException(status_code=404, detail="Community user not found")
        reputation = _reputation(connection, user_id)
        communities = [dict(row) for row in connection.execute(
            """
            SELECT cb.slug,cb.name,cm.role,cm.flair,cm.joined_at
            FROM community_memberships cm JOIN community_boards cb ON cb.slug=cm.community_slug
            WHERE cm.user_id=? ORDER BY cm.joined_at DESC
            """,
            (user_id,),
        ).fetchall()]
        return {"user": dict(user), "reputation": reputation, "communities": communities}
