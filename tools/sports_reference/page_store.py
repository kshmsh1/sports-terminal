from __future__ import annotations

import gzip
import hashlib
import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterator

from .table_parser import ParsedPage


class SportsReferencePageStore:
    """SQLite queue and raw table warehouse for resumable historical collection."""

    def __init__(
        self,
        database_path: str | Path,
        snapshot_root: str | Path | None = None,
    ) -> None:
        self.database_path = Path(database_path)
        self.snapshot_root = Path(snapshot_root) if snapshot_root else self.database_path.parent / "snapshots"
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        self.snapshot_root.mkdir(parents=True, exist_ok=True)
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
                  canonical_url TEXT,
                  page_family TEXT NOT NULL,
                  source_key TEXT,
                  season_end_year INTEGER,
                  team_abbreviation TEXT,
                  priority INTEGER NOT NULL DEFAULT 100,
                  status TEXT NOT NULL DEFAULT 'queued',
                  depth INTEGER NOT NULL DEFAULT 0,
                  discovered_from TEXT,
                  attempts INTEGER NOT NULL DEFAULT 0,
                  title TEXT,
                  fetched_at TEXT,
                  source_sha256 TEXT,
                  status_code INTEGER,
                  content_type TEXT,
                  cache_path TEXT,
                  snapshot_path TEXT,
                  html_bytes INTEGER NOT NULL DEFAULT 0,
                  table_count INTEGER NOT NULL DEFAULT 0,
                  link_count INTEGER NOT NULL DEFAULT 0,
                  last_error TEXT,
                  updated_at TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_pages_status_priority_depth
                  ON pages(status, priority, depth, url);
                CREATE INDEX IF NOT EXISTS idx_pages_family_season
                  ON pages(page_family, season_end_year, status);
                CREATE INDEX IF NOT EXISTS idx_pages_source_key
                  ON pages(source_key);

                CREATE TABLE IF NOT EXISTS tables (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  page_url TEXT NOT NULL,
                  table_id TEXT NOT NULL,
                  ordinal INTEGER NOT NULL,
                  caption TEXT,
                  columns_json TEXT NOT NULL,
                  schema_hash TEXT NOT NULL DEFAULT '',
                  link_count INTEGER NOT NULL DEFAULT 0,
                  row_count INTEGER NOT NULL,
                  UNIQUE(page_url, table_id, ordinal),
                  FOREIGN KEY(page_url) REFERENCES pages(url) ON DELETE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_tables_table_id
                  ON tables(table_id);
                CREATE INDEX IF NOT EXISTS idx_tables_schema_hash
                  ON tables(table_id, schema_hash);

                CREATE TABLE IF NOT EXISTS table_rows (
                  table_pk INTEGER NOT NULL,
                  row_index INTEGER NOT NULL,
                  source_row_index INTEGER,
                  row_class TEXT,
                  section TEXT,
                  values_json TEXT NOT NULL,
                  display_json TEXT NOT NULL DEFAULT '{}',
                  links_json TEXT NOT NULL,
                  PRIMARY KEY(table_pk, row_index),
                  FOREIGN KEY(table_pk) REFERENCES tables(id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS discovered_links (
                  source_url TEXT NOT NULL,
                  target_url TEXT NOT NULL,
                  page_family TEXT NOT NULL,
                  source_key TEXT,
                  season_end_year INTEGER,
                  team_abbreviation TEXT,
                  priority INTEGER NOT NULL DEFAULT 100,
                  anchor_text TEXT,
                  PRIMARY KEY(source_url, target_url)
                );
                CREATE INDEX IF NOT EXISTS idx_discovered_links_source_key
                  ON discovered_links(source_key);

                CREATE TABLE IF NOT EXISTS source_entities (
                  source_key TEXT PRIMARY KEY,
                  page_family TEXT NOT NULL,
                  canonical_url TEXT NOT NULL,
                  season_end_year INTEGER,
                  team_abbreviation TEXT,
                  first_seen_at TEXT NOT NULL,
                  last_seen_at TEXT NOT NULL,
                  discovery_count INTEGER NOT NULL DEFAULT 1,
                  anchor_text TEXT
                );

                CREATE TABLE IF NOT EXISTS runs (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  run_key TEXT UNIQUE,
                  started_at TEXT NOT NULL,
                  finished_at TEXT,
                  mode TEXT NOT NULL,
                  status TEXT NOT NULL DEFAULT 'running',
                  configuration_json TEXT NOT NULL,
                  summary_json TEXT
                );
                """
            )
            self._migrate_existing_schema(db)

    def _migrate_existing_schema(self, db: sqlite3.Connection) -> None:
        for table, column, declaration in (
            ("pages", "canonical_url", "TEXT"),
            ("pages", "source_key", "TEXT"),
            ("pages", "season_end_year", "INTEGER"),
            ("pages", "team_abbreviation", "TEXT"),
            ("pages", "priority", "INTEGER NOT NULL DEFAULT 100"),
            ("pages", "status_code", "INTEGER"),
            ("pages", "content_type", "TEXT"),
            ("pages", "snapshot_path", "TEXT"),
            ("pages", "html_bytes", "INTEGER NOT NULL DEFAULT 0"),
            ("tables", "schema_hash", "TEXT NOT NULL DEFAULT ''"),
            ("tables", "link_count", "INTEGER NOT NULL DEFAULT 0"),
            ("table_rows", "section", "TEXT"),
            ("table_rows", "display_json", "TEXT NOT NULL DEFAULT '{}'"),
            ("discovered_links", "source_key", "TEXT"),
            ("discovered_links", "season_end_year", "INTEGER"),
            ("discovered_links", "team_abbreviation", "TEXT"),
            ("discovered_links", "priority", "INTEGER NOT NULL DEFAULT 100"),
            ("runs", "run_key", "TEXT"),
            ("runs", "status", "TEXT NOT NULL DEFAULT 'running'"),
        ):
            self._ensure_column(db, table, column, declaration)

    def _ensure_column(
        self,
        db: sqlite3.Connection,
        table: str,
        column: str,
        declaration: str,
    ) -> None:
        existing = {row["name"] for row in db.execute(f"PRAGMA table_info({table})")}
        if column not in existing:
            db.execute(f"ALTER TABLE {table} ADD COLUMN {column} {declaration}")

    def enqueue(
        self,
        url: str,
        page_family: str,
        *,
        depth: int = 0,
        discovered_from: str | None = None,
        priority: int = 100,
        source_key: str | None = None,
        season_end_year: int | None = None,
        team_abbreviation: str | None = None,
    ) -> bool:
        now = self._now()
        with self.connect() as db:
            cursor = db.execute(
                """
                INSERT OR IGNORE INTO pages(
                  url, canonical_url, page_family, source_key, season_end_year,
                  team_abbreviation, priority, status, depth, discovered_from,
                  updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 'queued', ?, ?, ?)
                """,
                (
                    url,
                    url,
                    page_family,
                    source_key,
                    season_end_year,
                    team_abbreviation,
                    priority,
                    depth,
                    discovered_from,
                    now,
                ),
            )
            inserted = cursor.rowcount > 0
            if not inserted:
                db.execute(
                    """
                    UPDATE pages
                    SET priority = MIN(priority, ?), depth = MIN(depth, ?),
                        source_key = COALESCE(source_key, ?),
                        season_end_year = COALESCE(season_end_year, ?),
                        team_abbreviation = COALESCE(team_abbreviation, ?),
                        discovered_from = COALESCE(discovered_from, ?),
                        updated_at = ?
                    WHERE url = ?
                    """,
                    (
                        priority,
                        depth,
                        source_key,
                        season_end_year,
                        team_abbreviation,
                        discovered_from,
                        now,
                        url,
                    ),
                )
            return inserted

    def next_page(self, *, max_depth: int, families: set[str]) -> sqlite3.Row | None:
        if not families:
            return None
        placeholders = ",".join("?" for _ in families)
        params = [max_depth, *sorted(families)]
        with self.connect() as db:
            row = db.execute(
                f"""
                SELECT * FROM pages
                WHERE status = 'queued'
                  AND depth <= ?
                  AND page_family IN ({placeholders})
                ORDER BY priority, depth, url
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
                (self._now(), row["url"]),
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
        status_code: int = 200,
        content_type: str = "text/html",
        html_bytes: int = 0,
    ) -> None:
        now = self._now()
        snapshot_path = self._write_snapshot(
            url=url,
            parsed=parsed,
            fetched_at=fetched_at,
            source_sha256=source_sha256,
            cache_path=cache_path,
            status_code=status_code,
            content_type=content_type,
            html_bytes=html_bytes,
        )
        with self.connect() as db:
            db.execute("DELETE FROM tables WHERE page_url = ?", (url,))
            db.execute("DELETE FROM discovered_links WHERE source_url = ?", (url,))
            for table in parsed.tables:
                cursor = db.execute(
                    """
                    INSERT INTO tables(
                      page_url, table_id, ordinal, caption, columns_json,
                      schema_hash, link_count, row_count
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        url,
                        table.table_id,
                        table.ordinal,
                        table.caption,
                        json.dumps(table.columns, separators=(",", ":")),
                        table.schema_hash,
                        table.link_count,
                        len(table.rows),
                    ),
                )
                table_pk = int(cursor.lastrowid)
                db.executemany(
                    """
                    INSERT INTO table_rows(
                      table_pk, row_index, source_row_index, row_class, section,
                      values_json, display_json, links_json
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    [
                        (
                            table_pk,
                            row["rowIndex"],
                            row["sourceRowIndex"],
                            row["rowClass"],
                            row.get("section"),
                            json.dumps(row["values"], separators=(",", ":"), ensure_ascii=False),
                            json.dumps(row.get("display", {}), separators=(",", ":"), ensure_ascii=False),
                            json.dumps(row["links"], separators=(",", ":"), ensure_ascii=False),
                        )
                        for row in table.rows
                    ],
                )

            db.executemany(
                """
                INSERT OR REPLACE INTO discovered_links(
                  source_url, target_url, page_family, source_key,
                  season_end_year, team_abbreviation, priority, anchor_text
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    (
                        url,
                        link["url"],
                        link["pageFamily"],
                        link.get("sourceKey"),
                        link.get("seasonEndYear"),
                        link.get("teamAbbreviation"),
                        int(link.get("priority", 100)),
                        link["anchorText"],
                    )
                    for link in parsed.discovered_links
                ],
            )
            for link in parsed.discovered_links:
                source_key = link.get("sourceKey")
                if not source_key:
                    continue
                db.execute(
                    """
                    INSERT INTO source_entities(
                      source_key, page_family, canonical_url, season_end_year,
                      team_abbreviation, first_seen_at, last_seen_at,
                      discovery_count, anchor_text
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)
                    ON CONFLICT(source_key) DO UPDATE SET
                      last_seen_at = excluded.last_seen_at,
                      discovery_count = source_entities.discovery_count + 1,
                      anchor_text = COALESCE(source_entities.anchor_text, excluded.anchor_text)
                    """,
                    (
                        source_key,
                        link["pageFamily"],
                        link["url"],
                        link.get("seasonEndYear"),
                        link.get("teamAbbreviation"),
                        now,
                        now,
                        link.get("anchorText"),
                    ),
                )

            db.execute(
                """
                UPDATE pages
                SET status = 'complete', canonical_url = ?, page_family = COALESCE(?, page_family),
                    source_key = COALESCE(?, source_key), season_end_year = COALESCE(?, season_end_year),
                    team_abbreviation = COALESCE(?, team_abbreviation), title = ?, fetched_at = ?,
                    source_sha256 = ?, status_code = ?, content_type = ?, cache_path = ?,
                    snapshot_path = ?, html_bytes = ?, table_count = ?, link_count = ?,
                    last_error = NULL, updated_at = ?
                WHERE url = ?
                """,
                (
                    parsed.canonical_url or url,
                    parsed.page_family,
                    parsed.source_key,
                    parsed.season_end_year,
                    parsed.team_abbreviation,
                    parsed.title,
                    fetched_at,
                    source_sha256,
                    status_code,
                    content_type,
                    cache_path,
                    str(snapshot_path),
                    html_bytes,
                    len(parsed.tables),
                    len(parsed.discovered_links),
                    now,
                    url,
                ),
            )

    def mark_failed(self, url: str, error: str, *, terminal: bool = True) -> None:
        self._mark(url, "failed" if terminal else "queued", error)

    def mark_blocked(self, url: str, error: str) -> None:
        self._mark(url, "blocked", error)

    def mark_skipped(self, url: str, reason: str) -> None:
        self._mark(url, "skipped", reason)

    def _mark(self, url: str, status: str, error: str | None) -> None:
        with self.connect() as db:
            db.execute(
                """
                UPDATE pages
                SET status = ?, last_error = ?, updated_at = ?
                WHERE url = ?
                """,
                (status, (error or "")[:2000] or None, self._now(), url),
            )

    def reset_fetching(self) -> int:
        with self.connect() as db:
            cursor = db.execute(
                "UPDATE pages SET status = 'queued', updated_at = ? WHERE status = 'fetching'",
                (self._now(),),
            )
            return cursor.rowcount

    def reset_failed(self, *, include_blocked: bool = False) -> int:
        statuses = ("failed", "blocked") if include_blocked else ("failed",)
        placeholders = ",".join("?" for _ in statuses)
        with self.connect() as db:
            cursor = db.execute(
                f"""
                UPDATE pages SET status = 'queued', last_error = NULL, updated_at = ?
                WHERE status IN ({placeholders})
                """,
                (self._now(), *statuses),
            )
            return cursor.rowcount

    def start_run(self, run_key: str, mode: str, configuration: dict[str, object]) -> None:
        with self.connect() as db:
            db.execute(
                """
                INSERT OR REPLACE INTO runs(
                  run_key, started_at, finished_at, mode, status,
                  configuration_json, summary_json
                ) VALUES (?, ?, NULL, ?, 'running', ?, NULL)
                """,
                (run_key, self._now(), mode, json.dumps(configuration, sort_keys=True)),
            )

    def finish_run(self, run_key: str, status: str, summary: dict[str, object]) -> None:
        with self.connect() as db:
            db.execute(
                """
                UPDATE runs SET finished_at = ?, status = ?, summary_json = ?
                WHERE run_key = ?
                """,
                (self._now(), status, json.dumps(summary, sort_keys=True), run_key),
            )

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
            entity_count = db.execute("SELECT COUNT(*) FROM source_entities").fetchone()[0]
            html_bytes = db.execute("SELECT COALESCE(SUM(html_bytes), 0) FROM pages").fetchone()[0]
            by_family = {
                row["page_family"]: row["count"]
                for row in db.execute(
                    "SELECT page_family, COUNT(*) AS count FROM pages GROUP BY page_family"
                )
            }
            latest_run = db.execute(
                "SELECT * FROM runs ORDER BY started_at DESC LIMIT 1"
            ).fetchone()
        return {
            "database": str(self.database_path),
            "snapshotRoot": str(self.snapshot_root),
            "pages": page_counts,
            "pageFamilies": by_family,
            "tables": table_count,
            "rows": row_count,
            "links": link_count,
            "sourceEntities": entity_count,
            "htmlBytes": html_bytes,
            "latestRun": dict(latest_run) if latest_run else None,
        }

    def coverage(self) -> dict[str, object]:
        with self.connect() as db:
            seasons = [
                dict(row)
                for row in db.execute(
                    """
                    SELECT season_end_year AS seasonEndYear, page_family AS pageFamily,
                           status, COUNT(*) AS pageCount,
                           COALESCE(SUM(table_count), 0) AS tableCount
                    FROM pages
                    WHERE season_end_year IS NOT NULL
                    GROUP BY season_end_year, page_family, status
                    ORDER BY season_end_year, page_family, status
                    """
                )
            ]
            table_ids = [
                dict(row)
                for row in db.execute(
                    """
                    SELECT table_id AS tableId, COUNT(*) AS pageCount,
                           SUM(row_count) AS rowCount,
                           COUNT(DISTINCT schema_hash) AS schemaVariants
                    FROM tables
                    GROUP BY table_id
                    ORDER BY pageCount DESC, table_id
                    """
                )
            ]
        return {"seasonCoverage": seasons, "tableRegistry": table_ids}

    def schema_drift(self) -> list[dict[str, object]]:
        with self.connect() as db:
            return [
                dict(row)
                for row in db.execute(
                    """
                    SELECT table_id AS tableId,
                           COUNT(*) AS pageCount,
                           COUNT(DISTINCT schema_hash) AS schemaVariants,
                           GROUP_CONCAT(DISTINCT schema_hash) AS schemaHashes
                    FROM tables
                    GROUP BY table_id
                    HAVING COUNT(DISTINCT schema_hash) > 1
                    ORDER BY schemaVariants DESC, pageCount DESC, table_id
                    """
                )
            ]

    def queue_sample(self, status: str = "queued", limit: int = 20) -> list[dict[str, object]]:
        limit = max(1, min(limit, 200))
        with self.connect() as db:
            return [
                dict(row)
                for row in db.execute(
                    """
                    SELECT url, page_family AS pageFamily, source_key AS sourceKey,
                           season_end_year AS seasonEndYear, priority, depth,
                           attempts, discovered_from AS discoveredFrom, last_error AS lastError
                    FROM pages WHERE status = ?
                    ORDER BY priority, depth, url LIMIT ?
                    """,
                    (status, limit),
                )
            ]

    def export_jsonl(self, output_dir: str | Path) -> dict[str, int]:
        output = Path(output_dir)
        output.mkdir(parents=True, exist_ok=True)
        counts = {
            "pages": 0,
            "tables": 0,
            "rows": 0,
            "links": 0,
            "entities": 0,
            "runs": 0,
        }
        with self.connect() as db:
            for name, query in (
                ("pages", "SELECT * FROM pages ORDER BY url"),
                ("tables", "SELECT * FROM tables ORDER BY page_url, ordinal"),
                ("rows", "SELECT * FROM table_rows ORDER BY table_pk, row_index"),
                ("links", "SELECT * FROM discovered_links ORDER BY source_url, target_url"),
                ("entities", "SELECT * FROM source_entities ORDER BY source_key"),
                ("runs", "SELECT * FROM runs ORDER BY started_at"),
            ):
                path = output / f"{name}.jsonl"
                with path.open("w", encoding="utf-8") as handle:
                    for row in db.execute(query):
                        handle.write(json.dumps(dict(row), ensure_ascii=False) + "\n")
                        counts[name] += 1
        return counts

    def _write_snapshot(
        self,
        *,
        url: str,
        parsed: ParsedPage,
        fetched_at: str,
        source_sha256: str,
        cache_path: str,
        status_code: int,
        content_type: str,
        html_bytes: int,
    ) -> Path:
        family = parsed.page_family or "unclassified"
        season = str(parsed.season_end_year or "unknown-season")
        url_hash = hashlib.sha256(url.encode("utf-8")).hexdigest()[:20]
        path = self.snapshot_root / season / family / f"{url_hash}.json.gz"
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix(path.suffix + ".tmp")
        document = {
            "url": url,
            "canonicalUrl": parsed.canonical_url or url,
            "pageFamily": parsed.page_family,
            "sourceKey": parsed.source_key,
            "seasonEndYear": parsed.season_end_year,
            "teamAbbreviation": parsed.team_abbreviation,
            "title": parsed.title,
            "fetchedAt": fetched_at,
            "sourceSha256": source_sha256,
            "cachePath": cache_path,
            "statusCode": status_code,
            "contentType": content_type,
            "htmlBytes": html_bytes,
            "tables": [
                {
                    "tableId": table.table_id,
                    "ordinal": table.ordinal,
                    "caption": table.caption,
                    "columns": table.columns,
                    "schemaHash": table.schema_hash,
                    "linkCount": table.link_count,
                    "rowCount": len(table.rows),
                    "rows": table.rows,
                }
                for table in parsed.tables
            ],
            "discoveredLinks": parsed.discovered_links,
        }
        with gzip.open(temporary, "wt", encoding="utf-8") as handle:
            json.dump(document, handle, ensure_ascii=False, separators=(",", ":"))
        temporary.replace(path)
        return path

    def _now(self) -> str:
        return datetime.now(timezone.utc).isoformat()
