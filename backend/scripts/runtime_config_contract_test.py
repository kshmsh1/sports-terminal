from __future__ import annotations

import os
from contextlib import contextmanager

from app.runtime_config import load_runtime_config


@contextmanager
def env(**values: str | None):
    previous = {key: os.environ.get(key) for key in values}
    try:
        for key, value in values.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        yield
    finally:
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


def main() -> None:
    with env(
        SPORTS_TERMINAL_ENV="development",
        SPORTS_TERMINAL_DATABASE_URL=None,
        DATABASE_URL=None,
        SPORTS_TERMINAL_BILLING_MODE="disabled",
    ):
        config = load_runtime_config()
        assert config.database_scheme == "sqlite"
        assert config.auto_migrate is True
        assert config.billing_mode == "disabled"
        assert config.production_errors() == []

    secret = "x" * 40
    with env(
        SPORTS_TERMINAL_ENV="production",
        SPORTS_TERMINAL_DATABASE_URL="postgresql://user:pass@db.example/sports_terminal",
        SPORTS_TERMINAL_CORS_ORIGINS="https://terminal.example",
        SPORTS_TERMINAL_ALLOWED_HOSTS="terminal.example,api.terminal.example",
        SPORTS_TERMINAL_SESSION_PEPPER=secret,
        SPORTS_TERMINAL_MFA_ENCRYPTION_KEY=secret,
        SPORTS_TERMINAL_RELEASE_SIGNING_SECRET=secret,
        SPORTS_TERMINAL_BACKUP_SIGNING_SECRET=secret,
        SPORTS_TERMINAL_BILLING_MODE="disabled",
    ):
        config = load_runtime_config()
        assert config.database_scheme == "postgresql"
        assert config.production_errors() == []
        config.assert_production_safe()

    with env(
        SPORTS_TERMINAL_ENV="production",
        SPORTS_TERMINAL_DATABASE_URL="sqlite:///tmp.db",
        SPORTS_TERMINAL_CORS_ORIGINS="*",
        SPORTS_TERMINAL_ALLOWED_HOSTS="*",
        SPORTS_TERMINAL_SESSION_PEPPER="short",
        SPORTS_TERMINAL_MFA_ENCRYPTION_KEY="short",
        SPORTS_TERMINAL_RELEASE_SIGNING_SECRET="",
        SPORTS_TERMINAL_BACKUP_SIGNING_SECRET="",
        SPORTS_TERMINAL_BILLING_MODE="live",
        SPORTS_TERMINAL_BILLING_WEBHOOK_SECRET="",
    ):
        errors = load_runtime_config().production_errors()
        assert any("PostgreSQL" in item for item in errors)
        assert any("CORS" in item for item in errors)
        assert any("allowed hosts" in item for item in errors)
        assert any("SESSION_PEPPER" in item for item in errors)
        assert any("MFA_ENCRYPTION_KEY" in item for item in errors)
        assert any("RELEASE_SIGNING_SECRET" in item for item in errors)
        assert any("BACKUP_SIGNING_SECRET" in item for item in errors)
        assert any("live billing" in item for item in errors)

    print("runtime_config_contract: PASS")


if __name__ == "__main__":
    main()
