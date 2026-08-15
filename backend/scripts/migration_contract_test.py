from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import database
from app.migrations import discover_migrations, run_migrations


def main() -> None:
    original_url = os.environ.get("SPORTS_TERMINAL_DATABASE_URL")
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        migrations = discover_migrations()
        assert [item.version for item in migrations] == ["0001", "0002", "0003"]
        assert len({item.checksum for item in migrations}) == 3

        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "migration.db"
            with database.connect() as connection:
                connection.executescript(
                    """
                    CREATE TABLE users (
                      id TEXT PRIMARY KEY,
                      email TEXT UNIQUE NOT NULL
                    );
                    """
                )
                first = run_migrations(migrations, connection=connection)
                assert first.applied == ("0001", "0002", "0003")
                assert first.already_applied == ()
                second = run_migrations(migrations, connection=connection)
                assert second.applied == ()
                assert second.already_applied == ("0001", "0002", "0003")
                tables = set(database.list_tables(connection))
                assert "schema_migrations" in tables
                assert "auth_mfa_factors" in tables
                assert "entitlement_grants" in tables
                assert "certified_releases" in tables
                assert "backup_manifests" in tables

        print("migration_contract: PASS")
    finally:
        if original_url is None:
            os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        else:
            os.environ["SPORTS_TERMINAL_DATABASE_URL"] = original_url


if __name__ == "__main__":
    main()
