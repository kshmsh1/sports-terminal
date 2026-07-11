from __future__ import annotations

import argparse
import json
import re
import sqlite3
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from inspect_basketball_reference_catalog import canonical_bucket

DEFAULT_SOURCE_DATABASE = "raw/basketball_reference/catalog.sqlite"
DEFAULT_OUTPUT_DATABASE = "data/warehouse/nba_2025.sqlite"

GAME_ID_RE = re.compile(r"/boxscores/(?:pbp/|shot-chart/|plus-minus/)?([0-9A-Z]+)\.html$", re.I)
PLAYER_ID_RE = re.compile(r"/players/[a-z]/([a-z0-9]+)(?:\.html|/)", re.I)
TEAM_BOX_RE = re.compile(r"^box-([A-Z0-9]{2,3})-game-(basic|advanced)$")
PERIOD_KEYS = {"1st_q": 1, "2nd_q": 2, "3rd_q": 3, "4th_q": 4, "ot": 5, "ot1": 5, "ot2": 6, "ot3": 7, "ot4": 8}
BASIC_STAT_KEYS = ("fg", "fga", "fg_pct", "fg3", "fg3a", "fg3_pct", "ft", "fta", "ft_pct", "orb", "drb", "trb", "ast", "stl", "blk", "tov", "pf", "pts", "plus_minus")
ADVANCED_STAT_KEYS = ("ts_pct", "efg_pct", "fg3a_per_fga_pct", "fta_per_fga_pct", "orb_pct", "drb_pct", "trb_pct", "ast_pct", "stl_pct", "blk_pct", "tov_pct", "usg_pct", "off_rtg", "def_rtg", "bpm")


