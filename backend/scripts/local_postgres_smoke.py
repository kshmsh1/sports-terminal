from __future__ import annotations

import os


def main() -> None:
    os.environ.setdefault(
        "SPORTS_TERMINAL_DATABASE_URL",
        "postgresql://sports_terminal:local-development-only@127.0.0.1:54329/sports_terminal",
    )
    os.environ.setdefault("SPORTS_TERMINAL_ENV", "development")

    from app import database
    from app import main as legacy_main
    from app.auth_api import init_auth_db
    from app.migrations import current_schema_version, discover_migrations, run_migrations
    from app.production_bootstrap import bind_database_boundary

    if database.database_backend() != "postgresql":
        raise RuntimeError("local Postgres smoke requires a PostgreSQL DATABASE_URL")

    bind_database_boundary()
    legacy_main.init_db()
    init_auth_db()
    result = run_migrations()
    target = discover_migrations()[-1].version
    if current_schema_version() != target:
        raise RuntimeError("local Postgres schema is not current")

    with database.connect() as connection:
        version = connection.execute("SELECT version() AS version").fetchone()
        tables = database.list_tables(connection)
        if version is None or "PostgreSQL" not in str(version["version"]):
            raise RuntimeError("database did not identify as PostgreSQL")
        required = {
            "users",
            "auth_sessions",
            "auth_session_security",
            "organization_security_policies",
            "certified_releases",
            "backup_manifests",
        }
        missing = sorted(required.difference(tables))
        if missing:
            raise RuntimeError(f"local Postgres is missing production tables: {missing}")

    print(
        "local_postgres_smoke: PASS "
        f"schema={target} applied={list(result.applied)} already={list(result.already_applied)}"
    )


if __name__ == "__main__":
    main()
