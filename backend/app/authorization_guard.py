from __future__ import annotations

import hashlib
import json
import os
import sqlite3
from typing import Any, Awaitable, Callable

from fastapi import Request
from fastapi.responses import JSONResponse, Response

from .main import connect, now_iso

_PUBLIC_PREFIXES = (
    "/v2/auth/",
    "/v2/launch/readiness",
    "/v2/billing/webhooks/",
)
_ADMIN_PREFIXES = (
    "/v2/trust/moderation/",
    "/v2/completion/",
)
_ADMIN_EXACT = {
    ("PUT", "/v2/workspaces/primary/permissions"),
    ("DELETE", "/v2/workspaces/primary/permissions"),
}
_PLATFORM_PREFIXES = (
    "/v2/platform/",
    "/v2/operations/",
    "/v2/releases",
)
_SELF_QUERY_KEYS = {
    "actor_user_id",
    "viewer_user_id",
    "user_id",
    "recipient_user_id",
    "owner_user_id",
}
_SELF_BODY_KEYS = {
    "actor_user_id",
    "viewer_user_id",
    "created_by_user_id",
    "owner_user_id",
}


def _enabled() -> bool:
    return os.getenv("SPORTS_TERMINAL_ENFORCE_AUTH", "false").lower() == "true"


def _token(request: Request) -> str:
    authorization = request.headers.get("authorization", "")
    if not authorization.lower().startswith("bearer "):
        return ""
    return authorization.split(" ", 1)[1].strip()


def _table_columns(connection: sqlite3.Connection, table: str) -> set[str]:
    return {
        str(row["name"])
        for row in connection.execute(f"PRAGMA table_info({table})").fetchall()
    }


def _session_identity(token: str) -> dict[str, str] | None:
    if not token:
        return None
    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    with connect() as connection:
        tables = {
            str(row["name"])
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            ).fetchall()
        }
        session_table = ""
        for candidate in ("auth_sessions", "user_sessions", "sessions"):
            if candidate not in tables:
                continue
            columns = _table_columns(connection, candidate)
            if {"token_hash", "user_id"}.issubset(columns):
                session_table = candidate
                break
        if not session_table:
            return None
        columns = _table_columns(connection, session_table)
        clauses = ["token_hash = ?"]
        values: list[Any] = [token_hash]
        if "revoked_at" in columns:
            clauses.append("(revoked_at IS NULL OR revoked_at = '')")
        if "expires_at" in columns:
            clauses.append("expires_at > ?")
            values.append(now_iso())
        session = connection.execute(
            f"SELECT * FROM {session_table} WHERE {' AND '.join(clauses)} LIMIT 1",
            tuple(values),
        ).fetchone()
        if session is None:
            return None
        user_id = str(session["user_id"])
        user = None
        if "users" in tables:
            user = connection.execute(
                "SELECT * FROM users WHERE id = ? LIMIT 1",
                (user_id,),
            ).fetchone()
        role = "analyst"
        organization_id = ""
        if user is not None:
            user_columns = set(user.keys())
            if "role" in user_columns and user["role"]:
                role = str(user["role"])
            if "organization_id" in user_columns and user["organization_id"]:
                organization_id = str(user["organization_id"])
        if not organization_id and "organization_memberships" in tables:
            membership_columns = _table_columns(connection, "organization_memberships")
            organization_column = (
                "organization_id"
                if "organization_id" in membership_columns
                else "org_id"
                if "org_id" in membership_columns
                else ""
            )
            if organization_column:
                membership = connection.execute(
                    "SELECT * FROM organization_memberships "
                    "WHERE user_id = ? ORDER BY joined_at ASC LIMIT 1",
                    (user_id,),
                ).fetchone()
                if membership is not None:
                    organization_id = str(membership[organization_column] or "")
                    membership_keys = set(membership.keys())
                    membership_role = (
                        str(membership["role"])
                        if "role" in membership_keys and membership["role"]
                        else str(membership["membership_role"])
                        if "membership_role" in membership_keys
                        and membership["membership_role"]
                        else ""
                    )
                    if membership_role in {"owner", "admin"}:
                        role = "organization_admin"
        return {
            "user_id": user_id,
            "role": role,
            "organization_id": organization_id,
        }


def _error(status_code: int, detail: str) -> JSONResponse:
    return JSONResponse(status_code=status_code, content={"detail": detail})


def _admin(role: str) -> bool:
    return role in {"organization_admin", "platform_admin"}


def _platform(role: str) -> bool:
    return role == "platform_admin"


def _claim_mismatch(payload: dict[str, Any], keys: set[str], user_id: str) -> str:
    for key in keys:
        value = payload.get(key)
        if value is None or str(value).strip() == "":
            continue
        if str(value) != user_id:
            return key
    return ""


def _path_claim(path: str) -> tuple[str, str] | None:
    prefixes = (
        "/v2/trust/relationships/",
        "/v2/notifications/",
        "/v2/entitlements/users/",
    )
    for prefix in prefixes:
        if path.startswith(prefix):
            value = path[len(prefix) :].split("/", 1)[0]
            if value:
                return prefix, value
    return None


async def enforce_launch_authorization(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    if not _enabled() or not request.url.path.startswith("/v2/"):
        return await call_next(request)
    if any(request.url.path.startswith(prefix) for prefix in _PUBLIC_PREFIXES):
        return await call_next(request)

    identity = _session_identity(_token(request))
    if identity is None:
        return _error(401, "A valid Sports Terminal session is required")
    request.state.user_id = identity["user_id"]
    request.state.user_role = identity["role"]
    request.state.organization_id = identity["organization_id"]

    method = request.method.upper()
    path = request.url.path
    role = identity["role"]
    user_id = identity["user_id"]

    if any(path.startswith(prefix) for prefix in _PLATFORM_PREFIXES):
        if not _platform(role):
            return _error(403, "Platform administrator access is required")
    if any(path.startswith(prefix) for prefix in _ADMIN_PREFIXES) or (
        method,
        path,
    ) in _ADMIN_EXACT:
        if not _admin(role):
            return _error(403, "Organization administrator access is required")

    query = {key: value for key, value in request.query_params.items()}
    mismatch = "" if _platform(role) else _claim_mismatch(
        query,
        _SELF_QUERY_KEYS,
        user_id,
    )
    if mismatch:
        return _error(
            403,
            f"The {mismatch} query claim must match the bearer session",
        )

    path_claim = _path_claim(path)
    if path_claim is not None and path_claim[1] != user_id and not _platform(role):
        return _error(403, "The requested user resource does not belong to this session")

    if method in {"POST", "PUT", "PATCH", "DELETE"}:
        body = await request.body()
        if body:
            try:
                decoded = json.loads(body)
            except json.JSONDecodeError:
                decoded = None
            if isinstance(decoded, dict):
                mismatch = "" if _platform(role) else _claim_mismatch(
                    decoded,
                    _SELF_BODY_KEYS,
                    user_id,
                )
                if mismatch:
                    return _error(
                        403,
                        f"The {mismatch} body claim must match the bearer session",
                    )
            sent = False

            async def receive() -> dict[str, Any]:
                nonlocal sent
                if sent:
                    return {"type": "http.request", "body": b"", "more_body": False}
                sent = True
                return {"type": "http.request", "body": body, "more_body": False}

            request._receive = receive

    return await call_next(request)
