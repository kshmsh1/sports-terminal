from __future__ import annotations

import argparse
import json
import re
import sqlite3
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from inspect_basketball_reference_catalog import canonical_bucket

DEFAULT_SOURCE_DATABASE = "raw/basketball_reference/catalog.sqlite"
DEFAULT_OUTPUT_DATABASE = "data/warehouse/nba_2025.sqlite"

GAME_ID_RE = re.compile(r"/boxscores/(?:pbp/|shot-chart/|plus-minus/)?([0-9A-Z]+)\.html$", re.IGNORECASE)
PLAYER_ID_RE = re.compile(r"/players/[a-z]/([a-z0-9]+)(?:\.html|/)", re.IGNORECASE)
TEAM_BOX_RE = re.compile(r"^box-([A-Z0-9]{2,3})-(game|h1|h2|q[1-4]|ot\d+)-(basic|advanced)$")


class WarehouseBuilder:
    def __init__(self, source_database: str | Path, output_database: str | Path, season: int) -> None:
        self.source_database = Path(source_database)
        self.output_database = Path(output_database)
        self.season = season

    def build(self) -> dict[str, Any]:
        if not self.source_database.exists():
            raise FileNotFoundError(f"Raw catalog does not exist: {self.source_database}")
        self.output_database.parent.mkdir(parents=True, exist_ok=True)
        if self.output_database.exists():
            self.output_database.unlink()

        with self._connect_source() as source, self._connect_output() as warehouse:
            self._initialize_schema(warehouse)
            page_count = self._copy_pages(source, warehouse)
            table_count = self._copy_tables(source, warehouse)
            row_count = self._copy_rows(source, warehouse)
            line_score_count = self._copy_line_scores(source, warehouse)
            four_factor_count = self._copy_four_factors(source, warehouse)
            player_basic_count = self._copy_player_box_rows(source, warehouse, box_type="basic")
            player_advanced_count = self._copy_player_box_rows(source, warehouse, box_type="advanced")
            pbp_count = self._copy_play_by_play(source, warehouse)
            checks = self._write_quality_checks(warehouse)
            self._write_manifest(
                warehouse,
                {
                    "sourceDatabase": str(self.source_database),
                    "outputDatabase": str(self.output_database),
                    "seasonEndYear": self.season,
                    "generatedAt": datetime.now(timezone.utc).isoformat(),
                    "pages": page_count,
                    "tables": table_count,
                    "warehouseRows": row_count,
                    "gameLineScores": line_score_count,
                    "gameFourFactors": four_factor_count,
                    "playerBasicBoxRows": player_basic_count,
                    "playerAdvancedBoxRows": player_advanced_count,
                    "playByPlayEvents": pbp_count,
                    "qualityChecks": checks,
                },
            )
            self._create_indexes(warehouse)
            warehouse.commit()

        return {
            "output": str(self.output_database),
            "seasonEndYear": self.season,
            "pages": page_count,
            "tables": table_count,
            "warehouseRows": row_count,
            "gameLineScores": line_score_count,
            "gameFourFactors": four_factor_count,
            "playerBasicBoxRows": player_basic_count,
            "playerAdvancedBoxRows": player_advanced_count,
            "playByPlayEvents": pbp_count,
            "qualityChecks": checks,
        }

    def _connect_source(self) -> sqlite3.Connection:
        db = sqlite3.connect(self.source_database)
        db.row_factory = sqlite3.Row
        return db

    def _connect_output(self) -> sqlite3.Connection:
        db = sqlite3.connect(self.output_database)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA journal_mode = WAL")
        db.execute("PRAGMA synchronous = NORMAL")
        return db

    def _initialize_schema(self, db: sqlite3.Connection) -> None:
        db.executescript(
            """
            CREATE TABLE warehouse_build_manifest(
              key TEXT PRIMARY KEY,
              value_json TEXT NOT NULL
            );

            CREATE TABLE warehouse_quality_checks(
              check_name TEXT PRIMARY KEY,
              status TEXT NOT NULL,
              expected INTEGER,
              actual INTEGER,
              details_json TEXT
            );

            CREATE TABLE source_pages(
              page_url TEXT PRIMARY KEY,
              canonical_url TEXT,
              page_family TEXT NOT NULL,
              source_key TEXT,
              season_end_year INTEGER,
              team_abbreviation TEXT,
              title TEXT,
              depth INTEGER,
              fetched_at TEXT,
              table_count INTEGER,
              link_count INTEGER,
              html_bytes INTEGER,
              snapshot_path TEXT
            );

            CREATE TABLE source_tables(
              table_pk INTEGER PRIMARY KEY,
              page_url TEXT NOT NULL,
              table_id TEXT NOT NULL,
              canonical_bucket TEXT NOT NULL,
              ordinal INTEGER,
              caption TEXT,
              columns_json TEXT,
              schema_hash TEXT,
              row_count INTEGER,
              page_family TEXT NOT NULL,
              season_end_year INTEGER
            );

            CREATE TABLE warehouse_rows(
              warehouse_row_id INTEGER PRIMARY KEY AUTOINCREMENT,
              table_pk INTEGER NOT NULL,
              page_url TEXT NOT NULL,
              page_family TEXT NOT NULL,
              table_id TEXT NOT NULL,
              canonical_bucket TEXT NOT NULL,
              season_end_year INTEGER,
              row_index INTEGER,
              source_row_index INTEGER,
              row_class TEXT,
              section TEXT,
              values_json TEXT NOT NULL,
              display_json TEXT NOT NULL,
              links_json TEXT NOT NULL
            );

            CREATE TABLE canonical_bucket_summary(
              canonical_bucket TEXT PRIMARY KEY,
              table_instances INTEGER NOT NULL,
              row_count INTEGER NOT NULL,
              page_count INTEGER NOT NULL,
              page_families_json TEXT NOT NULL,
              sample_table_ids_json TEXT NOT NULL
            );

            CREATE TABLE game_line_scores(
              game_id TEXT NOT NULL,
              page_url TEXT NOT NULL,
              team_label TEXT,
              team_url TEXT,
              team_id TEXT,
              q1 INTEGER,
              q2 INTEGER,
              q3 INTEGER,
              q4 INTEGER,
              ot1 INTEGER,
              ot2 INTEGER,
              ot3 INTEGER,
              ot4 INTEGER,
              total INTEGER,
              values_json TEXT NOT NULL,
              display_json TEXT NOT NULL,
              links_json TEXT NOT NULL
            );

            CREATE TABLE game_four_factors(
              game_id TEXT NOT NULL,
              page_url TEXT NOT NULL,
              team_label TEXT,
              team_url TEXT,
              team_id TEXT,
              values_json TEXT NOT NULL,
              display_json TEXT NOT NULL,
              links_json TEXT NOT NULL
            );

            CREATE TABLE player_box_scores(
              game_id TEXT NOT NULL,
              page_url TEXT NOT NULL,
              team_abbreviation TEXT NOT NULL,
              box_type TEXT NOT NULL,
              player_label TEXT,
              player_url TEXT,
              player_id TEXT,
              row_index INTEGER NOT NULL,
              values_json TEXT NOT NULL,
              display_json TEXT NOT NULL,
              links_json TEXT NOT NULL
            );

            CREATE TABLE play_by_play_events(
              game_id TEXT NOT NULL,
              page_url TEXT NOT NULL,
              row_index INTEGER NOT NULL,
              values_json TEXT NOT NULL,
              display_json TEXT NOT NULL,
              links_json TEXT NOT NULL
            );
            """
        )

    def _page_filter_sql(self) -> str:
        return """
            p.status = 'complete'
            AND (
              p.season_end_year = :season
              OR p.page_family = 'player'
            )
        """

    def _copy_pages(self, source: sqlite3.Connection, warehouse: sqlite3.Connection) -> int:
        rows = source.execute(
            f"""
            SELECT p.url, p.canonical_url, p.page_family, p.source_key,
                   p.season_end_year, p.team_abbreviation, p.title, p.depth,
                   p.fetched_at, p.table_count, p.link_count, p.html_bytes,
                   p.snapshot_path
            FROM pages AS p
            WHERE {self._page_filter_sql()}
            ORDER BY p.page_family, p.url
            """,
            {"season": self.season},
        )
        payload = [tuple(row) for row in rows]
        warehouse.executemany(
            """
            INSERT INTO source_pages(
              page_url, canonical_url, page_family, source_key, season_end_year,
              team_abbreviation, title, depth, fetched_at, table_count, link_count,
              html_bytes, snapshot_path
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            payload,
        )
        return len(payload)

    def _copy_tables(self, source: sqlite3.Connection, warehouse: sqlite3.Connection) -> int:
        rows = source.execute(
            f"""
            SELECT t.table_pk, t.page_url, t.table_id, t.ordinal, t.caption,
                   t.columns_json, t.schema_hash, t.row_count,
                   p.page_family, p.season_end_year
            FROM tables AS t
            JOIN pages AS p ON p.url = t.page_url
            WHERE {self._page_filter_sql()}
            ORDER BY t.table_pk
            """,
            {"season": self.season},
        )
        payload = []
        bucket_counts: dict[str, dict[str, Any]] = {}
        for row in rows:
            bucket = canonical_bucket(str(row["table_id"]), str(row["page_family"]))
            payload.append(
                (
                    row["table_pk"],
                    row["page_url"],
                    row["table_id"],
                    bucket,
                    row["ordinal"],
                    row["caption"],
                    row["columns_json"],
                    row["schema_hash"],
                    row["row_count"],
                    row["page_family"],
                    row["season_end_year"],
                )
            )
            current = bucket_counts.setdefault(
                bucket,
                {
                    "table_instances": 0,
                    "row_count": 0,
                    "pages": set(),
                    "page_families": set(),
                    "table_ids": set(),
                },
            )
            current["table_instances"] += 1
            current["row_count"] += int(row["row_count"] or 0)
            current["pages"].add(row["page_url"])
            current["page_families"].add(row["page_family"])
            current["table_ids"].add(row["table_id"])

        warehouse.executemany(
            """
            INSERT INTO source_tables(
              table_pk, page_url, table_id, canonical_bucket, ordinal, caption,
              columns_json, schema_hash, row_count, page_family, season_end_year
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            payload,
        )
        summary_payload = []
        for bucket, value in sorted(bucket_counts.items()):
            summary_payload.append(
                (
                    bucket,
                    value["table_instances"],
                    value["row_count"],
                    len(value["pages"]),
                    json.dumps(sorted(value["page_families"])),
                    json.dumps(sorted(value["table_ids"])[:30]),
                )
            )
        warehouse.executemany(
            """
            INSERT INTO canonical_bucket_summary(
              canonical_bucket, table_instances, row_count, page_count,
              page_families_json, sample_table_ids_json
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            summary_payload,
        )
        return len(payload)

    def _copy_rows(self, source: sqlite3.Connection, warehouse: sqlite3.Connection) -> int:
        rows = source.execute(
            f"""
            SELECT tr.table_pk, t.page_url, p.page_family, t.table_id,
                   p.season_end_year, tr.row_index, tr.source_row_index,
                   tr.row_class, tr.section, tr.values_json, tr.display_json,
                   tr.links_json
            FROM table_rows AS tr
            JOIN tables AS t ON t.table_pk = tr.table_pk
            JOIN pages AS p ON p.url = t.page_url
            WHERE {self._page_filter_sql()}
            ORDER BY tr.table_pk, tr.row_index
            """,
            {"season": self.season},
        )
        count = 0
        batch = []
        for row in rows:
            bucket = canonical_bucket(str(row["table_id"]), str(row["page_family"]))
            batch.append(
                (
                    row["table_pk"],
                    row["page_url"],
                    row["page_family"],
                    row["table_id"],
                    bucket,
                    row["season_end_year"],
                    row["row_index"],
                    row["source_row_index"],
                    row["row_class"],
                    row["section"],
                    row["values_json"],
                    row["display_json"] or "{}",
                    row["links_json"] or "{}",
                )
            )
            if len(batch) >= 10000:
                count += self._insert_warehouse_rows(warehouse, batch)
                batch.clear()
        if batch:
            count += self._insert_warehouse_rows(warehouse, batch)
        return count

    def _insert_warehouse_rows(self, warehouse: sqlite3.Connection, batch: list[tuple[Any, ...]]) -> int:
        warehouse.executemany(
            """
            INSERT INTO warehouse_rows(
              table_pk, page_url, page_family, table_id, canonical_bucket,
              season_end_year, row_index, source_row_index, row_class, section,
              values_json, display_json, links_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            batch,
        )
        return len(batch)

    def _copy_line_scores(self, source: sqlite3.Connection, warehouse: sqlite3.Connection) -> int:
        rows = self._raw_rows_for(source, page_family="boxscore", table_id="line_score")
        payload = []
        for row in rows:
            values = self._loads(row["values_json"])
            display = self._loads(row["display_json"])
            links = self._loads(row["links_json"])
            team_label, team_url, team_id = self._entity(values, display, links, "team")
            payload.append(
                (
                    self._game_id(row["page_url"]),
                    row["page_url"],
                    team_label,
                    team_url,
                    team_id,
                    self._intish(values.get("1") or values.get("q1")),
                    self._intish(values.get("2") or values.get("q2")),
                    self._intish(values.get("3") or values.get("q3")),
                    self._intish(values.get("4") or values.get("q4")),
                    self._intish(values.get("ot") or values.get("ot1")),
                    self._intish(values.get("ot2")),
                    self._intish(values.get("ot3")),
                    self._intish(values.get("ot4")),
                    self._intish(values.get("T") or values.get("pts") or values.get("total")),
                    row["values_json"],
                    row["display_json"] or "{}",
                    row["links_json"] or "{}",
                )
            )
        warehouse.executemany(
            """
            INSERT INTO game_line_scores(
              game_id, page_url, team_label, team_url, team_id, q1, q2, q3, q4,
              ot1, ot2, ot3, ot4, total, values_json, display_json, links_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            payload,
        )
        return len(payload)

    def _copy_four_factors(self, source: sqlite3.Connection, warehouse: sqlite3.Connection) -> int:
        rows = self._raw_rows_for(source, page_family="boxscore", table_id="four_factors")
        payload = []
        for row in rows:
            values = self._loads(row["values_json"])
            display = self._loads(row["display_json"])
            links = self._loads(row["links_json"])
            team_label, team_url, team_id = self._entity(values, display, links, "team")
            payload.append(
                (
                    self._game_id(row["page_url"]),
                    row["page_url"],
                    team_label,
                    team_url,
                    team_id,
                    row["values_json"],
                    row["display_json"] or "{}",
                    row["links_json"] or "{}",
                )
            )
        warehouse.executemany(
            """
            INSERT INTO game_four_factors(
              game_id, page_url, team_label, team_url, team_id,
              values_json, display_json, links_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            payload,
        )
        return len(payload)

    def _copy_player_box_rows(
        self,
        source: sqlite3.Connection,
        warehouse: sqlite3.Connection,
        *,
        box_type: str,
    ) -> int:
        like = "%-game-basic" if box_type == "basic" else "%-game-advanced"
        rows = source.execute(
            f"""
            SELECT tr.row_index, tr.values_json, tr.display_json, tr.links_json,
                   t.table_id, t.page_url
            FROM table_rows AS tr
            JOIN tables AS t ON t.table_pk = tr.table_pk
            JOIN pages AS p ON p.url = t.page_url
            WHERE {self._page_filter_sql()}
              AND p.page_family = 'boxscore'
              AND t.table_id LIKE ?
            ORDER BY t.page_url, t.table_id, tr.row_index
            """,
            {"season": self.season, 1: like},
        )
        # sqlite named and positional parameters cannot be mixed cleanly, so use a simple second query.
        rows = source.execute(
            """
            SELECT tr.row_index, tr.values_json, tr.display_json, tr.links_json,
                   t.table_id, t.page_url
            FROM table_rows AS tr
            JOIN tables AS t ON t.table_pk = tr.table_pk
            JOIN pages AS p ON p.url = t.page_url
            WHERE p.status = 'complete'
              AND p.season_end_year = ?
              AND p.page_family = 'boxscore'
              AND t.table_id LIKE ?
            ORDER BY t.page_url, t.table_id, tr.row_index
            """,
            (self.season, like),
        )
        payload = []
        for row in rows:
            match = TEAM_BOX_RE.match(str(row["table_id"]))
            if match is None:
                continue
            team = match.group(1)
            values = self._loads(row["values_json"])
            display = self._loads(row["display_json"])
            links = self._loads(row["links_json"])
            player_label, player_url, player_id = self._entity(values, display, links, "player")
            payload.append(
                (
                    self._game_id(row["page_url"]),
                    row["page_url"],
                    team,
                    box_type,
                    player_label,
                    player_url,
                    player_id,
                    row["row_index"],
                    row["values_json"],
                    row["display_json"] or "{}",
                    row["links_json"] or "{}",
                )
            )
        warehouse.executemany(
            """
            INSERT INTO player_box_scores(
              game_id, page_url, team_abbreviation, box_type, player_label,
              player_url, player_id, row_index, values_json, display_json, links_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            payload,
        )
        return len(payload)

    def _copy_play_by_play(self, source: sqlite3.Connection, warehouse: sqlite3.Connection) -> int:
        rows = source.execute(
            """
            SELECT tr.row_index, tr.values_json, tr.display_json, tr.links_json,
                   t.page_url
            FROM table_rows AS tr
            JOIN tables AS t ON t.table_pk = tr.table_pk
            JOIN pages AS p ON p.url = t.page_url
            WHERE p.status = 'complete'
              AND p.season_end_year = ?
              AND p.page_family = 'boxscore_detail'
              AND t.table_id = 'pbp'
            ORDER BY t.page_url, tr.row_index
            """,
            (self.season,),
        )
        payload = [
            (
                self._game_id(row["page_url"]),
                row["page_url"],
                row["row_index"],
                row["values_json"],
                row["display_json"] or "{}",
                row["links_json"] or "{}",
            )
            for row in rows
        ]
        warehouse.executemany(
            """
            INSERT INTO play_by_play_events(
              game_id, page_url, row_index, values_json, display_json, links_json
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            payload,
        )
        return len(payload)

    def _raw_rows_for(self, source: sqlite3.Connection, *, page_family: str, table_id: str) -> list[sqlite3.Row]:
        return list(
            source.execute(
                """
                SELECT tr.row_index, tr.values_json, tr.display_json, tr.links_json,
                       t.page_url
                FROM table_rows AS tr
                JOIN tables AS t ON t.table_pk = tr.table_pk
                JOIN pages AS p ON p.url = t.page_url
                WHERE p.status = 'complete'
                  AND p.season_end_year = ?
                  AND p.page_family = ?
                  AND t.table_id = ?
                ORDER BY t.page_url, tr.row_index
                """,
                (self.season, page_family, table_id),
            )
        )

    def _write_quality_checks(self, db: sqlite3.Connection) -> list[dict[str, Any]]:
        checks = []
        checks.append(self._check_count(db, "regular_and_postseason_boxscores", "source_pages", "page_family = 'boxscore'", 1314))
        checks.append(self._check_count(db, "game_line_score_rows", "game_line_scores", "1 = 1", 2628))
        checks.append(self._check_count(db, "game_four_factor_rows", "game_four_factors", "1 = 1", 2628))
        checks.append(self._check_count(db, "play_by_play_events_present", "play_by_play_events", "1 = 1", 1, minimum=True))
        db.executemany(
            """
            INSERT INTO warehouse_quality_checks(
              check_name, status, expected, actual, details_json
            ) VALUES (?, ?, ?, ?, ?)
            """,
            [
                (
                    item["checkName"],
                    item["status"],
                    item["expected"],
                    item["actual"],
                    json.dumps(item.get("details", {}), sort_keys=True),
                )
                for item in checks
            ],
        )
        return checks

    def _check_count(
        self,
        db: sqlite3.Connection,
        name: str,
        table: str,
        where: str,
        expected: int,
        *,
        minimum: bool = False,
    ) -> dict[str, Any]:
        actual = int(db.execute(f"SELECT COUNT(*) FROM {table} WHERE {where}").fetchone()[0])
        passed = actual >= expected if minimum else actual == expected
        return {
            "checkName": name,
            "status": "pass" if passed else "warn",
            "expected": expected,
            "actual": actual,
            "details": {"mode": "minimum" if minimum else "exact"},
        }

    def _write_manifest(self, db: sqlite3.Connection, document: dict[str, Any]) -> None:
        db.execute(
            "INSERT INTO warehouse_build_manifest(key, value_json) VALUES (?, ?)",
            ("build", json.dumps(document, indent=2, sort_keys=True)),
        )

    def _create_indexes(self, db: sqlite3.Connection) -> None:
        db.executescript(
            """
            CREATE INDEX idx_source_tables_bucket ON source_tables(canonical_bucket);
            CREATE INDEX idx_warehouse_rows_bucket ON warehouse_rows(canonical_bucket, table_id);
            CREATE INDEX idx_warehouse_rows_page ON warehouse_rows(page_url);
            CREATE INDEX idx_game_line_scores_game ON game_line_scores(game_id);
            CREATE INDEX idx_game_four_factors_game ON game_four_factors(game_id);
            CREATE INDEX idx_player_box_scores_game ON player_box_scores(game_id, team_abbreviation, box_type);
            CREATE INDEX idx_player_box_scores_player ON player_box_scores(player_id);
            CREATE INDEX idx_pbp_game ON play_by_play_events(game_id, row_index);
            """
        )

    def _game_id(self, url: str) -> str | None:
        match = GAME_ID_RE.search(url)
        return match.group(1).upper() if match else None

    def _entity(
        self,
        values: dict[str, Any],
        display: dict[str, Any],
        links: dict[str, Any],
        key: str,
    ) -> tuple[str | None, str | None, str | None]:
        label = self._string(values.get(key) or display.get(key))
        url = None
        raw_link = links.get(key)
        if isinstance(raw_link, str):
            url = raw_link
        elif isinstance(raw_link, list) and raw_link:
            first = raw_link[0]
            if isinstance(first, str):
                url = first
            elif isinstance(first, dict):
                url = first.get("href") or first.get("url")
        elif isinstance(raw_link, dict):
            url = raw_link.get("href") or raw_link.get("url")
        entity_id = None
        if key == "player" and url:
            match = PLAYER_ID_RE.search(url)
            entity_id = match.group(1) if match else None
        elif key == "team" and url:
            parts = [part for part in url.split("/") if part]
            entity_id = parts[-2] if len(parts) >= 2 and parts[-1].endswith(".html") else None
        return label, url, entity_id

    def _loads(self, raw: str | None) -> dict[str, Any]:
        if not raw:
            return {}
        try:
            value = json.loads(raw)
        except json.JSONDecodeError:
            return {}
        return value if isinstance(value, dict) else {}

    def _string(self, value: Any) -> str | None:
        if value is None:
            return None
        text = str(value).strip()
        return text or None

    def _intish(self, value: Any) -> int | None:
        if value is None or value == "":
            return None
        try:
            return int(float(str(value)))
        except (TypeError, ValueError):
            return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build a first-pass local NBA warehouse from the completed raw Basketball Reference catalog."
    )
    parser.add_argument("--database", default=DEFAULT_SOURCE_DATABASE)
    parser.add_argument("--season", type=int, default=2025)
    parser.add_argument("--output", default=DEFAULT_OUTPUT_DATABASE)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    summary = WarehouseBuilder(args.database, args.output, args.season).build()
    print(json.dumps(summary, indent=2, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
