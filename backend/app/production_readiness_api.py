from __future__ import annotations

import os
from typing import Any

from fastapi import APIRouter

from .database import connect, database_backend, database_location, list_tables
from .migrations import current_schema_version, discover_migrations
from .runtime_config import load_runtime_config

router = APIRouter(prefix="/v2/operations", tags=["production-operations"])

REQUIRED_PRODUCTION_TABLES = {
    "schema_migrations",
    "auth_sessions",
    "auth_security_events",
    "auth_delivery_tokens",
    "auth_login_challenges",
    "auth_session_security",
    "delivery_outbox",
    "organization_security_policies",
    "sso_connections",
    "sso_login_states",
    "billing_webhook_events",
    "entitlement_grants",
    "certified_releases",
    "release_activations",
    "platform_audit_events",
    "backup_manifests",
    "rate_limit_buckets",
}


def production_readiness_payload() -> dict[str, Any]:
    config = load_runtime_config()
    target = discover_migrations()
    target_version = target[-1].version if target else "unversioned"
    schema_version = current_schema_version()
    with connect() as connection:
        tables = set(list_tables(connection))
    missing_tables = sorted(REQUIRED_PRODUCTION_TABLES - tables)
    config_errors = config.production_errors()
    require_verification = os.getenv(
        "SPORTS_TERMINAL_REQUIRE_EMAIL_VERIFICATION", "false"
    ).lower() == "true"
    email_provider = os.getenv("SPORTS_TERMINAL_EMAIL_PROVIDER", "disabled").lower()
    object_store = os.getenv("SPORTS_TERMINAL_OBJECT_STORE", "disabled").lower()
    checks = {
        "production_configuration": not config_errors,
        "managed_postgresql": (not config.production) or database_backend() == "postgresql",
        "schema_current": schema_version == target_version,
        "required_tables": not missing_tables,
        "billing_fail_closed": config.billing_mode in {"disabled", "test", "live"},
        "security_email_delivery": (
            not config.production
            or not require_verification
            or email_provider == "http"
        ),
        "durable_object_storage": (
            not config.production or object_store == "http"
        ),
    }
    ready = all(checks.values())
    return {
        "status": "ready" if ready else "blocked",
        "environment": config.environment,
        "database": {
            "backend": database_backend(),
            "location": database_location(),
            "schema_version": schema_version,
            "target_schema_version": target_version,
        },
        "checks": checks,
        "configuration_errors": config_errors,
        "missing_tables": missing_tables,
        "billing_mode": config.billing_mode,
        "email_provider": email_provider,
        "object_store": object_store,
        "automatic_migrations": config.auto_migrate,
    }


@router.get("/production-readiness")
def production_readiness() -> dict[str, Any]:
    return production_readiness_payload()


@router.get("/database")
def database_status() -> dict[str, Any]:
    config = load_runtime_config()
    with connect() as connection:
        tables = list_tables(connection)
    return {
        "backend": database_backend(),
        "location": database_location(),
        "schema_version": current_schema_version(),
        "table_count": len(tables),
        "environment": config.environment,
        "auto_migrate": config.auto_migrate,
    }
