from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import database, platform_audit
from app.migrations import discover_migrations
from app.service_health import ServiceHealthEvaluator


def main() -> None:
    original = {key: os.environ.get(key) for key in (
        "SPORTS_TERMINAL_DATABASE_URL",
        "SPORTS_TERMINAL_ENV",
    )}
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_ENV"] = "development"
        target_schema = discover_migrations()[-1].version
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "health.db"
            platform_audit.connect = database.connect
            with database.connect() as connection:
                connection.executescript(
                    f"""
                    CREATE TABLE schema_migrations (
                      version TEXT PRIMARY KEY, name TEXT NOT NULL,
                      checksum TEXT NOT NULL, applied_at TEXT NOT NULL
                    );
                    INSERT INTO schema_migrations VALUES ('{target_schema}', 'current', 'checksum', CURRENT_TIMESTAMP);
                    CREATE TABLE platform_audit_events (
                      id TEXT PRIMARY KEY, actor_type TEXT NOT NULL, actor_id TEXT,
                      action TEXT NOT NULL, object_type TEXT, object_id TEXT,
                      request_id TEXT, metadata TEXT NOT NULL DEFAULT '{{}}',
                      previous_event_sha256 TEXT, event_sha256 TEXT, recorded_at TEXT NOT NULL
                    );
                    """
                )
            snapshot = ServiceHealthEvaluator().snapshot()
            assert snapshot.status == "healthy"
            checks = {check.name: check for check in snapshot.checks}
            assert checks["database"].healthy is True
            assert checks["schema"].healthy is True
            assert checks["audit_chain"].healthy is True
            assert checks["runtime_configuration"].healthy is True
            assert f"current={target_schema} target={target_schema}" in checks["schema"].detail

        print("service_health_contract: PASS")
    finally:
        for key, value in original.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
