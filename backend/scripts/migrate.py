from __future__ import annotations

import json

from app import auth_api
from app.database import database_backend
from app.migrations import current_schema_version, discover_migrations, run_migrations
from app.production_bootstrap import bind_database_boundary
from app.runtime_config import load_runtime_config


def bootstrap_core_schema() -> None:
    """Create the legacy core tables that versioned migrations extend.

    Sports Terminal's pre-migration schema predates the numbered migration spine.
    A fresh managed database therefore needs the established core user/organization/
    auth tables once before migrations 0001+ can apply foreign keys. Rebinding first
    guarantees those legacy initializers use the configured managed database.
    """
    bind_database_boundary()
    auth_api.init_auth_db()


def main() -> None:
    config = load_runtime_config()
    if config.production:
        config.assert_production_safe()
    bootstrap_core_schema()
    migrations = discover_migrations()
    result = run_migrations(migrations)
    payload = {
        "database_backend": database_backend(),
        "target_version": migrations[-1].version if migrations else "unversioned",
        "schema_version": current_schema_version(),
        "applied": list(result.applied),
        "already_applied": list(result.already_applied),
    }
    print(json.dumps(payload, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
