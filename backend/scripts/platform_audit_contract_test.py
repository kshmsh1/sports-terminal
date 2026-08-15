from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import database, platform_audit
from app.migrations import run_migrations


def main() -> None:
    previous = os.environ.get("SPORTS_TERMINAL_DATABASE_URL")
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "audit.db"
            platform_audit.connect = database.connect
            with database.connect() as connection:
                connection.execute(
                    "CREATE TABLE users (id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL)"
                )
            run_migrations()
            log = platform_audit.PlatformAuditLog()
            first = log.record(
                actor_type="user",
                actor_id="u1",
                action="release.certify",
                object_type="release",
                object_id="r1",
                metadata={"season": "2025-26"},
            )
            second = log.record(
                actor_type="system",
                action="release.activate",
                object_type="release",
                object_id="r1",
            )
            assert first["previous_event_sha256"] is None
            assert second["previous_event_sha256"] == first["event_sha256"]
            assert log.verify().valid is True

            with database.connect() as connection:
                connection.execute(
                    "UPDATE platform_audit_events SET action = 'tampered' WHERE id = ?",
                    (first["id"],),
                )
            verification = log.verify()
            assert verification.valid is False
            assert verification.first_invalid_id == first["id"]

        print("platform_audit_contract: PASS")
    finally:
        if previous is None:
            os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        else:
            os.environ["SPORTS_TERMINAL_DATABASE_URL"] = previous


if __name__ == "__main__":
    main()
