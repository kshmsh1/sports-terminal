from __future__ import annotations

import hashlib
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from .database import DatabaseConnection, connect

BACKEND_ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS_DIR = BACKEND_ROOT / "migrations"


@dataclass(frozen=True)
class Migration:
    version: str
    name: str
    path: Path
    checksum: str
    sql: str


@dataclass(frozen=True)
class MigrationResult:
    applied: tuple[str, ...]
    already_applied: tuple[str, ...]


def discover_migrations(directory: Path = MIGRATIONS_DIR) -> list[Migration]:
    migrations: list[Migration] = []
    if not directory.exists():
        return migrations
    for path in sorted(directory.glob("*.sql")):
        stem = path.stem
        if "_" not in stem:
            raise RuntimeError(f"Invalid migration filename: {path.name}")
        version, name = stem.split("_", 1)
        if not version.isdigit():
            raise RuntimeError(f"Migration version must be numeric: {path.name}")
        sql = path.read_text(encoding="utf-8")
        checksum = hashlib.sha256(sql.encode("utf-8")).hexdigest()
        migrations.append(
            Migration(version=version, name=name, path=path, checksum=checksum, sql=sql)
        )
    versions = [migration.version for migration in migrations]
    if len(versions) != len(set(versions)):
        raise RuntimeError("Duplicate database migration versions are not allowed")
    return migrations


def _ensure_table(connection: DatabaseConnection) -> None:
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS schema_migrations (
          version TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          checksum TEXT NOT NULL,
          applied_at TEXT NOT NULL
        )
        """
    )


def _applied(connection: DatabaseConnection) -> dict[str, str]:
    _ensure_table(connection)
    rows = connection.execute(
        "SELECT version, checksum FROM schema_migrations ORDER BY version"
    ).fetchall()
    return {str(row["version"]): str(row["checksum"]) for row in rows}


def run_migrations(
    migrations: Iterable[Migration] | None = None,
    *,
    connection: DatabaseConnection | None = None,
) -> MigrationResult:
    owned = connection is None
    db = connection or connect()
    applied_now: list[str] = []
    already: list[str] = []
    try:
        current = _applied(db)
        for migration in migrations or discover_migrations():
            existing_checksum = current.get(migration.version)
            if existing_checksum:
                if existing_checksum != migration.checksum:
                    raise RuntimeError(
                        f"Migration {migration.version} checksum changed after application"
                    )
                already.append(migration.version)
                continue
            db.executescript(migration.sql)
            db.execute(
                "INSERT INTO schema_migrations (version, name, checksum, applied_at) "
                "VALUES (?, ?, ?, CURRENT_TIMESTAMP)",
                (migration.version, migration.name, migration.checksum),
            )
            applied_now.append(migration.version)
        db.commit()
        return MigrationResult(tuple(applied_now), tuple(already))
    except Exception:
        db.rollback()
        raise
    finally:
        if owned:
            db.close()


def current_schema_version() -> str:
    with connect() as connection:
        _ensure_table(connection)
        row = connection.execute(
            "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1"
        ).fetchone()
        return "unversioned" if row is None else str(row["version"])
