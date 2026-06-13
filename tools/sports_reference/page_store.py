from __future__ import annotations

import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterator

from .catalog_schema import initialize_catalog_schema
from .snapshot_archive import SportsReferenceSnapshotArchive
from .table_parser import ParsedPage


class SportsReferencePageStore:
    """SQLite queue, link graph, entity index, and normalized raw table store."""

    def __init__(
        self,
        database_path: str | Path,
        snapshot_root: str | Path | None = None,
    ) -> None:
        self.database_path = Path(database_path)
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        self.snapshot_root = Path(snapshot_root) if snapshot_root else self.database_path.parent / "snapshots"
        self.archive = SportsReferenceSnapshotArchive(self.snapshot_root)
        with self.connect() as db:
            initialize_catalog_schema(db)

    @contextmanager
    def connect(self) -> Iterator[sqlite3.Connection]:
        db = sqlite3.connect(self.database_path)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA foreign_keys = ON")
        db.execute("PRAGMA journal_mode = WAL")
        try:
            yield db
            db.commit()
        finally:
            db.close()

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
                    UPDATE pages SET
                      priority = MIN(priority, ?), depth = MIN(depth, ?),
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
        with self.connect() as db:
            row = db.execute(
                f"""
                SELECT * FROM pages
                WHERE status = 'queued' AND depth <= ?
                  AND page_family IN ({placeholders})
                ORDER BY priority, depth, url LIMIT 1
                """,
                (max_depth, *sorted(families)),
            ).fetchone()
            if row is None:
                return None
            db.execute(
                """
                UPDATE pages SET status = 'fetching', attempts = attempts + 1,
                  updated_at = ? WHERE url = ?
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
        snapshot_path = self.archive.write(
            url=url,
            parsed=parsed,
            fetched_at=fetched_at,
            source_sha256=source_sha256,
            cache_path=cache_path,
            status_code=status_code,
            content_type=content_type,
            html_bytes=html_bytes,
        )
        now = self._now()
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
                            self._json(row["values"]),
                            self._json(row.get("display", {})),
                            self._json(row["links"]),
                        )
                        for row in table.rows
                    ],
                )

            links = parsed.discovered_links
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
                        link.get("anchorText"),
                    )
                    for link in links
                ],
            )
            for link in links:
                self._upsert_entity(db, link, now)

            db.execute(
                """
                UPDATE pages SET
                  status = 'complete', canonical_url = ?,
                  page_family = COALESCE(?, page_family),
                  source_key = COALESCE(?, source_key),
                  season_end_year = COALESCE(?, season_end_year),
                  team_abbreviation = COALESCE(?, team_abbreviation),
                  title = ?, fetched_at = ?, source_sha256 = ?,
                  status_code = ?, content_type = ?, cache_path = ?,
                  snapshot_path = ?, html_bytes = ?, table_count = ?,
                  link_count = ?, last_error = NULL, updated_at = ?
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
                    len(links),
                    now,
                    url,
                ),
            )

    def _upsert_entity(self, db: sqlite3.Connection, link: dict, now: str) -> None:
        source_key = link.get("sourceKey")
        if not source_key:
            return
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
                UPDATE pages SET status = ?, last_error = ?, updated_at = ?
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
                UPDATE pages SET status = 'queued', last_error = NULL,
                  updated_at = ? WHERE status IN ({placeholders})
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
            pages = {
                row["status"]: row["count"]
                for row in db.execute(
                    "SELECT status, COUNT(*) AS count FROM pages GROUP BY status"
                )
            }
            families = {
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
                "pages": pages,
                "pageFamilies": families,
                "tables": db.execute("SELECT COUNT(*) FROM tables").fetchone()[0],
                "rows": db.execute("SELECT COUNT(*) FROM table_rows").fetchone()[0],
                "links": db.execute("SELECT COUNT(*) FROM discovered_links").fetchone()[0],
                "sourceEntities": db.execute("SELECT COUNT(*) FROM source_entities").fetchone()[0],
                "htmlBytes": db.execute("SELECT COALESCE(SUM(html_bytes), 0) FROM pages").fetchone()[0],
                "latestRun": dict(latest_run) if latest_run else None,
            }

    def coverage(self) -> dict[str, object]:
        with self.connect() as db:
            seasons = [
                dict(row)
                for row in db.execute(
                    """
                    SELECT season_end_year AS seasonEndYear,
                           page_family AS pageFamily, status,
                           COUNT(*) AS pageCount,
                           COALESCE(SUM(table_count), 0) AS tableCount
                    FROM pages WHERE season_end_year IS NOT NULL
                    GROUP BY season_end_year, page_family, status
                    ORDER BY season_end_year, page_family, status
                    """
                )
            ]
            registry = [
                dict(row)
                for row in db.execute(
                    """
                    SELECT table_id AS tableId, COUNT(*) AS pageCount,
                           SUM(row_count) AS rowCount,
                           COUNT(DISTINCT schema_hash) AS schemaVariants
                    FROM tables GROUP BY table_id
                    ORDER BY pageCount DESC, table_id
                    """
                )
            ]
        return {"seasonCoverage": seasons, "tableRegistry": registry}

    def schema_drift(self) -> list[dict[str, object]]:
        with self.connect() as db:
            return [
                dict(row)
                for row in db.execute(
                    """
                    SELECT table_id AS tableId, COUNT(*) AS pageCount,
                           COUNT(DISTINCT schema_hash) AS schemaVariants,
                           GROUP_CONCAT(DISTINCT schema_hash) AS schemaHashes
                    FROM tables GROUP BY table_id
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
                           attempts, discovered_from AS discoveredFrom,
                           last_error AS lastError
                    FROM pages WHERE status = ?
                    ORDER BY priority, depth, url LIMIT ?
                    """,
                    (status, limit),
                )
            ]

    def export_jsonl(self, output_dir: str | Path) -> dict[str, int]:
        output = Path(output_dir)
        output.mkdir(parents=True, exist_ok=True)
        counts = {name: 0 for name in ("pages", "tables", "rows", "links", "entities", "runs")}
        queries = (
            ("pages", "SELECT * FROM pages ORDER BY url"),
            ("tables", "SELECT * FROM tables ORDER BY page_url, ordinal"),
            ("rows", "SELECT * FROM table_rows ORDER BY table_pk, row_index"),
            ("links", "SELECT * FROM discovered_links ORDER BY source_url, target_url"),
            ("entities", "SELECT * FROM source_entities ORDER BY source_key"),
            ("runs", "SELECT * FROM runs ORDER BY started_at"),
        )
        with self.connect() as db:
            for name, query in queries:
                with (output / f"{name}.jsonl").open("w", encoding="utf-8") as handle:
                    for row in db.execute(query):
                        handle.write(json.dumps(dict(row), ensure_ascii=False) + "\n")
                        counts[name] += 1
        return counts

    def _json(self, value: object) -> str:
        return json.dumps(value, separators=(",", ":"), ensure_ascii=False)

    def _now(self) -> str:
        return datetime.now(timezone.utc).isoformat()
