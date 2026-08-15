from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import backup_manifests, database
from app.backup_executor import create_database_backup


def main() -> None:
    original = {key: os.environ.get(key) for key in (
        "SPORTS_TERMINAL_DATABASE_URL",
        "SPORTS_TERMINAL_OBJECT_STORE",
        "SPORTS_TERMINAL_OBJECT_STORE_PATH",
        "SPORTS_TERMINAL_BACKUP_SIGNING_SECRET",
    )}
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_OBJECT_STORE"] = "filesystem"
        os.environ["SPORTS_TERMINAL_BACKUP_SIGNING_SECRET"] = "b" * 40
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            database.DEFAULT_SQLITE_PATH = root / "source.db"
            os.environ["SPORTS_TERMINAL_OBJECT_STORE_PATH"] = str(root / "objects")
            backup_manifests.connect = database.connect
            with database.connect() as connection:
                connection.executescript(
                    """
                    CREATE TABLE schema_migrations (
                      version TEXT PRIMARY KEY,
                      name TEXT NOT NULL,
                      checksum TEXT NOT NULL,
                      applied_at TEXT NOT NULL
                    );
                    INSERT INTO schema_migrations VALUES ('0005', 'test', 'checksum', CURRENT_TIMESTAMP);
                    CREATE TABLE backup_manifests (
                      id TEXT PRIMARY KEY,
                      database_backend TEXT NOT NULL,
                      schema_version TEXT NOT NULL,
                      release_id TEXT,
                      object_key TEXT NOT NULL,
                      byte_size INTEGER,
                      sha256 TEXT NOT NULL,
                      signature TEXT NOT NULL,
                      status TEXT NOT NULL,
                      created_at TEXT NOT NULL,
                      verified_at TEXT,
                      restored_at TEXT
                    );
                    CREATE TABLE durable_example (id TEXT PRIMARY KEY, value TEXT NOT NULL);
                    INSERT INTO durable_example VALUES ('one', 'persist-me');
                    """
                )
            result = create_database_backup()
            assert result.object.backend == "filesystem"
            assert result.object.byte_size > 0
            assert result.manifest["status"] == "created"
            object_path = root / "objects" / result.object.key
            assert object_path.exists()
            assert object_path.stat().st_size == result.object.byte_size
            with database.connect() as connection:
                row = connection.execute(
                    "SELECT status, verified_at, sha256 FROM backup_manifests WHERE id = ?",
                    (result.manifest["id"],),
                ).fetchone()
                assert row is not None
                assert row["status"] == "verified"
                assert row["verified_at"] is not None
                assert row["sha256"] == result.object.sha256

        print("backup_executor_contract: PASS")
    finally:
        for key, value in original.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
