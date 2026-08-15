from __future__ import annotations

import os
import secrets
import tempfile
from pathlib import Path

from app import database
from app.auth_api import PASSWORD_ITERATIONS, _password_hash, init_auth_db
from app.auth_delivery import AuthDeliveryTokenService
from app.auth_recovery_api import (
    EmailRequest,
    PasswordResetConfirm,
    TokenConfirm,
    confirm_email_verification,
    confirm_password_reset,
    request_password_reset,
)
from app.main import make_id, now_iso
from app.migrations import run_migrations


def main() -> None:
    original = {key: os.environ.get(key) for key in (
        "SPORTS_TERMINAL_DATABASE_URL",
        "SPORTS_TERMINAL_SESSION_PEPPER",
        "SPORTS_TERMINAL_EMAIL_PROVIDER",
    )}
    pepper = "r" * 40
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_SESSION_PEPPER"] = pepper
        os.environ["SPORTS_TERMINAL_EMAIL_PROVIDER"] = "disabled"
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "recovery.db"
            init_auth_db()
            run_migrations()
            timestamp = now_iso()
            user_id = make_id("usr")
            salt = secrets.token_bytes(16).hex()
            with database.connect() as connection:
                connection.execute(
                    "INSERT INTO users (id, email, display_name, role, status, created_at, updated_at) VALUES (?, 'analyst@example.com', 'Analyst Person', 'analyst', 'active', ?, ?)",
                    (user_id, timestamp, timestamp),
                )
                connection.execute(
                    "INSERT INTO auth_credentials (user_id, password_hash, password_salt, password_iterations, email_verified, created_at, updated_at) VALUES (?, ?, ?, ?, 0, ?, ?)",
                    (user_id, _password_hash("InitialPass123!", salt, PASSWORD_ITERATIONS), salt, PASSWORD_ITERATIONS, timestamp, timestamp),
                )
                verify = AuthDeliveryTokenService(pepper).issue(
                    connection, user_id=user_id, purpose="verify-email", ttl_minutes=30
                )
                reset = AuthDeliveryTokenService(pepper).issue(
                    connection, user_id=user_id, purpose="password-reset", ttl_minutes=30
                )
                token_hash = "session-token-hash"
                connection.execute(
                    "INSERT INTO auth_sessions (token_hash, user_id, expires_at, created_at, last_seen_at) VALUES (?, ?, '2099-01-01T00:00:00+00:00', ?, ?)",
                    (token_hash, user_id, timestamp, timestamp),
                )
                connection.commit()

            assert confirm_email_verification(TokenConfirm(token=verify.plaintext)) == {"verified": True}
            with database.connect() as connection:
                assert connection.execute(
                    "SELECT email_verified FROM auth_credentials WHERE user_id = ?", (user_id,)
                ).fetchone()["email_verified"] == 1

            assert request_password_reset(EmailRequest(email="unknown@example.com")) == {"accepted": True}
            assert request_password_reset(EmailRequest(email="analyst@example.com")) == {"accepted": True}
            # Use the already-issued reset token; public request responses never expose one.
            result = confirm_password_reset(
                PasswordResetConfirm(token=reset.plaintext, new_password="DifferentStrong456!")
            )
            assert result["password_reset"] is True
            assert result["sessions_revoked"] is True
            with database.connect() as connection:
                row = connection.execute(
                    "SELECT revoked_at FROM auth_sessions WHERE token_hash = ?", (token_hash,)
                ).fetchone()
                assert row is not None and row["revoked_at"] is not None

        print("auth_recovery_contract: PASS")
    finally:
        for key, value in original.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
