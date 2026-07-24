from __future__ import annotations

import hashlib
import os
from datetime import datetime, timezone
from typing import Any

from fastapi import Request
from fastapi.responses import JSONResponse

from .main import connect

PUBLIC_V2_PATHS = {
    "/v2/auth/signup",
    "/v2/auth/login",
    "/v2/launch/config",
    "/v2/launch/readiness",
}


def auth_enforcement_enabled() -> bool:
    return os.getenv("SPORTS_TERMINAL_ENFORCE_AUTH", "false").lower() == "true"


async def enforce_launch_auth(request: Request, call_next: Any):
    """Optionally require a valid first-party bearer session for `/v2` routes.

    Local development stays permissive unless `SPORTS_TERMINAL_ENFORCE_AUTH=true`.
    Staging and public deployments can turn on enforcement without rebuilding the
    Flutter application because the client already sends its bearer token.
    """

    if not auth_enforcement_enabled():
        return await call_next(request)
    path = request.url.path.rstrip("/") or "/"
    if not path.startswith("/v2") or path in PUBLIC_V2_PATHS:
        return await call_next(request)

    authorization = request.headers.get("authorization", "")
    if not authorization.lower().startswith("bearer "):
        return JSONResponse(
            status_code=401,
            content={"detail": "A bearer session token is required"},
        )
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        return JSONResponse(
            status_code=401,
            content={"detail": "A bearer session token is required"},
        )

    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    with connect() as connection:
        row = connection.execute(
            """
            SELECT auth_sessions.user_id,
                   auth_sessions.expires_at,
                   auth_sessions.revoked_at,
                   users.status,
                   users.role
            FROM auth_sessions
            JOIN users ON users.id = auth_sessions.user_id
            WHERE auth_sessions.token_hash = ?
            """,
            (token_hash,),
        ).fetchone()
        if row is None or row["revoked_at"] is not None:
            return JSONResponse(
                status_code=401,
                content={"detail": "Session is invalid or revoked"},
            )
        if datetime.fromisoformat(row["expires_at"]) <= datetime.now(timezone.utc):
            return JSONResponse(
                status_code=401,
                content={"detail": "Session has expired"},
            )
        if row["status"] != "active":
            return JSONResponse(
                status_code=403,
                content={"detail": "Account is not active"},
            )
        request.state.user_id = row["user_id"]
        request.state.user_role = row["role"]

    return await call_next(request)