class WarehouseBuilder:
    def __init__(self, source_database: str | Path, output_database: str | Path, season: int) -> None:
        self.source_database = Path(source_database)
        self.output_database = Path(output_database)
        self.season = season
        self.player_name_to_id: dict[str, str | None] = {}

    def build(self) -> dict[str, Any]:
        if not self.source_database.exists():
            raise FileNotFoundError(f"Raw catalog does not exist: {self.source_database}")
        self.output_database.parent.mkdir(parents=True, exist_ok=True)
        if self.output_database.exists():
            self.output_database.unlink()

        source = sqlite3.connect(self.source_database)
        source.row_factory = sqlite3.Row
        warehouse = sqlite3.connect(self.output_database)
        warehouse.row_factory = sqlite3.Row
        warehouse.execute("PRAGMA journal_mode = WAL")
        warehouse.execute("PRAGMA synchronous = NORMAL")
        try:
            self._initialize_schema(warehouse)
            pages = self._copy_pages(source, warehouse)
            tables = self._copy_tables(source, warehouse)
            rows = self._copy_bucketed_rows(source, warehouse)
            players = self._build_players(warehouse)
            line_scores = self._copy_line_scores(source, warehouse)
            four_factors = self._copy_four_factors(source, warehouse)
            basic_boxes = self._copy_player_box_scores(source, warehouse, "basic")
            advanced_boxes = self._copy_player_box_scores(source, warehouse, "advanced")
            games = self._build_games_and_team_game_stats(warehouse)
            player_game_stats = self._build_player_game_stats(warehouse)
            pbp_events = self._copy_play_by_play(source, warehouse)
            pbp_normalized = self._build_normalized_play_by_play(warehouse)
            checks = self._quality_checks(warehouse)
            summary = {
                "sourceDatabase": str(self.source_database),
                "outputDatabase": str(self.output_database),
                "seasonEndYear": self.season,
                "generatedAt": datetime.now(timezone.utc).isoformat(),
                "pages": pages,
                "tables": tables,
                "warehouseRows": rows,
                "players": players,
                "games": games,
                "gameLineScores": line_scores,
                "gameFourFactors": four_factors,
                "playerBasicBoxRows": basic_boxes,
                "playerAdvancedBoxRows": advanced_boxes,
                "playerGameStats": player_game_stats,
                "playByPlayEvents": pbp_events,
                "playByPlayEventsNormalized": pbp_normalized,
                "qualityChecks": checks,
            }
            warehouse.execute("INSERT INTO warehouse_build_manifest(key, value_json) VALUES (?, ?)", ("build", json.dumps(summary, indent=2, sort_keys=True)))
            self._create_indexes(warehouse)
            warehouse.commit()
            return summary
        finally:
            source.close()
            warehouse.close()

    def _initialize_schema(self, db: sqlite3.Connection) -> None:
        db.executescript(
            """
            CREATE TABLE warehouse_build_manifest(key TEXT PRIMARY KEY, value_json TEXT NOT NULL);
            CREATE TABLE warehouse_quality_checks(check_name TEXT PRIMARY KEY, status TEXT NOT NULL, expected INTEGER, actual INTEGER, details_json TEXT NOT NULL);
            CREATE TABLE source_pages(page_url TEXT PRIMARY KEY, canonical_url TEXT, page_family TEXT NOT NULL, source_key TEXT, season_end_year INTEGER, team_abbreviation TEXT, title TEXT, depth INTEGER, fetched_at TEXT, table_count INTEGER, link_count INTEGER, html_bytes INTEGER, snapshot_path TEXT);
            CREATE TABLE source_tables(table_pk INTEGER PRIMARY KEY, page_url TEXT NOT NULL, table_id TEXT NOT NULL, canonical_bucket TEXT NOT NULL, ordinal INTEGER, caption TEXT, columns_json TEXT, schema_hash TEXT, row_count INTEGER, page_family TEXT NOT NULL, season_end_year INTEGER);
            CREATE TABLE warehouse_rows(warehouse_row_id INTEGER PRIMARY KEY AUTOINCREMENT, table_pk INTEGER NOT NULL, page_url TEXT NOT NULL, page_family TEXT NOT NULL, table_id TEXT NOT NULL, canonical_bucket TEXT NOT NULL, season_end_year INTEGER, row_index INTEGER, source_row_index INTEGER, row_class TEXT, section TEXT, values_json TEXT NOT NULL, display_json TEXT NOT NULL, links_json TEXT NOT NULL);
            CREATE TABLE canonical_bucket_summary(canonical_bucket TEXT PRIMARY KEY, table_instances INTEGER NOT NULL, row_count INTEGER NOT NULL, page_count INTEGER NOT NULL, page_families_json TEXT NOT NULL, sample_table_ids_json TEXT NOT NULL);
            CREATE TABLE teams(team_id TEXT PRIMARY KEY, season_end_year INTEGER NOT NULL, team_abbreviation TEXT NOT NULL, team_name TEXT, team_url TEXT);
            CREATE TABLE players(player_id TEXT PRIMARY KEY, player_name TEXT NOT NULL, profile_url TEXT, source_key TEXT, title TEXT);
            CREATE TABLE games(game_id TEXT PRIMARY KEY, season_end_year INTEGER NOT NULL, game_date TEXT, home_team_id TEXT, away_team_id TEXT, home_score INTEGER, away_score INTEGER, winner_team_id TEXT, loser_team_id TEXT, page_url TEXT);
            CREATE TABLE team_game_stats(game_id TEXT NOT NULL, team_id TEXT NOT NULL, opponent_team_id TEXT, is_home INTEGER, points INTEGER, opponent_points INTEGER, result TEXT, q1 INTEGER, q2 INTEGER, q3 INTEGER, q4 INTEGER, ot1 INTEGER, ot2 INTEGER, ot3 INTEGER, ot4 INTEGER, values_json TEXT NOT NULL, display_json TEXT NOT NULL, links_json TEXT NOT NULL, PRIMARY KEY(game_id, team_id));
            CREATE TABLE game_line_scores(game_id TEXT, page_url TEXT NOT NULL, team_label TEXT, team_url TEXT, team_id TEXT, q1 INTEGER, q2 INTEGER, q3 INTEGER, q4 INTEGER, ot1 INTEGER, ot2 INTEGER, ot3 INTEGER, ot4 INTEGER, total INTEGER, values_json TEXT NOT NULL, display_json TEXT NOT NULL, links_json TEXT NOT NULL);
            CREATE TABLE game_four_factors(game_id TEXT, page_url TEXT NOT NULL, team_label TEXT, team_url TEXT, team_id TEXT, values_json TEXT NOT NULL, display_json TEXT NOT NULL, links_json TEXT NOT NULL);
            CREATE TABLE player_box_scores(game_id TEXT, page_url TEXT NOT NULL, team_abbreviation TEXT NOT NULL, box_type TEXT NOT NULL, player_label TEXT, player_url TEXT, player_id TEXT, row_index INTEGER NOT NULL, values_json TEXT NOT NULL, display_json TEXT NOT NULL, links_json TEXT NOT NULL);
            CREATE TABLE player_game_stats(game_id TEXT NOT NULL, team_id TEXT NOT NULL, player_id TEXT, player_label TEXT NOT NULL, mp_text TEXT, mp_seconds INTEGER, fg REAL, fga REAL, fg_pct REAL, fg3 REAL, fg3a REAL, fg3_pct REAL, ft REAL, fta REAL, ft_pct REAL, orb REAL, drb REAL, trb REAL, ast REAL, stl REAL, blk REAL, tov REAL, pf REAL, pts REAL, plus_minus REAL, ts_pct REAL, efg_pct REAL, fg3a_per_fga_pct REAL, fta_per_fga_pct REAL, orb_pct REAL, drb_pct REAL, trb_pct REAL, ast_pct REAL, stl_pct REAL, blk_pct REAL, tov_pct REAL, usg_pct REAL, off_rtg REAL, def_rtg REAL, bpm REAL, basic_values_json TEXT NOT NULL, advanced_values_json TEXT, PRIMARY KEY(game_id, team_id, player_label));
            CREATE TABLE play_by_play_events(game_id TEXT, page_url TEXT NOT NULL, row_index INTEGER NOT NULL, values_json TEXT NOT NULL, display_json TEXT NOT NULL, links_json TEXT NOT NULL);
            CREATE TABLE play_by_play_events_normalized(event_id INTEGER PRIMARY KEY AUTOINCREMENT, game_id TEXT, page_url TEXT NOT NULL, row_index INTEGER NOT NULL, period INTEGER, clock TEXT, description TEXT, score TEXT, values_json TEXT NOT NULL, display_json TEXT NOT NULL, links_json TEXT NOT NULL);
            """
        )

    def _page_filter(self) -> str:
        return "p.status = 'complete' AND (p.season_end_year = ? OR p.page_family = 'player')"

    def _copy_pages(self, source: sqlite3.Connection, db: sqlite3.Connection) -> int:
        payload = [tuple(row) for row in source.execute(f"""SELECT p.url, p.canonical_url, p.page_family, p.source_key, p.season_end_year, p.team_abbreviation, p.title, p.depth, p.fetched_at, p.table_count, p.link_count, p.html_bytes, p.snapshot_path FROM pages AS p WHERE {self._page_filter()} ORDER BY p.page_family, p.url""", (self.season,))]
        db.executemany("""INSERT INTO source_pages(page_url, canonical_url, page_family, source_key, season_end_year, team_abbreviation, title, depth, fetched_at, table_count, link_count, html_bytes, snapshot_path) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""", payload)
        return len(payload)

    def _copy_tables(self, source: sqlite3.Connection, db: sqlite3.Connection) -> int:
        bucket_index: dict[str, dict[str, Any]] = {}
        payload = []
        for row in source.execute(f"""SELECT t.id AS table_pk, t.page_url, t.table_id, t.ordinal, t.caption, t.columns_json, t.schema_hash, t.row_count, p.page_family, p.season_end_year FROM tables AS t JOIN pages AS p ON p.url = t.page_url WHERE {self._page_filter()} ORDER BY t.id""", (self.season,)):
            bucket = canonical_bucket(row["table_id"], row["page_family"])
            payload.append((row["table_pk"], row["page_url"], row["table_id"], bucket, row["ordinal"], row["caption"], row["columns_json"], row["schema_hash"], row["row_count"], row["page_family"], row["season_end_year"]))
            current = bucket_index.setdefault(bucket, {"tables": 0, "rows": 0, "pages": set(), "families": set(), "ids": set()})
            current["tables"] += 1
            current["rows"] += int(row["row_count"] or 0)
            current["pages"].add(row["page_url"])
            current["families"].add(row["page_family"])
            current["ids"].add(row["table_id"])
        db.executemany("""INSERT INTO source_tables(table_pk, page_url, table_id, canonical_bucket, ordinal, caption, columns_json, schema_hash, row_count, page_family, season_end_year) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""", payload)
        db.executemany("""INSERT INTO canonical_bucket_summary(canonical_bucket, table_instances, row_count, page_count, page_families_json, sample_table_ids_json) VALUES (?, ?, ?, ?, ?, ?)""", [(bucket, value["tables"], value["rows"], len(value["pages"]), json.dumps(sorted(value["families"])), json.dumps(sorted(value["ids"])[:30])) for bucket, value in sorted(bucket_index.items())])
        return len(payload)

    def _copy_bucketed_rows(self, source: sqlite3.Connection, db: sqlite3.Connection) -> int:
        rows = source.execute(f"""SELECT tr.table_pk, t.page_url, p.page_family, t.table_id, p.season_end_year, tr.row_index, tr.source_row_index, tr.row_class, tr.section, tr.values_json, tr.display_json, tr.links_json FROM table_rows AS tr JOIN tables AS t ON t.id = tr.table_pk JOIN pages AS p ON p.url = t.page_url WHERE {self._page_filter()} ORDER BY tr.table_pk, tr.row_index""", (self.season,))
        count = 0
        batch = []
        for row in rows:
            batch.append((row["table_pk"], row["page_url"], row["page_family"], row["table_id"], canonical_bucket(row["table_id"], row["page_family"]), row["season_end_year"], row["row_index"], row["source_row_index"], row["row_class"], row["section"], row["values_json"], row["display_json"] or "{}", row["links_json"] or "{}"))
            if len(batch) >= 10000:
                count += self._insert_rows(db, batch)
                batch = []
        if batch:
            count += self._insert_rows(db, batch)
        return count

    def _insert_rows(self, db: sqlite3.Connection, batch: list[tuple[Any, ...]]) -> int:
        db.executemany("""INSERT INTO warehouse_rows(table_pk, page_url, page_family, table_id, canonical_bucket, season_end_year, row_index, source_row_index, row_class, section, values_json, display_json, links_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""", batch)
        return len(batch)

    def _build_players(self, db: sqlite3.Connection) -> int:
        player_rows = []
        for row in db.execute("SELECT page_url, source_key, title FROM source_pages WHERE page_family = 'player' ORDER BY page_url"):
            player_id = self._player_id_from_url(row["page_url"])
            if not player_id:
                continue
            name = self._player_name_from_title(row["title"]) or player_id
            player_rows.append((player_id, name, row["page_url"], row["source_key"], row["title"]))
        db.executemany("INSERT OR REPLACE INTO players(player_id, player_name, profile_url, source_key, title) VALUES (?, ?, ?, ?, ?)", player_rows)
        names: dict[str, list[str]] = defaultdict(list)
        for player_id, name, *_ in player_rows:
            names[self._normalize_name(name)].append(player_id)
        self.player_name_to_id = {name: ids[0] for name, ids in names.items() if len(ids) == 1}
        return len(player_rows)

    def _copy_line_scores(self, source: sqlite3.Connection, db: sqlite3.Connection) -> int:
        payload = []
        for row in self._rows_for(source, "boxscore", "line_score"):
            values = self._json(row["values_json"])
            display = self._json(row["display_json"])
            links = self._json(row["links_json"])
            team_label, team_url, team_id = self._entity(values, display, links, "team")
            team_id = team_id or team_label
            q1 = self._int(values.get("1") or values.get("q1"))
            q2 = self._int(values.get("2") or values.get("q2"))
            q3 = self._int(values.get("3") or values.get("q3"))
            q4 = self._int(values.get("4") or values.get("q4"))
            ot1 = self._int(values.get("ot") or values.get("ot1"))
            ot2 = self._int(values.get("ot2"))
            ot3 = self._int(values.get("ot3"))
            ot4 = self._int(values.get("ot4"))
            total = self._int(values.get("T") or values.get("pts") or values.get("total"))
            if total is None:
                parts = [q1, q2, q3, q4, ot1, ot2, ot3, ot4]
                if any(part is not None for part in parts):
                    total = sum(part or 0 for part in parts)
            payload.append((self._game_id(row["page_url"]), row["page_url"], team_label, team_url, team_id, q1, q2, q3, q4, ot1, ot2, ot3, ot4, total, row["values_json"], row["display_json"] or "{}", row["links_json"] or "{}"))
            if team_id:
                db.execute("INSERT OR IGNORE INTO teams(team_id, season_end_year, team_abbreviation, team_name, team_url) VALUES (?, ?, ?, ?, ?)", (team_id, self.season, team_id, team_label, team_url))
        db.executemany("""INSERT INTO game_line_scores(game_id, page_url, team_label, team_url, team_id, q1, q2, q3, q4, ot1, ot2, ot3, ot4, total, values_json, display_json, links_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""", payload)
        return len(payload)

    def _copy_four_factors(self, source: sqlite3.Connection, db: sqlite3.Connection) -> int:
        payload = []
        for row in self._rows_for(source, "boxscore", "four_factors"):
            values = self._json(row["values_json"])
            display = self._json(row["display_json"])
            links = self._json(row["links_json"])
            team_label, team_url, team_id = self._entity(values, display, links, "team")
            payload.append((self._game_id(row["page_url"]), row["page_url"], team_label, team_url, team_id or team_label, row["values_json"], row["display_json"] or "{}", row["links_json"] or "{}"))
        db.executemany("INSERT INTO game_four_factors(game_id, page_url, team_label, team_url, team_id, values_json, display_json, links_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", payload)
        return len(payload)

    def _copy_player_box_scores(self, source: sqlite3.Connection, db: sqlite3.Connection, box_type: str) -> int:
        like = "%-game-basic" if box_type == "basic" else "%-game-advanced"
        payload = []
        for row in source.execute("""SELECT tr.row_index, tr.values_json, tr.display_json, tr.links_json, t.table_id, t.page_url FROM table_rows AS tr JOIN tables AS t ON t.id = tr.table_pk JOIN pages AS p ON p.url = t.page_url WHERE p.status = 'complete' AND p.season_end_year = ? AND p.page_family = 'boxscore' AND t.table_id LIKE ? ORDER BY t.page_url, t.table_id, tr.row_index""", (self.season, like)):
            match = TEAM_BOX_RE.match(row["table_id"])
            if not match:
                continue
            values = self._json(row["values_json"])
            display = self._json(row["display_json"])
            links = self._json(row["links_json"])
            player_label, player_url, player_id = self._entity(values, display, links, "player")
            player_label = player_label or self._text(values.get("name_display") or values.get("starters") or values.get("reserves"))
            if not player_id:
                player_id = self._player_id_from_url(player_url or "")
            if not player_id and player_label:
                player_id = self.player_name_to_id.get(self._normalize_name(player_label))
            payload.append((self._game_id(row["page_url"]), row["page_url"], match.group(1), box_type, player_label, player_url, player_id, row["row_index"], row["values_json"], row["display_json"] or "{}", row["links_json"] or "{}"))
        db.executemany("""INSERT INTO player_box_scores(game_id, page_url, team_abbreviation, box_type, player_label, player_url, player_id, row_index, values_json, display_json, links_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""", payload)
        return len(payload)

    def _build_games_and_team_game_stats(self, db: sqlite3.Connection) -> int:
        grouped: dict[str, list[sqlite3.Row]] = defaultdict(list)
        for row in db.execute("SELECT * FROM game_line_scores ORDER BY game_id, team_id"):
            grouped[row["game_id"]].append(row)
        games = []
        team_stats = []
        for game_id, rows in sorted(grouped.items()):
            if not game_id or len(rows) != 2:
                continue
            home_id = game_id[-3:]
            home = next((row for row in rows if row["team_id"] == home_id or row["team_label"] == home_id), None)
            away = next((row for row in rows if row is not home), None)
            if home is None or away is None:
                away, home = rows[0], rows[1]
                home_id = home["team_id"] or home["team_label"]
            away_id = away["team_id"] or away["team_label"]
            home_score = home["total"]
            away_score = away["total"]
            winner = loser = None
            if home_score is not None and away_score is not None:
                winner = home_id if home_score > away_score else away_id
                loser = away_id if home_score > away_score else home_id
            games.append((game_id, self.season, self._game_date(game_id), home_id, away_id, home_score, away_score, winner, loser, home["page_url"]))
            for row, opponent in ((home, away), (away, home)):
                points = row["total"]
                opp_points = opponent["total"]
                result = "W" if points is not None and opp_points is not None and points > opp_points else "L" if points is not None and opp_points is not None else None
                team_stats.append((game_id, row["team_id"] or row["team_label"], opponent["team_id"] or opponent["team_label"], 1 if row is home else 0, points, opp_points, result, row["q1"], row["q2"], row["q3"], row["q4"], row["ot1"], row["ot2"], row["ot3"], row["ot4"], row["values_json"], row["display_json"], row["links_json"]))
        db.executemany("INSERT INTO games(game_id, season_end_year, game_date, home_team_id, away_team_id, home_score, away_score, winner_team_id, loser_team_id, page_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", games)
        db.executemany("""INSERT INTO team_game_stats(game_id, team_id, opponent_team_id, is_home, points, opponent_points, result, q1, q2, q3, q4, ot1, ot2, ot3, ot4, values_json, display_json, links_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""", team_stats)
        return len(games)

    def _build_player_game_stats(self, db: sqlite3.Connection) -> int:
        advanced: dict[tuple[str, str, str], dict[str, Any]] = {}
        for row in db.execute("SELECT * FROM player_box_scores WHERE box_type = 'advanced'"):
            if not row["player_label"] or row["player_label"].lower() == "team totals":
                continue
            advanced[(row["game_id"], row["team_abbreviation"], row["player_label"])] = self._json(row["values_json"])
        payload = []
        for row in db.execute("SELECT * FROM player_box_scores WHERE box_type = 'basic' ORDER BY game_id, team_abbreviation, row_index"):
            if not row["player_label"] or row["player_label"].lower() == "team totals":
                continue
            values = self._json(row["values_json"])
            adv = advanced.get((row["game_id"], row["team_abbreviation"], row["player_label"]), {})
            player_id = row["player_id"] or self.player_name_to_id.get(self._normalize_name(row["player_label"]))
            basic_values = {key: self._num(values.get(key)) for key in BASIC_STAT_KEYS}
            advanced_values = {key: self._num(adv.get(key)) for key in ADVANCED_STAT_KEYS}
            payload.append((row["game_id"], row["team_abbreviation"], player_id, row["player_label"], self._text(values.get("mp")), self._seconds(values.get("mp")), *[basic_values[key] for key in BASIC_STAT_KEYS], *[advanced_values[key] for key in ADVANCED_STAT_KEYS], row["values_json"], json.dumps(adv, separators=(",", ":")) if adv else None))
        placeholders = ", ".join("?" for _ in range(42))
        db.executemany(f"""INSERT OR REPLACE INTO player_game_stats(game_id, team_id, player_id, player_label, mp_text, mp_seconds, fg, fga, fg_pct, fg3, fg3a, fg3_pct, ft, fta, ft_pct, orb, drb, trb, ast, stl, blk, tov, pf, pts, plus_minus, ts_pct, efg_pct, fg3a_per_fga_pct, fta_per_fga_pct, orb_pct, drb_pct, trb_pct, ast_pct, stl_pct, blk_pct, tov_pct, usg_pct, off_rtg, def_rtg, bpm, basic_values_json, advanced_values_json) VALUES ({placeholders})""", payload)
        return len(payload)

    def _copy_play_by_play(self, source: sqlite3.Connection, db: sqlite3.Connection) -> int:
        payload = [(self._game_id(row["page_url"]), row["page_url"], row["row_index"], row["values_json"], row["display_json"] or "{}", row["links_json"] or "{}") for row in self._rows_for(source, "boxscore_detail", "pbp")]
        db.executemany("INSERT INTO play_by_play_events(game_id, page_url, row_index, values_json, display_json, links_json) VALUES (?, ?, ?, ?, ?, ?)", payload)
        return len(payload)

    def _build_normalized_play_by_play(self, db: sqlite3.Connection) -> int:
        payload = []
        for row in db.execute("SELECT * FROM play_by_play_events ORDER BY game_id, row_index"):
            values = self._json(row["values_json"])
            period, clock = self._period_clock(values)
            payload.append((row["game_id"], row["page_url"], row["row_index"], period, clock, self._event_description(values), self._score(values), row["values_json"], row["display_json"], row["links_json"]))
        db.executemany("""INSERT INTO play_by_play_events_normalized(game_id, page_url, row_index, period, clock, description, score, values_json, display_json, links_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""", payload)
        return len(payload)

    def _rows_for(self, source: sqlite3.Connection, page_family: str, table_id: str) -> list[sqlite3.Row]:
        return list(source.execute("""SELECT tr.row_index, tr.values_json, tr.display_json, tr.links_json, t.page_url FROM table_rows AS tr JOIN tables AS t ON t.id = tr.table_pk JOIN pages AS p ON p.url = t.page_url WHERE p.status = 'complete' AND p.season_end_year = ? AND p.page_family = ? AND t.table_id = ? ORDER BY t.page_url, tr.row_index""", (self.season, page_family, table_id)))

    def _quality_checks(self, db: sqlite3.Connection) -> list[dict[str, Any]]:
        checks = [self._check(db, "boxscore_pages", "source_pages", "page_family = 'boxscore'", 1314), self._check(db, "games", "games", "1 = 1", 1314), self._check(db, "line_score_rows", "game_line_scores", "1 = 1", 2628), self._check(db, "line_score_totals_present", "game_line_scores", "total IS NOT NULL", 2628), self._check(db, "team_game_stats", "team_game_stats", "1 = 1", 2628), self._check(db, "four_factor_rows", "game_four_factors", "1 = 1", 2628), self._check(db, "player_game_stats", "player_game_stats", "1 = 1", 1, minimum=True), self._check(db, "player_game_stats_with_player_ids", "player_game_stats", "player_id IS NOT NULL", 1, minimum=True), self._check(db, "play_by_play_events", "play_by_play_events", "1 = 1", 1, minimum=True), self._check(db, "play_by_play_events_normalized", "play_by_play_events_normalized", "description IS NOT NULL", 1, minimum=True)]
        db.executemany("INSERT INTO warehouse_quality_checks(check_name, status, expected, actual, details_json) VALUES (?, ?, ?, ?, ?)", [(c["checkName"], c["status"], c["expected"], c["actual"], json.dumps(c["details"])) for c in checks])
        return checks

    def _check(self, db: sqlite3.Connection, name: str, table: str, where: str, expected: int, *, minimum: bool = False) -> dict[str, Any]:
        actual = int(db.execute(f"SELECT COUNT(*) FROM {table} WHERE {where}").fetchone()[0])
        passed = actual >= expected if minimum else actual == expected
        return {"checkName": name, "status": "pass" if passed else "warn", "expected": expected, "actual": actual, "details": {"mode": "minimum" if minimum else "exact"}}

    def _create_indexes(self, db: sqlite3.Connection) -> None:
        db.executescript("""CREATE INDEX idx_source_tables_bucket ON source_tables(canonical_bucket, table_id); CREATE INDEX idx_warehouse_rows_bucket ON warehouse_rows(canonical_bucket, table_id); CREATE INDEX idx_warehouse_rows_page ON warehouse_rows(page_url); CREATE INDEX idx_games_date ON games(game_date, game_id); CREATE INDEX idx_team_game_stats_team ON team_game_stats(team_id, game_id); CREATE INDEX idx_line_scores_game ON game_line_scores(game_id); CREATE INDEX idx_four_factors_game ON game_four_factors(game_id); CREATE INDEX idx_player_box_scores_game ON player_box_scores(game_id, team_abbreviation, box_type); CREATE INDEX idx_player_box_scores_player ON player_box_scores(player_id); CREATE INDEX idx_player_game_stats_player ON player_game_stats(player_id, game_id); CREATE INDEX idx_player_game_stats_game ON player_game_stats(game_id, team_id); CREATE INDEX idx_pbp_game ON play_by_play_events(game_id, row_index); CREATE INDEX idx_pbp_norm_game ON play_by_play_events_normalized(game_id, row_index);""")

    def _game_id(self, url: str) -> str | None:
        match = GAME_ID_RE.search(url or "")
        return match.group(1).upper() if match else None

    def _game_date(self, game_id: str) -> str | None:
        if not game_id or len(game_id) < 8:
            return None
        raw = game_id[:8]
        return f"{raw[:4]}-{raw[4:6]}-{raw[6:8]}"

    def _entity(self, values: dict[str, Any], display: dict[str, Any], links: dict[str, Any], key: str) -> tuple[str | None, str | None, str | None]:
        label = self._text(values.get(key) or display.get(key) or values.get("name_display") or display.get("name_display"))
        url = self._first_url(links.get(key)) or self._first_url(links.get("name_display")) or self._first_url(links)
        entity_id = self._player_id_from_url(url or "") if key == "player" else None
        if key == "team" and url:
            parts = [part for part in str(url).split("/") if part]
            if "teams" in parts:
                index = parts.index("teams")
                if len(parts) > index + 1:
                    entity_id = parts[index + 1]
        return label, url, entity_id

    def _first_url(self, value: Any) -> str | None:
        if isinstance(value, str):
            return value if "/" in value else None
        if isinstance(value, dict):
            for key in ("href", "url"):
                if isinstance(value.get(key), str):
                    return value[key]
            for item in value.values():
                found = self._first_url(item)
                if found:
                    return found
        if isinstance(value, list):
            for item in value:
                found = self._first_url(item)
                if found:
                    return found
        return None

    def _player_id_from_url(self, url: str) -> str | None:
        match = PLAYER_ID_RE.search(url or "")
        return match.group(1) if match else None

    def _player_name_from_title(self, title: str | None) -> str | None:
        if not title:
            return None
        for marker in (" Stats", " NBA", " College"):
            if marker in title:
                return title.split(marker, 1)[0].strip()
        return title.strip() or None

    def _period_clock(self, values: dict[str, Any]) -> tuple[int | None, str | None]:
        for key, period in PERIOD_KEYS.items():
            if key in values and values[key]:
                return period, self._text(values[key])
        for key, value in values.items():
            normalized = key.lower()
            if normalized in PERIOD_KEYS and value:
                return PERIOD_KEYS[normalized], self._text(value)
        return None, None

    def _event_description(self, values: dict[str, Any]) -> str | None:
        for key in ("description", "visitor_play", "home_play", "column_2", "column_3", "play"):
            text = self._text(values.get(key))
            if text and not self._looks_like_score(text) and not self._looks_like_clock(text):
                return text
        for key, value in values.items():
            text = self._text(value)
            if text and key.lower() not in PERIOD_KEYS and not self._looks_like_score(text) and not self._looks_like_clock(text):
                return text
        return None

    def _score(self, values: dict[str, Any]) -> str | None:
        for key in ("score", "visitor_score", "home_score"):
            text = self._text(values.get(key))
            if text:
                return text
        for value in values.values():
            text = self._text(value)
            if text and self._looks_like_score(text):
                return text
        return None

    def _json(self, raw: str | None) -> dict[str, Any]:
        if not raw:
            return {}
        try:
            value = json.loads(raw)
        except json.JSONDecodeError:
            return {}
        return value if isinstance(value, dict) else {}

    def _text(self, value: Any) -> str | None:
        if value is None:
            return None
        text = str(value).strip()
        return text or None

    def _int(self, value: Any) -> int | None:
        number = self._num(value)
        return int(number) if number is not None else None

    def _num(self, value: Any) -> float | None:
        if value is None or value == "":
            return None
        text = str(value).strip().replace("%", "")
        if text in {"", "None"}:
            return None
        if text.startswith("+"):
            text = text[1:]
        try:
            return float(text)
        except (TypeError, ValueError):
            return None

    def _seconds(self, value: Any) -> int | None:
        text = self._text(value)
        if not text:
            return None
        if ":" not in text:
            return self._int(text)
        left, right = text.split(":", 1)
        try:
            return int(left) * 60 + int(float(right))
        except ValueError:
            return None

    def _looks_like_clock(self, text: str) -> bool:
        return bool(re.fullmatch(r"\d{1,2}:\d{2}(?:\.\d)?", text))

    def _looks_like_score(self, text: str) -> bool:
        return bool(re.fullmatch(r"\d{1,3}-\d{1,3}", text))

    def _normalize_name(self, name: str | None) -> str:
        return re.sub(r"[^a-z0-9]", "", (name or "").lower())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a first-pass NBA warehouse from the raw Basketball Reference catalog.")
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
