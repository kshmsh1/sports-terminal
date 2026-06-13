from __future__ import annotations

import sqlite3


def initialize_catalog_schema(db: sqlite3.Connection) -> None:
    """Create or migrate the historical catalog without dropping prior data."""
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
          started_at TEXT NOT NULL,
          finished_at TEXT,
          mode TEXT NOT NULL,
          configuration_json TEXT NOT NULL,
          summary_json TEXT
        );
        """
    )

    additions = (
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
    )
    for table, column, declaration in additions:
        _ensure_column(db, table, column, declaration)

    db.executescript(
        """
        CREATE INDEX IF NOT EXISTS idx_pages_status_priority_depth
          ON pages(status, priority, depth, url);
        CREATE INDEX IF NOT EXISTS idx_pages_family_season
          ON pages(page_family, season_end_year, status);
        CREATE INDEX IF NOT EXISTS idx_pages_source_key
          ON pages(source_key);
        CREATE INDEX IF NOT EXISTS idx_tables_table_id
          ON tables(table_id);
        CREATE INDEX IF NOT EXISTS idx_tables_schema_hash
          ON tables(table_id, schema_hash);
        CREATE INDEX IF NOT EXISTS idx_discovered_links_source_key
          ON discovered_links(source_key);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_runs_run_key
          ON runs(run_key) WHERE run_key IS NOT NULL;
        """
    )


def _ensure_column(
    db: sqlite3.Connection,
    table: str,
    column: str,
    declaration: str,
) -> None:
    existing = {row["name"] for row in db.execute(f"PRAGMA table_info({table})")}
    if column not in existing:
        db.execute(f"ALTER TABLE {table} ADD COLUMN {column} {declaration}")
