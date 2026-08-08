from __future__ import annotations

import re
from typing import Any
from urllib.parse import urlparse

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from .community_api import community_user_profile, init_community_db
from .launch_api import _ensure_shadow_user
from .main import connect, decode_json, encode_json, init_db, now_iso

router = APIRouter(prefix="/v2/profile", tags=["profile"])

NBA_TEAMS = {
    "ATL", "BOS", "BKN", "CHA", "CHI", "CLE", "DAL", "DEN", "DET", "GSW",
    "HOU", "IND", "LAC", "LAL", "MEM", "MIA", "MIL", "MIN", "NOP", "NYK",
    "OKC", "ORL", "PHI", "PHX", "POR", "SAC", "SAS", "TOR", "UTA", "WAS",
}
HANDLE_RE = re.compile(r"^[a-z0-9_.-]{3,30}$")


class ProfileUpdate(BaseModel):
    actor_user_id: str
    display_name: str = Field(min_length=1, max_length=80)
    handle: str = Field(min_length=3, max_length=30)
    bio: str = Field(default="", max_length=1200)
    avatar_url: str = Field(default="", max_length=2000)
    is_public: bool = True
    favorite_teams: list[str] = Field(default_factory=list, max_length=30)
    favorite_players: list[str] = Field(default_factory=list, max_length=250)
    email_digest: bool = False
    fantasy_alerts: bool = True
    trade_alerts: bool = True
    editorial_newsletter: bool = True
    notification_preferences: dict[str, Any] = Field(default_factory=dict)


def init_profile_api() -> None:
    init_db()
    init_community_db()


def _validate_handle(handle: str) -> str:
    clean = handle.strip().lower()
    if not HANDLE_RE.fullmatch(clean):
        raise HTTPException(
            status_code=422,
            detail="Handle must be 3–30 lowercase letters, numbers, underscores, periods, or hyphens.",
        )
    return clean


def _validate_avatar(url: str) -> str:
    clean = url.strip()
    if not clean:
        return ""
    parsed = urlparse(clean)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise HTTPException(
            status_code=422,
            detail="Avatar URL must be an absolute HTTP or HTTPS URL.",
        )
    return clean


