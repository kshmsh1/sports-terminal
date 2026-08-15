from __future__ import annotations

import os
import sqlite3
import tempfile
from pathlib import Path

from app import backup_manifests, database
from app.backup_executor import create_database_backup
from app.restore_executor import RestoreExecutionError, restore_postgres_to_database, restore_sqlite_to_path


def main() -> None:
    original = {key: os.environ.get(key) for key in (
        "SPORTS_TERMINAL_DATABASE_URL",
        "SPORTS_TERMINAL_OBJECT_STORE",
        "SPORTS_TERMINAL_OBJECT_STORE_PATH",
        "SPORTS_TERMINAL_BACKUP_SIGNING_SECRET",
        "SPORTS_TERMINAL_ALLOW_DATABASE_RESTORE",
    )}
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_OBJECT_STORE"] = "filesystem"
        os.environ["SPORTS_TERMINAL_BACKUP_SIGNING_SECRET"] = "r" * 40
        os.environ["SPORTS_TERMINAL_ALLOW_DATABASE_RESTORE"] = "false"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            database.DEFAULT_SQLITE_PATH = root / "source.db"
            os.environ["SPORTS_TERMINAL_OBJECT_STORE_PATH"] = str(root / "objects")
            backup_manifests.connect = database.connect
            with database.connect() as connection:
                connection.executescript(
                    """
                    CREATE TABLE schema_migrations (
                      version TEXT PRIMARY KEY, name TEXT NOT NULL,
                      checksum TEXT NOT NULL, applied_at TEXT NOT NULL
                    );
                    INSERT INTO schema_migrations VALUES ('0005', 'test', 'checksum', CURRENT_TIMESTAMP);
                    CREATE TABLE backup_manifests (
                      id TEXT PRIMARY KEY, database_backend TEXT NOT NULL,
                      schema_version TEXT NOT NULL, release_id TEXT,
                      object_key TEXT NOT NULL, byte_size INTEGER, sha256 TEXT NOT NULL,
                      signature TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL,
                      verified_at TEXT, restored_at TEXT
                    );
                    CREATE TABLE durable_example (id TEXT PRIMARY KEY, value TEXT NOT NULL);
                    INSERT INTO durable_example VALUES ('one', 'restored-value');
                    """
                )
            backup = create_database_backup()
            target = root / "restore-drill.db"
            verified = restore_sqlite_to_path(str(backup.manifest["id"]), target)
            assert verified.sha256 == backup.object.sha256
            restored = sqlite3.connect(target)
            try:
                assert restored.execute(
                    "SELECT value FROM durable_example WHERE id = 'one'"
                ).fetchone()[0] == "restored-value"
            finally:
                restored.close()
            with database.connect() as connection:
                manifest = connection.execute(
                    "SELECT status, restored_at FROM backup_manifests WHERE id = ?",
                    (backup.manifest["id"],),
                ).fetchone()
                assert manifest is not None
                assert manifest["status"] == "restored"
                assert manifest["restored_at"] is not None

            try:
                restore_postgres_to_database(
                    str(backup.manifest["id"]),
                    target_database_url="postgresql://user:pass@localhost/db",
                    allow_destructive=False,
                )
            except RestoreExecutionError:
                pass
            else:
                raise AssertionError("PostgreSQL restore must require explicit destructive opt-in")

        print("restore_executor_contract: PASS")
    finally:
        for key, value in original.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
