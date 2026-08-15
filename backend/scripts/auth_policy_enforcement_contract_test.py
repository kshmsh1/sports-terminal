from __future__ import annotations

import asyncio
import hashlib
import json
import os
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

from starlette.requests import Request
from starlette.responses import JSONResponse

from app import auth_guard, database


def request(path: str, token: str | None = None, *, method: str = "GET") -> Request:
    headers = []
    if token:
        headers.append((b"authorization", f"Bearer {token}".encode()))
    return Request(
        {
            "type": "http",
            "method": method,
            "path": path,
            "headers": headers,
            "query_string": b"",
            "scheme": "https",
            "server": ("test", 443),
            "client": ("127.0.0.1", 1234),
        }
    )


async def allowed(request: Request) -> JSONResponse:
    return JSONResponse({"allowed": True, "auth_level": getattr(request.state, "auth_level", None)})


def body(response) -> dict:
    return json.loads(response.body.decode("utf-8"))


def main() -> None:
    original = {key: os.environ.get(key) for key in (
        "SPORTS_TERMINAL_DATABASE_URL",
        "SPORTS_TERMINAL_ENFORCE_AUTH",
        "SPORTS_TERMINAL_REQUIRE_EMAIL_VERIFICATION",
    )}
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_ENFORCE_AUTH"] = "true"
        os.environ["SPORTS_TERMINAL_REQUIRE_EMAIL_VERIFICATION"] = "true"
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "guard.db"
            auth_guard.connect = database.connect
            token = "policy-session-token"
            token_hash = hashlib.sha256(token.encode()).hexdigest()
            now = datetime.now(timezone.utc)
            with database.connect() as connection:
                connection.executescript(
                    """
                    CREATE TABLE users (
                      id TEXT PRIMARY KEY, status TEXT NOT NULL, role TEXT NOT NULL
                    );
                    INSERT INTO users VALUES ('usr_1', 'active', 'organization_admin');
                    CREATE TABLE auth_credentials (
                      user_id TEXT PRIMARY KEY, email_verified INTEGER NOT NULL
                    );
                    INSERT INTO auth_credentials VALUES ('usr_1', 1);
                    CREATE TABLE auth_sessions (
                      token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL,
                      expires_at TEXT NOT NULL, created_at TEXT NOT NULL, revoked_at TEXT
                    );
                    CREATE TABLE auth_session_security (
                      token_hash TEXT PRIMARY KEY, auth_level TEXT NOT NULL,
                      mfa_verified_at TEXT, device_hash TEXT, client_hash TEXT, created_at TEXT NOT NULL
                    );
                    CREATE TABLE organization_memberships (
                      organization_id TEXT NOT NULL, user_id TEXT NOT NULL,
                      role TEXT NOT NULL, status TEXT NOT NULL
                    );
                    INSERT INTO organization_memberships VALUES ('org_1', 'usr_1', 'owner', 'active');
                    CREATE TABLE organization_security_policies (
                      organization_id TEXT PRIMARY KEY, require_mfa INTEGER NOT NULL,
                      sso_required INTEGER NOT NULL, max_session_days INTEGER NOT NULL
                    );
                    INSERT INTO organization_security_policies VALUES ('org_1', 1, 0, 7);
                    """
                )
                connection.execute(
                    "INSERT INTO auth_sessions VALUES (?, 'usr_1', ?, ?, NULL)",
                    (token_hash, (now + timedelta(days=30)).isoformat(), now.isoformat()),
                )
                connection.execute(
                    "INSERT INTO auth_session_security (token_hash, auth_level, created_at) VALUES (?, 'password', ?)",
                    (token_hash, now.isoformat()),
                )

            public = asyncio.run(
                auth_guard.enforce_launch_auth(request("/v2/auth/password-reset/request"), allowed)
            )
            assert public.status_code == 200

            blocked = asyncio.run(
                auth_guard.enforce_launch_auth(request("/v2/workspaces", token), allowed)
            )
            assert blocked.status_code == 403
            assert "MFA is required" in body(blocked)["detail"]

            enroll = asyncio.run(
                auth_guard.enforce_launch_auth(
                    request("/v2/security/mfa/totp/enroll", token, method="POST"), allowed
                )
            )
            assert enroll.status_code == 200
            assert body(enroll)["auth_level"] == "password"
            verify = asyncio.run(
                auth_guard.enforce_launch_auth(
                    request("/v2/security/mfa/totp/mfa_123/verify", token, method="POST"), allowed
                )
            )
            assert verify.status_code == 200
            disable = asyncio.run(
                auth_guard.enforce_launch_auth(
                    request("/v2/security/mfa/mfa_123", token, method="DELETE"), allowed
                )
            )
            assert disable.status_code == 403

            with database.connect() as connection:
                connection.execute(
                    "UPDATE auth_session_security SET auth_level = 'mfa', mfa_verified_at = ? WHERE token_hash = ?",
                    (now.isoformat(), token_hash),
                )
            accepted = asyncio.run(
                auth_guard.enforce_launch_auth(request("/v2/workspaces", token), allowed)
            )
            assert accepted.status_code == 200
            assert body(accepted)["auth_level"] == "mfa"

            with database.connect() as connection:
                old = now - timedelta(days=10)
                connection.execute(
                    "UPDATE auth_sessions SET created_at = ? WHERE token_hash = ?",
                    (old.isoformat(), token_hash),
                )
            expired_by_policy = asyncio.run(
                auth_guard.enforce_launch_auth(request("/v2/workspaces", token), allowed)
            )
            assert expired_by_policy.status_code == 401
            assert "maximum lifetime" in body(expired_by_policy)["detail"]

        print("auth_policy_enforcement_contract: PASS")
    finally:
        for key, value in original.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
