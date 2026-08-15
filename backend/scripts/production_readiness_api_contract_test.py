from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import database
from app.migrations import run_migrations
from app.production_readiness_api import production_readiness_payload


def main() -> None:
    previous = {
        key: os.environ.get(key)
        for key in [
            "SPORTS_TERMINAL_ENV",
            "SPORTS_TERMINAL_DATABASE_URL",
            "SPORTS_TERMINAL_BILLING_MODE",
            "SPORTS_TERMINAL_EMAIL_PROVIDER",
            "SPORTS_TERMINAL_OBJECT_STORE",
        ]
    }
    try:
        os.environ["SPORTS_TERMINAL_ENV"] = "development"
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_BILLING_MODE"] = "disabled"
        os.environ["SPORTS_TERMINAL_EMAIL_PROVIDER"] = "disabled"
        os.environ["SPORTS_TERMINAL_OBJECT_STORE"] = "filesystem"
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "readiness.db"
            with database.connect() as connection:
                connection.executescript(
                    """
                    CREATE TABLE users (id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL);
                    CREATE TABLE auth_sessions (
                      token_hash TEXT PRIMARY KEY,
                      user_id TEXT NOT NULL,
                      expires_at TEXT NOT NULL,
                      created_at TEXT NOT NULL,
                      last_seen_at TEXT NOT NULL,
                      revoked_at TEXT
                    );
                    CREATE TABLE organizations (id TEXT PRIMARY KEY);
                    """
                )
            run_migrations()
            payload = production_readiness_payload()
            assert payload["database"]["schema_version"] == "0005"
            assert payload["billing_mode"] == "disabled"
            assert payload["checks"]["schema_current"] is True
            assert payload["checks"]["required_tables"] is True
            assert payload["checks"]["security_email_delivery"] is True
            assert payload["checks"]["durable_object_storage"] is True
            assert payload["status"] == "ready"
        print("production_readiness_api_contract: PASS")
    finally:
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
