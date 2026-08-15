from __future__ import annotations

import hashlib
import os
import re
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import Request
from fastapi.responses import JSONResponse

from .main import connect

PUBLIC_V2_PATHS = {
    "/v2/auth/signup",
    "/v2/auth/login",
    "/v2/auth/login/mfa",
    "/v2/auth/email-verification/request",
    "/v2/auth/email-verification/confirm",
    "/v2/auth/password-reset/request",
    "/v2/auth/password-reset/confirm",
    "/v2/launch/config",
    "/v2/launch/readiness",
}
PUBLIC_V2_PREFIXES = (
    "/v2/billing/webhooks/",
)
_MFA_VERIFY_PATH = re.compile(r"^/v2/security/mfa/totp/[^/]+/verify$")


def auth_enforcement_enabled() -> bool:
    return os.getenv("SPORTS_TERMINAL_ENFORCE_AUTH", "false").lower() == "true"


def _error(status: int, detail: str) -> JSONResponse:
    return JSONResponse(status_code=status, content={"detail": detail})


def _mfa_bootstrap_allowed(request: Request, path: str) -> bool:
    if request.method.upper() != "POST":
        return False
    return path == "/v2/security/mfa/totp/enroll" or bool(_MFA_VERIFY_PATH.match(path))


def _session_assurance(connection: Any, token_hash: str) -> str:
    try:
        row = connection.execute(
            "SELECT auth_level FROM auth_session_security WHERE token_hash = ?",
            (token_hash,),
        ).fetchone()
        return "password" if row is None else str(row["auth_level"] or "password")
    except Exception:
        # Legacy development databases may predate the assurance migration. Production
        # bootstrap requires the current schema, so this fallback is development-only.
        return "password"


def _organization_policy(connection: Any, user_id: str) -> dict[str, Any]:
    try:
        rows = connection.execute(
            """
            SELECT organization_memberships.organization_id,
                   organization_security_policies.require_mfa,
                   organization_security_policies.sso_required,
                   organization_security_policies.max_session_days
            FROM organization_memberships
            LEFT JOIN organization_security_policies
              ON organization_security_policies.organization_id = organization_memberships.organization_id
            WHERE organization_memberships.user_id = ?
              AND organization_memberships.status = 'active'
            """,
            (user_id,),
        ).fetchall()
    except Exception:
        return {
            "organization_id": "",
            "require_mfa": False,
            "sso_required": False,
            "max_session_days": 30,
        }
    if not rows:
        return {
            "organization_id": "",
            "require_mfa": False,
            "sso_required": False,
            "max_session_days": 30,
        }
    return {
        "organization_id": str(rows[0]["organization_id"] or ""),
        "require_mfa": any(bool(row["require_mfa"] or 0) for row in rows),
        "sso_required": any(bool(row["sso_required"] or 0) for row in rows),
        "max_session_days": min(
            max(1, int(row["max_session_days"] or 30)) for row in rows
        ),
    }


def _email_verified(connection: Any, user_id: str) -> bool:
    try:
        row = connection.execute(
            "SELECT email_verified FROM auth_credentials WHERE user_id = ?",
            (user_id,),
        ).fetchone()
        return row is not None and bool(row["email_verified"])
    except Exception:
        return False


async def enforce_launch_auth(request: Request, call_next: Any):
    """Require valid sessions and enforce session-assurance policy on `/v2` routes.

    Local development stays permissive unless `SPORTS_TERMINAL_ENFORCE_AUTH=true`.
    Billing webhook ingress is bearer-exempt because it is authenticated independently
    with request-body HMAC. Verification/recovery and MFA completion are also public
    because they exist specifically to establish or recover authentication.
    """

    if not auth_enforcement_enabled():
        return await call_next(request)
    path = request.url.path.rstrip("/") or "/"
    public_prefix = any(path.startswith(prefix) for prefix in PUBLIC_V2_PREFIXES)
    if not path.startswith("/v2") or path in PUBLIC_V2_PATHS or public_prefix:
        return await call_next(request)

    authorization = request.headers.get("authorization", "")
    if not authorization.lower().startswith("bearer "):
        return _error(401, "A bearer session token is required")
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        return _error(401, "A bearer session token is required")

    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    with connect() as connection:
        row = connection.execute(
            """
            SELECT auth_sessions.user_id,
                   auth_sessions.expires_at,
                   auth_sessions.created_at,
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
            return _error(401, "Session is invalid or revoked")
        now = datetime.now(timezone.utc)
        if datetime.fromisoformat(str(row["expires_at"])) <= now:
            return _error(401, "Session has expired")
        if row["status"] != "active":
            return _error(403, "Account is not active")
        user_id = str(row["user_id"])
        if os.getenv("SPORTS_TERMINAL_REQUIRE_EMAIL_VERIFICATION", "false").lower() == "true":
            if not _email_verified(connection, user_id):
                return _error(403, "Email verification is required")

        assurance = _session_assurance(connection, token_hash)
        policy = _organization_policy(connection, user_id)
        created_at = datetime.fromisoformat(str(row["created_at"]))
        maximum_age = timedelta(days=int(policy["max_session_days"]))
        if created_at + maximum_age <= now:
            return _error(401, "Session exceeds organization maximum lifetime")
        if policy["require_mfa"] and assurance not in {"mfa", "sso_mfa"}:
            if not _mfa_bootstrap_allowed(request, path):
                return _error(403, "MFA is required by organization policy")
        if policy["sso_required"] and assurance not in {"sso", "sso_mfa"}:
            return _error(403, "SSO is required by organization policy")

        request.state.user_id = user_id
        request.state.user_role = row["role"]
        request.state.organization_id = policy["organization_id"]
        request.state.auth_level = assurance

    return await call_next(request)
