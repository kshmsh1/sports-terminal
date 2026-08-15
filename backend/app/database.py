from __future__ import annotations

import os
import re
import sqlite3
from collections.abc import Iterable, Iterator, Mapping
from pathlib import Path
from typing import Any

from .runtime_config import load_runtime_config

BACKEND_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SQLITE_PATH = Path(
    os.getenv("SPORTS_TERMINAL_DB_PATH", BACKEND_ROOT / ".data" / "sports_terminal.db")
)


class CompatRow(dict[str, Any]):
    """Mapping row that also preserves legacy integer-index access."""

    def __getitem__(self, key: str | int) -> Any:
        if isinstance(key, int):
            return list(self.values())[key]
        return super().__getitem__(key)


class CompatCursor:
    def __init__(self, cursor: Any, *, postgres: bool) -> None:
        self._cursor = cursor
        self._postgres = postgres

    @property
    def rowcount(self) -> int:
        return int(getattr(self._cursor, "rowcount", -1))

    @property
    def lastrowid(self) -> Any:
        return getattr(self._cursor, "lastrowid", None)

    def _columns(self) -> list[str]:
        description = getattr(self._cursor, "description", None) or []
        return [getattr(item, "name", item[0]) for item in description]

    def _wrap(self, row: Any) -> CompatRow | None:
        if row is None:
            return None
        if isinstance(row, Mapping):
            return CompatRow({str(key): value for key, value in row.items()})
        columns = self._columns()
        return CompatRow({column: row[index] for index, column in enumerate(columns)})

    def fetchone(self) -> CompatRow | None:
        return self._wrap(self._cursor.fetchone())

    def fetchall(self) -> list[CompatRow]:
        return [self._wrap(row) for row in self._cursor.fetchall() if row is not None]  # type: ignore[misc]

    def __iter__(self) -> Iterator[CompatRow]:
        for row in self._cursor:
            wrapped = self._wrap(row)
            if wrapped is not None:
                yield wrapped


class DatabaseConnection:
    def __init__(self, raw: Any, *, backend: str) -> None:
        self.raw = raw
        self.backend = backend

    def __enter__(self) -> "DatabaseConnection":
        return self

    def __exit__(self, exc_type: Any, exc: Any, tb: Any) -> bool:
        if exc_type is None:
            self.commit()
        else:
            self.rollback()
        self.close()
        return False

    def execute(self, sql: str, params: Iterable[Any] | Mapping[str, Any] = ()) -> CompatCursor:
        translated = translate_sql(sql, backend=self.backend)
        cursor = self.raw.execute(translated, params)
        return CompatCursor(cursor, postgres=self.backend == "postgresql")

    def executemany(self, sql: str, params: Iterable[Iterable[Any]]) -> CompatCursor:
        translated = translate_sql(sql, backend=self.backend)
        cursor = self.raw.executemany(translated, params)
        return CompatCursor(cursor, postgres=self.backend == "postgresql")

    def executescript(self, script: str) -> None:
        if self.backend == "sqlite":
            self.raw.executescript(script)
            return
        for statement in split_sql_script(script):
            self.raw.execute(translate_sql(statement, backend=self.backend))

    def commit(self) -> None:
        self.raw.commit()

    def rollback(self) -> None:
        self.raw.rollback()

    def close(self) -> None:
        self.raw.close()


_INSERT_OR_IGNORE = re.compile(r"\bINSERT\s+OR\s+IGNORE\s+INTO\b", re.IGNORECASE)
_AUTOINCREMENT_PK = re.compile(
    r"\bINTEGER\s+PRIMARY\s+KEY\s+AUTOINCREMENT\b", re.IGNORECASE
)


def translate_sql(sql: str, *, backend: str) -> str:
    if backend != "postgresql":
        return sql
    statement = sql.strip()
    if not statement:
        return statement
    if statement.upper().startswith("PRAGMA "):
        return "SELECT 1"
    if "sqlite_master" in statement:
        statement = re.sub(
            r"SELECT\s+name\s+FROM\s+sqlite_master\s+WHERE\s+type\s*=\s*'table'\s+ORDER\s+BY\s+name",
            "SELECT table_name AS name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name",
            statement,
            flags=re.IGNORECASE,
        )
    ignored = bool(_INSERT_OR_IGNORE.search(statement))
    statement = _INSERT_OR_IGNORE.sub("INSERT INTO", statement)
    statement = _AUTOINCREMENT_PK.sub("BIGSERIAL PRIMARY KEY", statement)
    statement = statement.replace("datetime('now')", "CURRENT_TIMESTAMP")
    statement = statement.replace("?", "%s")
    if ignored and "ON CONFLICT" not in statement.upper():
        suffix = ";" if statement.endswith(";") else ""
        statement = statement.removesuffix(";") + " ON CONFLICT DO NOTHING" + suffix
    return statement


def split_sql_script(script: str) -> list[str]:
    """Split repository-owned migration/schema SQL on statement semicolons.

    The current schema contains no stored procedures or dollar-quoted functions;
    keeping this splitter deliberately small avoids pretending to be a SQL parser.
    """
    statements: list[str] = []
    buffer: list[str] = []
    in_single = False
    in_double = False
    for char in script:
        if char == "'" and not in_double:
            in_single = not in_single
        elif char == '"' and not in_single:
            in_double = not in_double
        if char == ";" and not in_single and not in_double:
            value = "".join(buffer).strip()
            if value:
                statements.append(value)
            buffer = []
        else:
            buffer.append(char)
    tail = "".join(buffer).strip()
    if tail:
        statements.append(tail)
    return statements


def connect() -> DatabaseConnection:
    config = load_runtime_config()
    if config.database_scheme == "postgresql":
        try:
            import psycopg
        except ImportError as error:  # pragma: no cover - exercised by deployment
            raise RuntimeError(
                "PostgreSQL DATABASE_URL configured but psycopg is not installed"
            ) from error
        raw = psycopg.connect(config.database_url)
        return DatabaseConnection(raw, backend="postgresql")

    DEFAULT_SQLITE_PATH.parent.mkdir(parents=True, exist_ok=True)
    raw = sqlite3.connect(DEFAULT_SQLITE_PATH)
    raw.row_factory = sqlite3.Row
    raw.execute("PRAGMA foreign_keys = ON")
    return DatabaseConnection(raw, backend="sqlite")


def database_backend() -> str:
    return load_runtime_config().database_scheme


def database_location() -> str:
    config = load_runtime_config()
    if config.database_scheme == "postgresql":
        return "managed-postgresql"
    return str(DEFAULT_SQLITE_PATH)


def list_tables(connection: DatabaseConnection) -> list[str]:
    if connection.backend == "postgresql":
        rows = connection.execute(
            "SELECT table_name AS name FROM information_schema.tables "
            "WHERE table_schema = 'public' ORDER BY table_name"
        ).fetchall()
    else:
        rows = connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"
        ).fetchall()
    return [str(row["name"]) for row in rows]
