from __future__ import annotations

import hashlib
import os
import tempfile
from pathlib import Path

from starlette.requests import Request

from app import account_security_api, auth_api, database
from app.account_security_api import TotpVerifyRequest
from app.mfa import TotpService
from app.migrations import run_migrations


def request() -> Request:
    return Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/v2/security",
            "headers": [(b"user-agent", b"contract-test")],
            "client": ("127.0.0.1", 12345),
            "scheme": "http",
            "server": ("test", 80),
            "query_string": b"",
        }
    )


def main() -> None:
    previous = {
        key: os.environ.get(key)
        for key in [
            "SPORTS_TERMINAL_DATABASE_URL",
            "SPORTS_TERMINAL_SESSION_PEPPER",
            "SPORTS_TERMINAL_MFA_ENCRYPTION_KEY",
        ]
    }
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_SESSION_PEPPER"] = "session-" + "x" * 40
        os.environ["SPORTS_TERMINAL_MFA_ENCRYPTION_KEY"] = "mfa-key-" + "y" * 40
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "security.db"
            account_security_api.connect = database.connect
            auth_api.connect = database.connect
            token = "contract-bearer-token"
            token_hash = hashlib.sha256(token.encode()).hexdigest()
            with database.connect() as connection:
                connection.executescript(
                    """
                    CREATE TABLE users (
                      id TEXT PRIMARY KEY,
                      email TEXT UNIQUE NOT NULL,
                      display_name TEXT NOT NULL,
                      role TEXT NOT NULL,
                      status TEXT NOT NULL
                    );
                    CREATE TABLE auth_sessions (
                      token_hash TEXT PRIMARY KEY,
                      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                      expires_at TEXT NOT NULL,
                      created_at TEXT NOT NULL,
                      last_seen_at TEXT NOT NULL,
                      revoked_at TEXT
                    );
                    """
                )
                connection.execute(
                    "INSERT INTO users VALUES (?, ?, ?, ?, ?)",
                    ("u1", "user@example.com", "User One", "user", "active"),
                )
                connection.execute(
                    "INSERT INTO auth_sessions VALUES (?, ?, ?, ?, ?, NULL)",
                    (
                        token_hash,
                        "u1",
                        "2099-01-01T00:00:00+00:00",
                        "2026-08-01T00:00:00+00:00",
                        "2026-08-01T00:00:00+00:00",
                    ),
                )
            run_migrations()

            result = account_security_api.sessions(authorization=f"Bearer {token}")
            assert result["user_id"] == "u1"
            assert len(result["sessions"]) == 1
            assert result["sessions"][0]["current"] is True
            assert "token_hash" not in result["sessions"][0]

            enrollment = account_security_api.enroll_totp(
                request(), authorization=f"Bearer {token}"
            )
            code = TotpService().code(enrollment["secret"])
            verified = account_security_api.verify_totp(
                enrollment["factor_id"],
                TotpVerifyRequest(code=code),
                request(),
                authorization=f"Bearer {token}",
            )
            assert verified["verified"] is True
            assert len(verified["recovery_codes"]) == 10

            factors = account_security_api.mfa_factors(authorization=f"Bearer {token}")
            assert factors["factors"][0]["verified_at"] is not None

        print("account_security_contract: PASS")
    finally:
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
