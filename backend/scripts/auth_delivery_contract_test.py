from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import database
from app.auth_api import init_auth_db
from app.auth_delivery import AuthDeliveryTokenService
from app.migrations import run_migrations
from app.main import make_id, now_iso


def main() -> None:
    original = os.environ.get("SPORTS_TERMINAL_DATABASE_URL")
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "delivery-token.db"
            init_auth_db()
            run_migrations()
            with database.connect() as connection:
                user_id = make_id("usr")
                timestamp = now_iso()
                connection.execute(
                    "INSERT INTO users (id, email, display_name, role, status, created_at, updated_at) VALUES (?, ?, 'Analyst', 'analyst', 'active', ?, ?)",
                    (user_id, "analyst@example.com", timestamp, timestamp),
                )
                service = AuthDeliveryTokenService("p" * 40)
                first = service.issue(connection, user_id=user_id, purpose="verify-email", ttl_minutes=30)
                second = service.issue(connection, user_id=user_id, purpose="verify-email", ttl_minutes=30)
                assert first.plaintext != second.plaintext
                assert service.consume(connection, plaintext=first.plaintext, purpose="verify-email") is None
                assert service.consume(connection, plaintext=second.plaintext, purpose="verify-email") == user_id
                assert service.consume(connection, plaintext=second.plaintext, purpose="verify-email") is None

                reset = service.issue(connection, user_id=user_id, purpose="password-reset", ttl_minutes=20)
                assert service.consume(connection, plaintext=reset.plaintext, purpose="verify-email") is None
                assert service.consume(connection, plaintext=reset.plaintext, purpose="password-reset") == user_id

            print("auth_delivery_contract: PASS")
    finally:
        if original is None:
            os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        else:
            os.environ["SPORTS_TERMINAL_DATABASE_URL"] = original


if __name__ == "__main__":
    main()
