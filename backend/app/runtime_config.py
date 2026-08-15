from __future__ import annotations

import os
from dataclasses import dataclass
from urllib.parse import urlparse


TRUE_VALUES = {"1", "true", "yes", "on"}


def _bool(name: str, default: bool = False) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in TRUE_VALUES


def _csv(name: str, default: str = "") -> tuple[str, ...]:
    return tuple(value.strip() for value in os.getenv(name, default).split(",") if value.strip())


@dataclass(frozen=True)
class RuntimeConfig:
    environment: str
    database_url: str
    database_pool_size: int
    auto_migrate: bool
    cors_origins: tuple[str, ...]
    allowed_hosts: tuple[str, ...]
    session_pepper: str
    auth_session_days: int
    rate_limits_enabled: bool
    hsts_enabled: bool
    billing_mode: str
    billing_webhook_secret: str
    release_signing_secret: str
    backup_signing_secret: str
    trust_proxy_headers: bool

    @property
    def production(self) -> bool:
        return self.environment == "production"

    @property
    def database_scheme(self) -> str:
        if not self.database_url:
            return "sqlite"
        scheme = urlparse(self.database_url).scheme.lower()
        if scheme in {"postgres", "postgresql", "postgresql+psycopg"}:
            return "postgresql"
        if scheme in {"sqlite", "sqlite3"}:
            return "sqlite"
        return scheme

    def production_errors(self) -> list[str]:
        if not self.production:
            return []
        errors: list[str] = []
        if self.database_scheme != "postgresql":
            errors.append("production requires a PostgreSQL DATABASE_URL")
        if not self.session_pepper or len(self.session_pepper) < 32:
            errors.append("SPORTS_TERMINAL_SESSION_PEPPER must contain at least 32 characters")
        if not self.release_signing_secret or len(self.release_signing_secret) < 32:
            errors.append("SPORTS_TERMINAL_RELEASE_SIGNING_SECRET must contain at least 32 characters")
        if not self.backup_signing_secret or len(self.backup_signing_secret) < 32:
            errors.append("SPORTS_TERMINAL_BACKUP_SIGNING_SECRET must contain at least 32 characters")
        if not self.cors_origins or "*" in self.cors_origins:
            errors.append("production CORS origins must be explicit and cannot include *")
        if not self.allowed_hosts or "*" in self.allowed_hosts:
            errors.append("production allowed hosts must be explicit and cannot include *")
        if self.billing_mode == "live" and len(self.billing_webhook_secret) < 24:
            errors.append("live billing requires SPORTS_TERMINAL_BILLING_WEBHOOK_SECRET")
        return errors

    def assert_production_safe(self) -> None:
        errors = self.production_errors()
        if errors:
            raise RuntimeError("Unsafe Sports Terminal production configuration: " + "; ".join(errors))


def load_runtime_config() -> RuntimeConfig:
    environment = os.getenv("SPORTS_TERMINAL_ENV", "development").strip().lower()
    database_url = (
        os.getenv("SPORTS_TERMINAL_DATABASE_URL")
        or os.getenv("DATABASE_URL")
        or ""
    ).strip()
    billing_mode = os.getenv("SPORTS_TERMINAL_BILLING_MODE", "disabled").strip().lower()
    if billing_mode not in {"disabled", "test", "live"}:
        raise RuntimeError("SPORTS_TERMINAL_BILLING_MODE must be disabled, test, or live")
    return RuntimeConfig(
        environment=environment,
        database_url=database_url,
        database_pool_size=max(1, int(os.getenv("SPORTS_TERMINAL_DATABASE_POOL_SIZE", "8"))),
        auto_migrate=_bool("SPORTS_TERMINAL_AUTO_MIGRATE", default=environment != "production"),
        cors_origins=_csv("SPORTS_TERMINAL_CORS_ORIGINS", "*" if environment != "production" else ""),
        allowed_hosts=_csv("SPORTS_TERMINAL_ALLOWED_HOSTS", "*" if environment != "production" else ""),
        session_pepper=os.getenv("SPORTS_TERMINAL_SESSION_PEPPER", ""),
        auth_session_days=max(1, int(os.getenv("SPORTS_TERMINAL_AUTH_SESSION_DAYS", "30"))),
        rate_limits_enabled=_bool("SPORTS_TERMINAL_RATE_LIMITS", default=environment == "production"),
        hsts_enabled=_bool("SPORTS_TERMINAL_HSTS", default=environment == "production"),
        billing_mode=billing_mode,
        billing_webhook_secret=os.getenv("SPORTS_TERMINAL_BILLING_WEBHOOK_SECRET", ""),
        release_signing_secret=os.getenv("SPORTS_TERMINAL_RELEASE_SIGNING_SECRET", ""),
        backup_signing_secret=os.getenv("SPORTS_TERMINAL_BACKUP_SIGNING_SECRET", ""),
        trust_proxy_headers=_bool("SPORTS_TERMINAL_TRUST_PROXY_HEADERS", default=False),
    )
