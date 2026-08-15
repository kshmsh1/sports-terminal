from __future__ import annotations

import json

from app.database import database_backend
from app.migrations import current_schema_version, discover_migrations, run_migrations
from app.runtime_config import load_runtime_config


def main() -> None:
    config = load_runtime_config()
    if config.production:
        config.assert_production_safe()
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
