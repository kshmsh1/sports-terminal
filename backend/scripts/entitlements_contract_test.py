from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import database, entitlements
from app.migrations import run_migrations


def main() -> None:
    original_url = os.environ.get("SPORTS_TERMINAL_DATABASE_URL")
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "entitlements.db"
            entitlements.connect = database.connect
            with database.connect() as connection:
                connection.executescript(
                    """
                    CREATE TABLE users (id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL);
                    CREATE TABLE subscriptions (
                      id TEXT PRIMARY KEY,
                      user_id TEXT NOT NULL,
                      plan_id TEXT NOT NULL,
                      status TEXT NOT NULL,
                      updated_at TEXT NOT NULL
                    );
                    """
                )
                connection.execute(
                    "INSERT INTO users VALUES (?, ?)", ("u1", "user@example.com")
                )
                connection.execute(
                    "INSERT INTO subscriptions VALUES (?, ?, ?, ?, ?)",
                    ("s1", "u1", "pro", "active", "2026-08-01T00:00:00+00:00"),
                )
            run_migrations()
            with database.connect() as connection:
                connection.execute(
                    "INSERT INTO entitlement_grants "
                    "(id, subject_type, subject_id, entitlement_key, source, created_at, updated_at) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?)",
                    (
                        "g1",
                        "user",
                        "u1",
                        "front_office.preview",
                        "manual",
                        "2026-08-01T00:00:00+00:00",
                        "2026-08-01T00:00:00+00:00",
                    ),
                )
            snapshot = entitlements.EntitlementService().for_user("u1")
            assert snapshot.plan_id == "pro"
            assert snapshot.allows("nba.history.full")
            assert snapshot.allows("front_office.preview")
            assert not snapshot.allows("enterprise.sso")
            assert "front_office.preview" in snapshot.explicit_grants

            organization = entitlements.EntitlementService().for_organization("org1")
            assert organization.plan_id == "org"
            assert organization.allows("workspace.shared")
            assert not organization.allows("enterprise.sso")

        print("entitlements_contract: PASS")
    finally:
        if original_url is None:
            os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        else:
            os.environ["SPORTS_TERMINAL_DATABASE_URL"] = original_url


if __name__ == "__main__":
    main()
