from __future__ import annotations

import hashlib
import os
import tempfile
from pathlib import Path

from app import backup_manifests, database
from app.migrations import run_migrations


def main() -> None:
    keys = ["SPORTS_TERMINAL_DATABASE_URL", "SPORTS_TERMINAL_BACKUP_SIGNING_SECRET"]
    previous = {key: os.environ.get(key) for key in keys}
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_BACKUP_SIGNING_SECRET"] = "backup-secret-" + "x" * 40
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "backup.db"
            backup_manifests.connect = database.connect
            backup_manifests.current_schema_version = lambda: "0003"
            with database.connect() as connection:
                connection.execute(
                    "CREATE TABLE users (id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL)"
                )
            run_migrations()
            digest = hashlib.sha256(b"database-backup-bytes").hexdigest()
            service = backup_manifests.BackupManifestService()
            record = service.record(
                object_key="backups/production/2026-08-15.dump",
                sha256=digest,
                byte_size=21,
                release_id="rel_123",
            )
            assert record["status"] == "created"
            assert service.verify_manifest(record["id"], observed_sha256=digest) is True
            assert service.verify_manifest(record["id"], observed_sha256="0" * 64) is False
            restored = service.mark_restored(record["id"])
            assert restored["status"] == "restored"
            assert restored["restored_at"] is not None

        print("backup_manifest_contract: PASS")
    finally:
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
