from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import database


def main() -> None:
    original_url = os.environ.get("SPORTS_TERMINAL_DATABASE_URL")
    original_path = os.environ.get("SPORTS_TERMINAL_DB_PATH")
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "contract.db"
            with database.connect() as connection:
                connection.executescript(
                    """
                    CREATE TABLE example (
                      id TEXT PRIMARY KEY,
                      label TEXT NOT NULL
                    );
                    CREATE TABLE second_table (
                      id TEXT PRIMARY KEY
                    );
                    """
                )
                connection.execute(
                    "INSERT INTO example (id, label) VALUES (?, ?)",
                    ("one", "First"),
                )
                row = connection.execute(
                    "SELECT id, label FROM example WHERE id = ?",
                    ("one",),
                ).fetchone()
                assert row is not None
                assert row["label"] == "First"
                assert row[0] == "one"
                assert database.list_tables(connection) == ["example", "second_table"]

        translated = database.translate_sql(
            "INSERT OR IGNORE INTO example (id, label) VALUES (?, ?);",
            backend="postgresql",
        )
        assert "INSERT INTO" in translated
        assert "%s" in translated
        assert "ON CONFLICT DO NOTHING" in translated
        assert "OR IGNORE" not in translated

        master = database.translate_sql(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
            backend="postgresql",
        )
        assert "information_schema.tables" in master
        assert "sqlite_master" not in master

        script = "CREATE TABLE a (id TEXT); CREATE TABLE b (label TEXT);"
        assert len(database.split_sql_script(script)) == 2
        print("database_contract: PASS")
    finally:
        if original_url is None:
            os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        else:
            os.environ["SPORTS_TERMINAL_DATABASE_URL"] = original_url
        if original_path is None:
            os.environ.pop("SPORTS_TERMINAL_DB_PATH", None)
        else:
            os.environ["SPORTS_TERMINAL_DB_PATH"] = original_path


if __name__ == "__main__":
    main()
