from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import database
from app.migrations import current_schema_version, discover_migrations, run_migrations
from scripts.migrate import bootstrap_core_schema


def main() -> None:
    original_url = os.environ.get("SPORTS_TERMINAL_DATABASE_URL")
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        migrations = discover_migrations()
        expected = ("0001", "0002", "0003", "0004", "0005", "0006")
        assert tuple(item.version for item in migrations) == expected
        assert len({item.checksum for item in migrations}) == len(expected)

        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "migration.db"
            with database.connect() as connection:
                connection.executescript(
                    """
                    CREATE TABLE users (
                      id TEXT PRIMARY KEY,
                      email TEXT UNIQUE NOT NULL
                    );
                    CREATE TABLE auth_sessions (
                      token_hash TEXT PRIMARY KEY,
                      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                      expires_at TEXT NOT NULL,
                      created_at TEXT NOT NULL,
                      last_seen_at TEXT NOT NULL,
                      revoked_at TEXT
                    );
                    CREATE TABLE organizations (
                      id TEXT PRIMARY KEY
                    );
                    """
                )
                first = run_migrations(migrations, connection=connection)
                assert first.applied == expected
                assert first.already_applied == ()
                second = run_migrations(migrations, connection=connection)
                assert second.applied == ()
                assert second.already_applied == expected
                tables = set(database.list_tables(connection))
                assert "schema_migrations" in tables
                assert "auth_mfa_factors" in tables
                assert "auth_session_security" in tables
                assert "delivery_outbox" in tables
                assert "organization_security_policies" in tables
                assert "sso_connections" in tables
                assert "sso_identities" in tables
                assert "entitlement_grants" in tables
                assert "certified_releases" in tables
                assert "backup_manifests" in tables
                columns = {
                    str(row["name"])
                    for row in connection.execute("PRAGMA table_info(sso_login_states)").fetchall()
                }
                assert "pkce_verifier_ciphertext" in columns

        # A brand-new database must not require hand-created foreign-key parents.
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "fresh.db"
            bootstrap_core_schema()
            fresh = run_migrations(migrations)
            assert fresh.applied == expected
            assert current_schema_version() == "0006"
            with database.connect() as connection:
                tables = set(database.list_tables(connection))
                assert {"users", "organizations", "auth_sessions"}.issubset(tables)
                assert {"auth_delivery_tokens", "sso_connections", "sso_identities"}.issubset(tables)

        print("migration_contract: PASS")
    finally:
        if original_url is None:
            os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        else:
            os.environ["SPORTS_TERMINAL_DATABASE_URL"] = original_url


if __name__ == "__main__":
    main()
