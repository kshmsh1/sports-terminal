from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import database, environment_promotions, platform_audit
from app.environment_promotions import EnvironmentPromotionError, EnvironmentPromotionService


def main() -> None:
    original = os.environ.get("SPORTS_TERMINAL_DATABASE_URL")
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "promotion.db"
            environment_promotions.connect = database.connect
            platform_audit.connect = database.connect
            with database.connect() as connection:
                connection.executescript(
                    """
                    CREATE TABLE schema_migrations (
                      version TEXT PRIMARY KEY, name TEXT NOT NULL,
                      checksum TEXT NOT NULL, applied_at TEXT NOT NULL
                    );
                    INSERT INTO schema_migrations VALUES ('0005', 'test', 'checksum', CURRENT_TIMESTAMP);
                    CREATE TABLE certified_releases (
                      id TEXT PRIMARY KEY, status TEXT NOT NULL
                    );
                    INSERT INTO certified_releases VALUES ('rel_1', 'certified');
                    CREATE TABLE deployment_environments (
                      environment TEXT PRIMARY KEY, release_id TEXT,
                      database_schema_version TEXT, status TEXT NOT NULL,
                      deployed_at TEXT, updated_at TEXT NOT NULL
                    );
                    INSERT INTO deployment_environments VALUES (
                      'development', 'rel_1', '0005', 'healthy', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                    );
                    CREATE TABLE platform_audit_events (
                      id TEXT PRIMARY KEY, actor_type TEXT NOT NULL, actor_id TEXT,
                      action TEXT NOT NULL, object_type TEXT, object_id TEXT,
                      request_id TEXT, metadata TEXT NOT NULL DEFAULT '{}',
                      previous_event_sha256 TEXT, event_sha256 TEXT, recorded_at TEXT NOT NULL
                    );
                    """
                )
            service = EnvironmentPromotionService()
            staging = service.promote(
                source="development", target="staging", actor="usr_admin", reason="candidate verified"
            )
            assert staging.release_id == "rel_1"
            service.mark_healthy("staging", actor="usr_admin")
            production = service.promote(
                source="staging", target="production", actor="usr_admin", reason="staging checks passed"
            )
            assert production.release_id == "rel_1"
            with database.connect() as connection:
                row = connection.execute(
                    "SELECT release_id, status FROM deployment_environments WHERE environment = 'production'"
                ).fetchone()
                assert row is not None
                assert row["release_id"] == "rel_1"
                assert row["status"] == "promoted"
            assert platform_audit.PlatformAuditLog().verify().valid is True
            try:
                service.promote(
                    source="development", target="production", actor="usr_admin", reason="skip staging"
                )
            except EnvironmentPromotionError as error:
                assert "development" in str(error)
            else:
                raise AssertionError("direct development-to-production promotion must be blocked")

        print("environment_promotion_contract: PASS")
    finally:
        if original is None:
            os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        else:
            os.environ["SPORTS_TERMINAL_DATABASE_URL"] = original


if __name__ == "__main__":
    main()
