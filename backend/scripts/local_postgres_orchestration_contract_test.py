from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend"


def main() -> None:
    compose = (BACKEND / "docker-compose.postgres.yml").read_text(encoding="utf-8")
    smoke = (BACKEND / "scripts" / "local_postgres_smoke.py").read_text(encoding="utf-8")

    for token in (
        "postgres:17-alpine",
        'profiles: ["local-postgres"]',
        "127.0.0.1:54329:5432",
        "local-development-only",
        'restart: "no"',
    ):
        assert token in compose
    for forbidden in ("aws", "railway", "render.com", "supabase", "neon.tech"):
        assert forbidden not in compose.lower()

    assert "postgresql://sports_terminal:local-development-only@127.0.0.1:54329" in smoke
    assert "bind_database_boundary()" in smoke
    assert "legacy_main.init_db()" in smoke
    assert "run_migrations()" in smoke
    assert "database.list_tables(connection)" in smoke
    assert "local Postgres schema is not current" in smoke

    print("local_postgres_orchestration_contract: PASS")


if __name__ == "__main__":
    main()