def _profile_payload(user_id: str, viewer_user_id: str = "") -> dict[str, Any]:
    init_profile_api()
    with connect() as connection:
        row = connection.execute(
            """
            SELECT u.id,u.email,u.display_name,u.role,u.status,u.created_at,u.updated_at,
                   p.handle,p.bio,p.avatar_url,p.is_public,
                   s.dark_mode,s.email_digest,s.fantasy_alerts,s.notification_preferences
            FROM users u
            LEFT JOIN user_profiles p ON p.user_id=u.id
            LEFT JOIN user_settings s ON s.user_id=u.id
            WHERE u.id=?
            """,
            (user_id,),
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Profile not found")
        is_owner = viewer_user_id == user_id
        is_public = bool(row["is_public"] if row["is_public"] is not None else 1)
        if not is_owner and not is_public:
            raise HTTPException(status_code=403, detail="This profile is private")
        teams = [
            str(item["team_id"])
            for item in connection.execute(
                "SELECT team_id FROM favorite_teams WHERE user_id=? ORDER BY team_id",
                (user_id,),
            ).fetchall()
        ]
        players = [
            str(item["player_id"])
            for item in connection.execute(
                "SELECT player_id FROM favorite_players WHERE user_id=? ORDER BY created_at DESC",
                (user_id,),
            ).fetchall()
        ]
        notifications = decode_json(row["notification_preferences"], {})
        if not isinstance(notifications, dict):
            notifications = {}
    community = community_user_profile(user_id)
    reputation = community.get("reputation", {})
    return {
        "user_id": user_id,
        "is_owner": is_owner,
        "email": row["email"] if is_owner else None,
        "display_name": row["display_name"],
        "handle": row["handle"] or "",
        "bio": row["bio"] or "",
        "avatar_url": row["avatar_url"] or "",
        "is_public": is_public,
        "role": row["role"],
        "member_since": row["created_at"],
        "favorite_teams": teams,
        "favorite_players": players if is_owner else players[:50],
        "preferences": {
            "dark_mode": bool(row["dark_mode"] if row["dark_mode"] is not None else 1),
            "email_digest": bool(row["email_digest"] if row["email_digest"] is not None else 0),
            "fantasy_alerts": bool(row["fantasy_alerts"] if row["fantasy_alerts"] is not None else 1),
            "trade_alerts": bool(notifications.get("trade_alerts", True)),
            "editorial_newsletter": bool(notifications.get("editorial_newsletter", True)),
            "notification_preferences": notifications,
        } if is_owner else {},
        "reputation": reputation,
        "communities": community.get("communities", []),
    }


@router.get("/{user_id}")
def get_profile_v2(user_id: str, viewer_user_id: str = "") -> dict[str, Any]:
    return _profile_payload(user_id, viewer_user_id)


@router.put("/{user_id}")
def update_profile_v2(user_id: str, payload: ProfileUpdate) -> dict[str, Any]:
    init_profile_api()
    if payload.actor_user_id != user_id:
        raise HTTPException(status_code=403, detail="Users may edit only their own profile")
    handle = _validate_handle(payload.handle)
    avatar = _validate_avatar(payload.avatar_url)
    teams = sorted({team.strip().upper() for team in payload.favorite_teams if team.strip()})
    invalid_teams = [team for team in teams if team not in NBA_TEAMS]
    if invalid_teams:
        raise HTTPException(
            status_code=422,
            detail=f"Unknown NBA team preference(s): {', '.join(invalid_teams)}",
        )
    players = []
    seen_players: set[str] = set()
    for value in payload.favorite_players:
        player = value.strip()[:160]
        if player and player not in seen_players:
            seen_players.add(player)
            players.append(player)
    timestamp = now_iso()
    with connect() as connection:
        _ensure_shadow_user(connection, user_id, payload.display_name.strip(), "analyst")
        conflict = connection.execute(
            "SELECT user_id FROM user_profiles WHERE handle=? AND user_id<>?",
            (handle, user_id),
        ).fetchone()
        if conflict is not None:
            raise HTTPException(status_code=409, detail="That username is already in use")
        connection.execute(
            "UPDATE users SET display_name=?,updated_at=? WHERE id=?",
            (payload.display_name.strip(), timestamp, user_id),
        )
        connection.execute(
            """
            INSERT INTO user_profiles(user_id,handle,bio,avatar_url,is_public,created_at,updated_at)
            VALUES (?,?,?,?,?,?,?)
            ON CONFLICT(user_id) DO UPDATE SET handle=excluded.handle,bio=excluded.bio,
              avatar_url=excluded.avatar_url,is_public=excluded.is_public,updated_at=excluded.updated_at
            """,
            (user_id, handle, payload.bio.strip(), avatar, int(payload.is_public), timestamp, timestamp),
        )
        existing_settings = connection.execute(
            "SELECT dark_mode,notification_preferences FROM user_settings WHERE user_id=?",
            (user_id,),
        ).fetchone()
        existing_notifications = decode_json(
            existing_settings["notification_preferences"] if existing_settings else "{}",
            {},
        )
        if not isinstance(existing_notifications, dict):
            existing_notifications = {}
        notifications = {
            **existing_notifications,
            **payload.notification_preferences,
            "trade_alerts": payload.trade_alerts,
            "editorial_newsletter": payload.editorial_newsletter,
        }
        dark_mode = int(existing_settings["dark_mode"] if existing_settings else 1)
        connection.execute(
            """
            INSERT INTO user_settings(user_id,dark_mode,email_digest,fantasy_alerts,notification_preferences,created_at,updated_at)
            VALUES (?,?,?,?,?,?,?)
            ON CONFLICT(user_id) DO UPDATE SET email_digest=excluded.email_digest,
              fantasy_alerts=excluded.fantasy_alerts,notification_preferences=excluded.notification_preferences,
              updated_at=excluded.updated_at
            """,
            (user_id, dark_mode, int(payload.email_digest), int(payload.fantasy_alerts), encode_json(notifications), timestamp, timestamp),
        )
        connection.execute("DELETE FROM favorite_teams WHERE user_id=?", (user_id,))
        for team in teams:
            connection.execute(
                "INSERT INTO favorite_teams(user_id,team_id,created_at) VALUES (?,?,?)",
                (user_id, team, timestamp),
            )
        connection.execute("DELETE FROM favorite_players WHERE user_id=?", (user_id,))
        for player in players:
            connection.execute(
                "INSERT INTO favorite_players(user_id,player_id,created_at) VALUES (?,?,?)",
                (user_id, player, timestamp),
            )
        connection.commit()
    return _profile_payload(user_id, user_id)
