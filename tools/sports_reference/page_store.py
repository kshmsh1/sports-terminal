from __future__ import annotations

import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterator

from .table_parser import ParsedPage


class SportsReferencePageStore:
    """SQLite-backed queue and normalized table store for resumable collection."""

    def __init__(self, database_path: str | Path) -> None:
        self.database_path = Path(database_path)
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        self._initialize()

    @contextmanager
    def connect(self) -> Iterator[sqlite3.Connection]:
        connection = sqlite3.connect(self.database_path)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA journal_mode = WAL")
        try:
            yield connection
            connection.commit()
        finally:
            connection.close()

    def _initialize(self) -> None:
        with self.connect() as db:
            db.executescript(
                """
                CREATE TABLE IF NOT EXISTS pages (
                  url TEXT PRIMARY KEY,
                  page_family TEXT NOT NULL,
                  status TEXT NOT NULL DEFAULT 'queued',
                  depth INTEGER NOT NULL DEFAULT 0,
                  discovered_from TEXT,
                  attempts INTEGER NOT NULL DEFAULT 0,
                  title TEXT,
                  fetched_at TEXT,
                  source_sha256 TEXT,
                  cache_path TEXT,
                  table_count INTEGER NOT NULL DEFAULT 0,
                  link_count INTEGER NOT NULL DEFAULT 0,
                  last_error TEXT,
                  updated_at TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_pages_status_depth
                  ON pages(status, depth, url);

                CREATE TABLE IF NOT EXISTS tables (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  page_url TEXT NOT NULL,
                  table_id TEXT NOT NULL,
                  ordinal INTEGER NOT NULL,
                  caption TEXT,
                  columns_json TEXT NOT NULL,
                  row_count INTEGER NOT NULL,
                  UNIQUE(page_url, table_id, ordinal),
                  FOREIGN KEY(page_url) REFERENCES pages(url) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS table_rows (
                  table_pk INTEGER NOT NULL,
                  row_index INTEGER NOT NULL,
                  source_row_index INTEGER,
                  row_class TEXT,
                  values_json TEXT NOT NULL,
                  links_json TEXT NOT NULL,
                  PRIMARY KEY(table_pk, row_index),
                  FOREIGN KEY(table_pk) REFERENCES tables(id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS discovered_links (
                  source_url TEXT NOT NULL,
                  target_url TEXT NOT NULL,
                  page_family TEXT NOT NULL,
                  anchor_text TEXT,
                  PRIMARY KEY(source_url, target_url)
                );

                CREATE TABLE IF NOT EXISTS runs (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  started_at TEXT NOT NULL,
                  finished_at TEXT,
                  mode TEXT NOT NULL,
                  configuration_json TEXT NOT NULL,
                  summary_json TEXT
                );
                """
            )

    def enqueue(
        self,
        url: str,
        page_family: str,
        *,
        depth: int = 0,
        discovered_from: str | None = None,
    ) -> bool:
        now = datetime.now(timezone.utc).isoformat()
        with self.connect() as db:
            cursor = db.execute(
                """
                INSERT OR IGNORE INTO pages(
                  url, page_family, status, depth, discovered_from, updated_at
                ) VALUES (?, ?, 'queued', ?, ?, ?)
                """,
                (url, page_family, depth, discovered_from, now),
            )
            return cursor.rowcount > 0

    def next_page(self, *, max_depth: int, families: set[str]) -> sqlite3.Row | None:
        placeholders = ",".join("?" for _ in families)
        params = [max_depth, *sorted(families)]
        with self.connect() as db:
            row = db.execute(
                f"""
                SELECT * FROM pages
                WHERE status = 'queued'
                  AND depth <= ?
                  AND page_family IN ({placeholders})
                ORDER BY depth, url
                LIMIT 1
                """,
                params,
            ).fetchone()
            if row is None:
                return None
            db.execute(
                """
                UPDATE pages
                SET status = 'fetching', attempts = attempts + 1, updated_at = ?
                WHERE url = ?
                """,
                (datetime.now(timezone.utc).isoformat(), row["url"]),
            )
            return row

    def save_page(
        self,
        *,
        url: str,
        parsed: ParsedPage,
        fetched_at: str,
        source_sha256: str,
        cache_path: str,
    ) -> None:
        now = datetime.now(timezone.utc).isoformat()
        with self.connect() as db:
            db.execute("DELETE FROM tables WHERE page_url = ?", (url,))
            db.execute("DELETE FROM discovered_links WHERE source_url = ?", (url,))
            for table in parsed.tables:
                cursor = db.execute(
                    """
                    INSERT INTO tables(
                      page_url, table_id, ordinal, caption, columns_json, row_count
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (
                        url,
                        table.table_id,
                        table.ordinal,
                        table.caption,
                        json.dumps(table.columns, separators=(",", ":")),
                        len(table.rows),
                    ),
                )
                table_pk = int(cursor.lastrowid)
                db.executemany(
                    """
                    INSERT INTO table_rows(
                      table_pk, row_index, source_row_index, row_class,
                      values_json, links_json
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    [
                        (
                            table_pk,
                            row["rowIndex"],
                            row["sourceRowIndex"],
                            row["rowClass"],
                            json.dumps(row["values"], separators=(",", ":"), ensure_ascii=False),
                            json.dumps(row["links"], separators=(",", ":"), ensure_ascii=False),
                        )
                        for row in table.rows
                    ],
                )
            db.executemany(
                """
                INSERT OR REPLACE INTO discovered_links(
                  source_url, target_url, page_family, anchor_text
                ) VALUES (?, ?, ?, ?)
                """,
                [
                    (url, link["url"], link["pageFamily"], link["anchorText"])
                    for link in parsed.discovered_links
                ],
            )
            db.execute(
                """
                UPDATE pages
                SET status = 'complete', title = ?, fetched_at = ?,
                    source_sha256 = ?, cache_path = ?, table_count = ?,
                    link_count = ?, last_error = NULL, updated_at = ?
                WHERE url = ?
                """,
                (
                    parsed.title,
                    fetched_at,
                    source_sha256,
                    cache_path,
                    len(parsed.tables),
                    len(parsed.discovered_links),
                    now,
                    url,
                ),
            )

    def mark_failed(self, url: str, error: str, *, terminal: bool = True) -> None:
        status = "failed" if terminal else "queued"
        with self.connect() as db:
            db.execute(
                """
                UPDATE pages
                SET status = ?, last_error = ?, updated_at = ?
                WHERE url = ?
                """,
                (status, error[:2000], datetime.now(timezone.utc).isoformat(), url),
            )

    def reset_fetching(self) -> int:
        with self.connect() as db:
            cursor = db.execute(
                "UPDATE pages SET status = 'queued' WHERE status = 'fetching'"
            )
            return cursor.rowcount

    def status(self) -> dict[str, object]:
        with self.connect() as db:
            page_counts = {
                row["status"]: row["count"]
                for row in db.execute(
                    "SELECT status, COUNT(*) AS count FROM pages GROUP BY status"
                )
            }
            table_count = db.execute("SELECT COUNT(*) FROM tables").fetchone()[0]
            row_count = db.execute("SELECT COUNT(*) FROM table_rows").fetchone()[0]
            link_count = db.execute("SELECT COUNT(*) FROM discovered_links").fetchone()[0]
            by_family = {
                row["page_family"]: row["count"]
                for row in db.execute(
                    "SELECT page_family, COUNT(*) AS count FROM pages GROUP BY page_family"
                )
            }
        return {
            "database": str(self.database_path),
            "pages": page_counts,
            "pageFamilies": by_family,
            "tables": table_count,
            "rows": row_count,
            "links": link_count,
        }

    def export_jsonl(self, output_dir: str | Path) -> dict[str, int]:
        output = Path(output_dir)
        output.mkdir(parents=True, exist_ok=True)
        counts = {"pages": 0, "tables": 0, "rows": 0, "links": 0}
        with self.connect() as db:
            for name, query in (
                ("pages", "SELECT * FROM pages ORDER BY url"),
                ("tables", "SELECT * FROM tables ORDER BY page_url, ordinal"),
                ("rows", "SELECT * FROM table_rows ORDER BY table_pk, row_index"),
                ("links", "SELECT * FROM discovered_links ORDER BY source_url, target_url"),
            ):
                path = output / f"{name}.jsonl"
                with path.open("w", encoding="utf-8") as handle:
                    for row in db.execute(query):
                        handle.write(json.dumps(dict(row), ensure_ascii=False) + "\n")
                        counts[name] += 1
        return counts
