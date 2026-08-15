from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import database, platform_audit
from app.metrics_api import metrics_prometheus, operational_metrics


def main() -> None:
    original = os.environ.get("SPORTS_TERMINAL_DATABASE_URL")
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "metrics.db"
            platform_audit.connect = database.connect
            with database.connect() as connection:
                connection.executescript(
                    """
                    CREATE TABLE schema_migrations (
                      version TEXT PRIMARY KEY, name TEXT NOT NULL,
                      checksum TEXT NOT NULL, applied_at TEXT NOT NULL
                    );
                    INSERT INTO schema_migrations VALUES ('0005', 'current', 'checksum', CURRENT_TIMESTAMP);
                    CREATE TABLE platform_audit_events (
                      id TEXT PRIMARY KEY, actor_type TEXT NOT NULL, actor_id TEXT,
                      action TEXT NOT NULL, object_type TEXT, object_id TEXT,
                      request_id TEXT, metadata TEXT NOT NULL DEFAULT '{}',
                      previous_event_sha256 TEXT, event_sha256 TEXT, recorded_at TEXT NOT NULL
                    );
                    CREATE TABLE auth_sessions (
                      token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL, expires_at TEXT NOT NULL,
                      created_at TEXT NOT NULL, last_seen_at TEXT NOT NULL, revoked_at TEXT
                    );
                    CREATE TABLE delivery_outbox (
                      id TEXT PRIMARY KEY, status TEXT NOT NULL, created_at TEXT NOT NULL
                    );
                    INSERT INTO delivery_outbox VALUES ('mail_1', 'failed', CURRENT_TIMESTAMP);
                    CREATE TABLE billing_webhook_events (
                      provider_event_id TEXT PRIMARY KEY, status TEXT NOT NULL
                    );
                    INSERT INTO billing_webhook_events VALUES ('evt_1', 'failed');
                    CREATE TABLE certified_releases (id TEXT PRIMARY KEY, status TEXT NOT NULL);
                    INSERT INTO certified_releases VALUES ('rel_1', 'active');
                    CREATE TABLE backup_manifests (
                      id TEXT PRIMARY KEY, status TEXT NOT NULL, created_at TEXT NOT NULL
                    );
                    INSERT INTO backup_manifests VALUES ('bak_1', 'verified', CURRENT_TIMESTAMP);
                    """
                )
            metrics = operational_metrics()
            assert metrics["sports_terminal_health"] == 1.0
            assert metrics["sports_terminal_failed_deliveries"] == 1.0
            assert metrics["sports_terminal_failed_billing_webhooks"] == 1.0
            assert metrics["sports_terminal_active_releases"] == 1.0
            assert metrics["sports_terminal_verified_backups"] == 1.0
            response = metrics_prometheus()
            body = response.body.decode("utf-8")
            assert "sports_terminal_failed_deliveries 1.0" in body
            assert "text/plain" in response.media_type

        print("metrics_api_contract: PASS")
    finally:
        if original is None:
            os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        else:
            os.environ["SPORTS_TERMINAL_DATABASE_URL"] = original


if __name__ == "__main__":
    main()
