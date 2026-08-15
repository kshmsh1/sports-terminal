from __future__ import annotations

import sys
from dataclasses import dataclass
from typing import Any

from .database import connect as production_connect
from .database import database_backend, database_location
from .migrations import current_schema_version, discover_migrations, run_migrations
from .runtime_config import RuntimeConfig, load_runtime_config


@dataclass(frozen=True)
class BootstrapStatus:
    environment: str
    database_backend: str
    database_location: str
    schema_version: str
    target_schema_version: str
    auto_migrated: bool
    rebound_modules: tuple[str, ...]


def bind_database_boundary() -> tuple[str, ...]:
    """Rebind legacy module-level `connect` imports to the production adapter.

    Existing route modules intentionally retain their current SQL/API surface. The
    binding happens once in launch composition so migrating persistence does not
    require a risky route-by-route rewrite.
    """
    rebound: list[str] = []
    for name, module in list(sys.modules.items()):
        if module is None or not (name == "app" or name.startswith("app.")):
            continue
        if hasattr(module, "connect"):
            setattr(module, "connect", production_connect)
            rebound.append(name)
    return tuple(sorted(set(rebound)))


def bootstrap(config: RuntimeConfig | None = None) -> BootstrapStatus:
    config = config or load_runtime_config()
    if config.production:
        config.assert_production_safe()

    rebound = bind_database_boundary()
    migrations = discover_migrations()
    target = migrations[-1].version if migrations else "unversioned"
    auto_migrated = False

    if config.auto_migrate:
        run_migrations(migrations)
        auto_migrated = bool(migrations)

    version = current_schema_version()
    if config.production and version != target:
        raise RuntimeError(
            f"Database schema is {version}; production requires {target}. "
            "Run `PYTHONPATH=backend python backend/scripts/migrate.py` before deployment."
        )

    return BootstrapStatus(
        environment=config.environment,
        database_backend=database_backend(),
        database_location=database_location(),
        schema_version=version,
        target_schema_version=target,
        auto_migrated=auto_migrated,
        rebound_modules=rebound,
    )


def status_payload(status: BootstrapStatus) -> dict[str, Any]:
    return {
        "environment": status.environment,
        "database_backend": status.database_backend,
        "database_location": status.database_location,
        "schema_version": status.schema_version,
        "target_schema_version": status.target_schema_version,
        "auto_migrated": status.auto_migrated,
        "rebound_modules": list(status.rebound_modules),
    }
