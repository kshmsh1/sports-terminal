from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import database
from app.production_bootstrap import bind_database_boundary, bootstrap
from app.runtime_config import RuntimeConfig


def _config() -> RuntimeConfig:
    return RuntimeConfig(
        environment="development",
        database_url="",
        database_pool_size=4,
        auto_migrate=True,
        cors_origins=("*",),
        allowed_hosts=("*",),
        session_pepper="",
        auth_session_days=30,
        rate_limits_enabled=False,
        hsts_enabled=False,
        billing_mode="disabled",
        billing_webhook_secret="",
        release_signing_secret="",
        backup_signing_secret="",
        trust_proxy_headers=False,
    )


def main() -> None:
    original_url = os.environ.get("SPORTS_TERMINAL_DATABASE_URL")
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "bootstrap.db"
            # The legacy core user table is an explicit dependency of migration 0002.
            with database.connect() as connection:
                connection.execute(
                    "CREATE TABLE users (id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL)"
                )
            rebound = bind_database_boundary()
            assert "app.database" in rebound
            status = bootstrap(_config())
            assert status.database_backend == "sqlite"
            assert status.schema_version == "0003"
            assert status.target_schema_version == "0003"
            assert status.auto_migrated is True

        print("production_bootstrap_contract: PASS")
    finally:
        if original_url is None:
            os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        else:
            os.environ["SPORTS_TERMINAL_DATABASE_URL"] = original_url


if __name__ == "__main__":
    main()
