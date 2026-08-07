from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sqlite3
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

DEFAULT_DATABASE = "data/warehouse/nba_history.sqlite"
DEFAULT_POLICY = "assets/data/nba/metadata/historical_canonical_policy.json"
DEFAULT_REPORT = "data/warehouse/nba_canonical_build_report.json"

SEASON_RE = re.compile(r"(?P<start>19\d{2}|20\d{2})[-_–](?P<end>\d{2}|19\d{2}|20\d{2})")
LEAGUE_SEASON_TABLE_RE = re.compile(
    r"^(?P<league>NBA|ABA|BAA)[_-](?P<start>\d{4})[-_](?P<end>\d{4})[_-](?P<kind>basic|advanced)$",
    re.I,
)
NBA_SEASON_TYPE = {"1": "preseason", "2": "regular", "3": "all_star", "4": "playoffs", "5": "all_star"}

PLAYER_METRICS: dict[str, tuple[str, ...]] = {
    "games": ("g", "gp", "games", "games_played"),
    "games_started": ("gs", "games_started"),
    "minutes": ("mp", "min", "minutes"),
    "fgm": ("fg", "fgm", "field_goals", "field_goals_made"),
    "fga": ("fga", "field_goal_attempts"),
    "fg_pct": ("fg_percent", "fg_pct", "field_goal_percentage"),
    "three_pm": ("n_3p", "fg3", "three_pm", "three_pointers_made"),
    "three_pa": ("n_3pa", "fg3a", "three_pa", "three_point_attempts"),
    "three_pct": ("n_3p_percent", "fg3_pct", "three_pct", "three_point_percentage"),
    "two_pm": ("n_2p", "two_pm", "two_pointers_made"),
    "two_pa": ("n_2pa", "two_pa", "two_point_attempts"),
    "two_pct": ("n_2p_percent", "two_pct", "two_point_percentage"),
    "ftm": ("ft", "ftm", "free_throws", "free_throws_made"),
    "fta": ("fta", "free_throw_attempts"),
    "ft_pct": ("ft_percent", "ft_pct", "free_throw_percentage"),
    "orb": ("orb", "oreb", "offensive_rebounds"),
    "drb": ("drb", "dreb", "defensive_rebounds"),
    "reb": ("trb", "reb", "rebounds", "total_rebounds"),
    "ast": ("ast", "assists"),
    "stl": ("stl", "steals"),
    "blk": ("blk", "blocks"),
    "tov": ("tov", "turnovers"),
    "pf": ("pf", "personal_fouls"),
    "pts": ("pts", "points"),
    "per": ("per",),
    "ts_pct": ("ts_percent", "ts_pct", "true_shooting_percentage"),
    "efg_pct": ("efg_percent", "efg_pct", "effective_field_goal_percentage"),
    "ws": ("ws", "win_shares"),
    "ws48": ("ws_per_48", "ws_48", "win_shares_per_48"),
    "obpm": ("obpm", "offensive_box_plus_minus"),
    "dbpm": ("dbpm", "defensive_box_plus_minus"),
    "bpm": ("bpm", "box_plus_minus"),
    "vorp": ("vorp",),
    "usg_pct": ("usg_percent", "usg_pct", "usage_percentage"),
    "ortg": ("off_rtg", "ortg", "offensive_rating"),
    "drtg": ("def_rtg", "drtg", "defensive_rating"),
}

TEAM_METRICS: dict[str, tuple[str, ...]] = {
    "games": ("g", "games", "gp"),
    "wins": ("w", "wins"),
    "losses": ("l", "losses"),
    "minutes": ("mp", "minutes"),
    "pts": ("pts", "points"),
    "opp_pts": ("opp_pts", "opponent_points"),
    "fgm": ("fg", "fgm"),
    "fga": ("fga",),
    "three_pm": ("n_3p", "fg3", "three_pm"),
    "three_pa": ("n_3pa", "fg3a", "three_pa"),
    "ftm": ("ft", "ftm"),
    "fta": ("fta",),
    "orb": ("orb", "oreb"),
    "drb": ("drb", "dreb"),
    "reb": ("trb", "reb"),
    "ast": ("ast",),
    "stl": ("stl",),
    "blk": ("blk",),
    "tov": ("tov",),
    "pf": ("pf",),
    "pace": ("pace",),
    "ortg": ("off_rtg", "ortg", "offensive_rating"),
    "drtg": ("def_rtg", "drtg", "defensive_rating"),
    "net_rtg": ("net_rtg", "net_rating"),
    "srs": ("srs",),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build canonical historical NBA dimensions/facts over the lossless historical warehouse.")
    parser.add_argument("--database", default=DEFAULT_DATABASE)
    parser.add_argument("--policy", default=DEFAULT_POLICY)
    parser.add_argument("--report", default=DEFAULT_REPORT)
    parser.add_argument("--skip-player-games", action="store_true")
    return parser.parse_args()


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def q(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def safe(value: Any) -> str:
    return re.sub(r"[^a-z0-9]+", "_", str(value or "").strip().lower()).strip("_")


def norm_name(value: Any) -> str:
    text = str(value or "").lower()
    text = text.replace("’", "'")
    text = re.sub(r"\b(jr|sr|ii|iii|iv)\.?\b", "", text)
    return re.sub(r"[^a-z0-9]+", "", text)


def text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def number(value: Any) -> float | None:
    if value is None or value == "":
        return None
    if isinstance(value, (int, float)):
        result = float(value)
        return result if math.isfinite(result) else None
    raw = str(value).strip().replace(",", "").replace("%", "")
    if raw in {"", "—", "-", "NA", "N/A", "None", "nan"}:
        return None
    try:
        result = float(raw)
        if "%" in str(value):
            result /= 100.0
        return result if math.isfinite(result) else None
    except ValueError:
        return None


def integer(value: Any) -> int | None:
    resolved = number(value)
    return None if resolved is None else int(round(resolved))


def first(row: dict[str, Any], aliases: Iterable[str]) -> Any:
    lowered = {safe(key): value for key, value in row.items()}
    for alias in aliases:
        key = safe(alias)
        if key in lowered and lowered[key] not in (None, ""):
            return lowered[key]
    return None


def table_exists(db: sqlite3.Connection, table: str) -> bool:
    return db.execute("SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name = ?", (table,)).fetchone() is not None


def table_columns(db: sqlite3.Connection, table: str) -> list[str]:
    return [str(row[1]) for row in db.execute(f"PRAGMA table_info({q(table)})").fetchall()]


def table_for_source(db: sqlite3.Connection, source_key: str, source_table: str) -> str | None:
    row = db.execute(
        "SELECT warehouse_table FROM historical_table_inventory WHERE source_key = ? AND lower(source_table) = lower(?) LIMIT 1",
        (source_key, source_table),
    ).fetchone()
    return None if row is None else str(row[0])


def source_tables(db: sqlite3.Connection, source_key: str) -> list[dict[str, Any]]:
    return [dict(row) for row in db.execute(
        "SELECT source_table, warehouse_table, row_count, columns_json FROM historical_table_inventory WHERE source_key = ? ORDER BY source_table",
        (source_key,),
    ).fetchall()]


def rows(db: sqlite3.Connection, table: str) -> Iterable[dict[str, Any]]:
    cursor = db.execute(f"SELECT * FROM {q(table)}")
    names = [item[0] for item in cursor.description]
    for raw in cursor:
        yield {names[index]: raw[index] for index in range(len(names))}


def source_rank(policy: dict[str, Any], domain: str, source_key: str) -> int:
    order = policy.get("sourcePriority", {}).get(domain, [])
    try:
        return list(order).index(source_key)
    except ValueError:
        return 999


def normalize_season(value: Any, *, source_key: str = "", source_table: str = "") -> tuple[str | None, int | None, int | None, str | None]:
    table_match = LEAGUE_SEASON_TABLE_RE.match(source_table)
    if table_match:
        start = int(table_match.group("start"))
        end = int(table_match.group("end"))
        return f"{start}-{str(end)[-2:]}", start, end, "regular"
    raw = text(value).replace("–", "-")
    if not raw:
        return None, None, None, None
    match = SEASON_RE.search(raw)
    if match:
        start = int(match.group("start"))
        end_raw = match.group("end")
        end = int(end_raw) if len(end_raw) == 4 else (start // 100) * 100 + int(end_raw)
        if end <= start:
            end += 100
        return f"{start}-{str(end)[-2:]}", start, end, None
    digits = re.sub(r"\D", "", raw)
    if len(digits) == 5 and digits[0] in NBA_SEASON_TYPE:
        start = int(digits[1:])
        return f"{start}-{str(start + 1)[-2:]}", start, start + 1, NBA_SEASON_TYPE[digits[0]]
    if len(digits) == 4:
        year = int(digits)
        if 1946 <= year <= 2100:
            if source_key in {"sumitro_bref_history", "gonzalo_all_time"}:
                start = year - 1
                end = year
            else:
                start = year
                end = year + 1
            return f"{start}-{str(end)[-2:]}", start, end, None
    return None, None, None, None


def infer_league(row: dict[str, Any], source_table: str, fallback: str = "NBA") -> str:
    match = LEAGUE_SEASON_TABLE_RE.match(source_table)
    if match:
        return match.group("league").upper()
    raw = text(first(row, ("lg", "league", "league_id", "league_name"))).upper()
    if raw in {"NBA", "ABA", "BAA"}:
        return raw
    return fallback


def infer_season_type(row: dict[str, Any], season_hint: str | None = None) -> str:
    raw = text(first(row, ("season_type", "season_segment", "type", "game_type"))).lower()
    if "playoff" in raw or "post" in raw:
        return "playoffs"
    if "pre" in raw:
        return "preseason"
    if "all" in raw and "star" in raw:
        return "all_star"
    return season_hint or "regular"


def material_conflict(left: Any, right: Any, policy: dict[str, Any]) -> bool:
    if left in (None, "") or right in (None, ""):
        return False
    lnum, rnum = number(left), number(right)
    if lnum is not None and rnum is not None:
        absolute = abs(lnum - rnum)
        abs_tol = float(policy.get("conflictPolicy", {}).get("numericAbsoluteTolerance", 1e-6))
        rel_tol = float(policy.get("conflictPolicy", {}).get("numericRelativeTolerance", 0.005))
        scale = max(abs(lnum), abs(rnum), 1.0)
        return absolute > abs_tol and absolute / scale > rel_tol
    return text(left).lower() != text(right).lower()


def load_policy(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def reset_canonical(db: sqlite3.Connection) -> None:
    objects = db.execute("SELECT type, name FROM sqlite_master WHERE name LIKE 'canon_%'").fetchall()
    for kind, name in objects:
        if kind == "view":
            db.execute(f"DROP VIEW IF EXISTS {q(str(name))}")
    for kind, name in objects:
        if kind == "table":
            db.execute(f"DROP TABLE IF EXISTS {q(str(name))}")
    db.commit()


def initialize_schema(db: sqlite3.Connection) -> None:
    db.executescript(
        """
        CREATE TABLE canon_build_manifest(
          build_id TEXT PRIMARY KEY, schema_version TEXT NOT NULL, built_at TEXT NOT NULL,
          source_rows INTEGER NOT NULL, source_tables INTEGER NOT NULL, source_count INTEGER NOT NULL,
          canonical_counts_json TEXT NOT NULL, warnings_json TEXT NOT NULL
        );
        CREATE TABLE canon_source_priority(domain TEXT NOT NULL, source_key TEXT NOT NULL, priority INTEGER NOT NULL, PRIMARY KEY(domain, source_key));
        CREATE TABLE canon_dim_league(league_id TEXT PRIMARY KEY, league_name TEXT NOT NULL, first_season TEXT, last_season TEXT);
        CREATE TABLE canon_dim_season(season_id TEXT PRIMARY KEY, start_year INTEGER NOT NULL, end_year INTEGER NOT NULL, label TEXT NOT NULL);
        CREATE TABLE canon_dim_franchise(franchise_key TEXT PRIMARY KEY, canonical_name TEXT NOT NULL, current_abbreviation TEXT, source_count INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE canon_dim_team(
          team_key TEXT PRIMARY KEY, franchise_key TEXT, canonical_name TEXT NOT NULL, abbreviation TEXT,
          league_id TEXT, active_from TEXT, active_to TEXT, nba_team_id TEXT, source_count INTEGER NOT NULL DEFAULT 1,
          provenance_json TEXT NOT NULL DEFAULT '{}'
        );
        CREATE TABLE canon_team_source_xref(
          source_key TEXT NOT NULL, source_table TEXT NOT NULL, source_id TEXT NOT NULL DEFAULT '', source_name TEXT NOT NULL DEFAULT '',
          source_abbreviation TEXT NOT NULL DEFAULT '', team_key TEXT NOT NULL, match_method TEXT NOT NULL, confidence REAL NOT NULL,
          evidence_json TEXT NOT NULL DEFAULT '{}', PRIMARY KEY(source_key, source_table, source_id, source_name, source_abbreviation)
        );
        CREATE TABLE canon_dim_player(
          player_key TEXT PRIMARY KEY, canonical_name TEXT NOT NULL, normalized_name TEXT NOT NULL,
          nba_id TEXT, bref_id TEXT, birth_date TEXT, birth_year INTEGER, primary_position TEXT,
          active_from TEXT, active_to TEXT, source_count INTEGER NOT NULL, identity_confidence REAL NOT NULL,
          provenance_json TEXT NOT NULL DEFAULT '{}'
        );
        CREATE TABLE canon_player_source_xref(
          source_key TEXT NOT NULL, source_table TEXT NOT NULL, source_id TEXT NOT NULL DEFAULT '', source_name TEXT NOT NULL DEFAULT '',
          player_key TEXT NOT NULL, match_method TEXT NOT NULL, confidence REAL NOT NULL, evidence_json TEXT NOT NULL DEFAULT '{}',
          PRIMARY KEY(source_key, source_table, source_id, source_name)
        );
        CREATE TABLE canon_dim_game(
          game_key TEXT PRIMARY KEY, nba_game_id TEXT, game_date TEXT, season_id TEXT, league_id TEXT,
          season_type TEXT NOT NULL, home_team_key TEXT, away_team_key TEXT, home_score REAL, away_score REAL,
          winner_team_key TEXT, status TEXT, source_count INTEGER NOT NULL, provenance_json TEXT NOT NULL DEFAULT '{}'
        );
        CREATE TABLE canon_game_source_xref(
          source_key TEXT NOT NULL, source_table TEXT NOT NULL, source_id TEXT NOT NULL DEFAULT '', game_key TEXT NOT NULL,
          match_method TEXT NOT NULL, confidence REAL NOT NULL, evidence_json TEXT NOT NULL DEFAULT '{}',
          PRIMARY KEY(source_key, source_table, source_id)
        );
        CREATE TABLE canon_fact_team_game(
          game_key TEXT NOT NULL, team_key TEXT NOT NULL, opponent_team_key TEXT, is_home INTEGER NOT NULL,
          result TEXT, points REAL, opponent_points REAL, fgm REAL, fga REAL, three_pm REAL, three_pa REAL,
          ftm REAL, fta REAL, orb REAL, drb REAL, reb REAL, ast REAL, stl REAL, blk REAL, tov REAL, pf REAL,
          source_key TEXT NOT NULL, provenance_json TEXT NOT NULL DEFAULT '{}', PRIMARY KEY(game_key, team_key)
        );
        CREATE TABLE canon_fact_player_season(
          fact_key TEXT PRIMARY KEY, player_key TEXT NOT NULL, season_id TEXT NOT NULL, league_id TEXT NOT NULL,
          season_type TEXT NOT NULL, team_key TEXT, team_abbreviation TEXT, position TEXT, age REAL,
          games REAL, games_started REAL, minutes REAL, fgm REAL, fga REAL, fg_pct REAL,
          three_pm REAL, three_pa REAL, three_pct REAL, two_pm REAL, two_pa REAL, two_pct REAL,
          ftm REAL, fta REAL, ft_pct REAL, orb REAL, drb REAL, reb REAL, ast REAL, stl REAL, blk REAL,
          tov REAL, pf REAL, pts REAL, per REAL, ts_pct REAL, efg_pct REAL, ws REAL, ws48 REAL,
          obpm REAL, dbpm REAL, bpm REAL, vorp REAL, usg_pct REAL, ortg REAL, drtg REAL,
          primary_source TEXT NOT NULL, source_count INTEGER NOT NULL, provenance_json TEXT NOT NULL
        );
        CREATE INDEX idx_canon_player_season_lookup ON canon_fact_player_season(season_id, league_id, season_type);
        CREATE INDEX idx_canon_player_season_player ON canon_fact_player_season(player_key, season_id);
        CREATE TABLE canon_fact_team_season(
          fact_key TEXT PRIMARY KEY, team_key TEXT, team_abbreviation TEXT, team_name TEXT, season_id TEXT NOT NULL,
          league_id TEXT NOT NULL, season_type TEXT NOT NULL, games REAL, wins REAL, losses REAL, minutes REAL,
          pts REAL, opp_pts REAL, fgm REAL, fga REAL, three_pm REAL, three_pa REAL, ftm REAL, fta REAL,
          orb REAL, drb REAL, reb REAL, ast REAL, stl REAL, blk REAL, tov REAL, pf REAL, pace REAL,
          ortg REAL, drtg REAL, net_rtg REAL, srs REAL, primary_source TEXT NOT NULL, source_count INTEGER NOT NULL,
          provenance_json TEXT NOT NULL
        );
        CREATE INDEX idx_canon_team_season_lookup ON canon_fact_team_season(season_id, league_id);
        CREATE TABLE canon_fact_player_game(
          fact_key TEXT PRIMARY KEY, game_key TEXT, source_game_id TEXT, player_key TEXT, player_name TEXT NOT NULL,
          team_key TEXT, team_abbreviation TEXT, opponent_team_key TEXT, opponent_abbreviation TEXT,
          season_id TEXT NOT NULL, league_id TEXT NOT NULL, season_type TEXT NOT NULL, game_date TEXT,
          minutes REAL, pts REAL, reb REAL, ast REAL, stl REAL, blk REAL, tov REAL, pf REAL,
          ts_pct REAL, efg_pct REAL, usg_pct REAL, ortg REAL, drtg REAL, bpm REAL,
          source_key TEXT NOT NULL, source_table TEXT NOT NULL, source_row INTEGER,
          provenance_json TEXT NOT NULL DEFAULT '{}'
        );
        CREATE INDEX idx_canon_player_game_player ON canon_fact_player_game(player_key, season_id);
        CREATE INDEX idx_canon_player_game_game ON canon_fact_player_game(game_key);
        CREATE TABLE canon_fact_award(
          award_key TEXT PRIMARY KEY, player_key TEXT, player_name TEXT, season_id TEXT, league_id TEXT,
          award TEXT NOT NULL, rank_text TEXT, winner INTEGER, share REAL, source_key TEXT NOT NULL, payload_json TEXT NOT NULL
        );
        CREATE TABLE canon_fact_all_star(
          selection_key TEXT PRIMARY KEY, player_key TEXT, player_name TEXT, season_id TEXT, league_id TEXT,
          team_text TEXT, source_key TEXT NOT NULL, payload_json TEXT NOT NULL
        );
        CREATE TABLE canon_fact_draft(
          draft_key TEXT PRIMARY KEY, player_key TEXT, player_name TEXT, draft_year INTEGER, league_id TEXT,
          round_text TEXT, pick_number REAL, drafting_team_key TEXT, drafting_team_text TEXT,
          source_key TEXT NOT NULL, payload_json TEXT NOT NULL
        );
        CREATE TABLE canon_conflicts(
          conflict_id INTEGER PRIMARY KEY AUTOINCREMENT, entity_type TEXT NOT NULL, entity_key TEXT NOT NULL,
          field_name TEXT NOT NULL, selected_source TEXT NOT NULL, selected_value TEXT,
          alternate_source TEXT NOT NULL, alternate_value TEXT, severity TEXT NOT NULL, detected_at TEXT NOT NULL
        );
        CREATE INDEX idx_canon_conflicts_entity ON canon_conflicts(entity_type, entity_key);
        CREATE TABLE canon_field_provenance(
          entity_type TEXT NOT NULL, entity_key TEXT NOT NULL, field_name TEXT NOT NULL,
          source_key TEXT NOT NULL, source_table TEXT, source_row TEXT, source_value TEXT,
          selected INTEGER NOT NULL, evidence_json TEXT NOT NULL DEFAULT '{}',
          PRIMARY KEY(entity_type, entity_key, field_name, source_key, source_table, source_row)
        );
        CREATE INDEX idx_canon_provenance_entity ON canon_field_provenance(entity_type, entity_key);
        CREATE TABLE canon_coverage(
          domain TEXT NOT NULL, league_id TEXT, season_id TEXT, row_count INTEGER NOT NULL,
          source_count INTEGER NOT NULL, sources_json TEXT NOT NULL,
          PRIMARY KEY(domain, league_id, season_id)
        );
        """
    )


def repair_inventory(db: sqlite3.Connection) -> int:
    repaired = 0
    inventory = db.execute("SELECT source_key, source_table, warehouse_table, columns_json FROM historical_table_inventory").fetchall()
    for source_key, source_table, warehouse_table, columns_json in inventory:
        domain = None
        grain = None
        source_name = str(source_table)
        lower = source_name.lower()
        match = LEAGUE_SEASON_TABLE_RE.match(source_name)
        if str(source_key) == "gonzalo_all_time" and match:
            if match.group("kind").lower() == "advanced":
                domain, grain = "player_game", "player_game"
            else:
                domain, grain = "historical_game_detail", "source_native_game_detail"
        elif str(source_key) == "gonzalo_all_time" and lower in {"advanced_stats", "per_game_stats", "per_minute_stats", "per_poss_stats", "totals_stats"}:
            domain, grain = "player_season", "player_season"
        elif str(source_key) == "gonzalo_all_time" and lower in {"shooting_stats", "adj-shooting", "adj_shooting"}:
            domain, grain = "shot_profile", "player_season"
        elif lower in {"team_summaries", "team_totals", "team_stats_per_game", "team_stats_per_100_poss"}:
            domain, grain = "team_season", "team_season"
        elif lower in {"player_totals", "player_per_game", "per_36_minutes", "per_100_poss", "advanced"}:
            domain, grain = "player_season", "player_season"
        if domain:
            db.execute(
                "UPDATE historical_table_inventory SET domain = ?, grain = ? WHERE source_key = ? AND source_table = ?",
                (domain, grain, source_key, source_table),
            )
            repaired += 1

        # Repair implausible generic season bounds by validating actual values.
        try:
            cols = [str(item.get("name") or "") for item in json.loads(columns_json or "[]")]
        except Exception:
            cols = table_columns(db, str(warehouse_table))
        season_candidates = [c for c in cols if safe(c) in {"season", "season_id", "season_year", "year", "seas_id"}]
        chosen = season_candidates[0] if season_candidates else None
        min_season = max_season = None
        if chosen:
            values = db.execute(
                f"SELECT DISTINCT {q(chosen)} FROM {q(str(warehouse_table))} WHERE {q(chosen)} IS NOT NULL LIMIT 2000"
            ).fetchall()
            normalized = [normalize_season(row[0], source_key=str(source_key), source_table=source_name)[0] for row in values]
            normalized = sorted(value for value in normalized if value)
            if normalized:
                min_season, max_season = normalized[0], normalized[-1]
                db.execute(
                    "UPDATE historical_table_inventory SET season_column = ?, min_season = ?, max_season = ? WHERE source_key = ? AND source_table = ?",
                    (chosen, min_season, max_season, source_key, source_table),
                )
    db.commit()
    return repaired


class UnionFind:
    def __init__(self, size: int) -> None:
        self.parent = list(range(size))

    def find(self, index: int) -> int:
        while self.parent[index] != index:
            self.parent[index] = self.parent[self.parent[index]]
            index = self.parent[index]
        return index

    def union(self, left: int, right: int) -> None:
        a, b = self.find(left), self.find(right)
        if a != b:
            self.parent[b] = a


def player_candidates(db: sqlite3.Connection) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    configured = [
        ("wyatt_nbadb", "player"),
        ("wyatt_nbadb", "common_player_info"),
        ("sumitro_bref_history", "Player Career Info"),
        ("sumitro_bref_history", "Player Season Info"),
        ("gonzalo_all_time", "totals_stats"),
    ]
    seen: set[tuple[str, str, str, str]] = set()
    for source_key, source_table in configured:
        table = table_for_source(db, source_key, source_table)
        if not table:
            continue
        for row in rows(db, table):
            source_id = text(first(row, ("person_id", "player_id", "playerid", "id", "player_key")))
            name = text(first(row, ("display_first_last", "full_name", "player_name", "player", "name")))
            if not name:
                first_name = text(first(row, ("first_name", "firstname")))
                last_name = text(first(row, ("last_name", "lastname")))
                name = f"{first_name} {last_name}".strip()
            if not name:
                continue
            birth_date = text(first(row, ("birthdate", "birth_date", "dob")))
            birth_year = integer(first(row, ("birth_year", "birthyear")))
            if birth_year is None and birth_date:
                match = re.search(r"(19\d{2}|20\d{2})", birth_date)
                birth_year = int(match.group(1)) if match else None
            position = text(first(row, ("position", "pos")))
            from_year = integer(first(row, ("from_year", "from", "first_season")))
            to_year = integer(first(row, ("to_year", "to", "last_season")))
            nba_id = source_id if source_key == "wyatt_nbadb" and source_id.isdigit() else ""
            bref_id = source_id if source_key == "sumitro_bref_history" and source_id and not source_id.isdigit() else ""
            signature = (source_key, source_id, norm_name(name), str(birth_year or ""))
            if signature in seen:
                continue
            seen.add(signature)
            candidates.append({
                "source_key": source_key, "source_table": source_table, "source_id": source_id,
                "name": name, "norm": norm_name(name), "birth_date": birth_date, "birth_year": birth_year,
                "position": position, "from_year": from_year, "to_year": to_year, "nba_id": nba_id, "bref_id": bref_id,
            })
    return candidates


def build_players(db: sqlite3.Connection, policy: dict[str, Any]) -> tuple[dict[tuple[str, str], str], dict[str, str], int]:
    candidates = player_candidates(db)
    uf = UnionFind(len(candidates))
    by_nba: dict[str, int] = {}
    by_bref: dict[str, int] = {}
    by_name_birth: dict[tuple[str, int], int] = {}
    by_name: dict[str, list[int]] = defaultdict(list)
    for index, item in enumerate(candidates):
        if item["nba_id"]:
            if item["nba_id"] in by_nba:
                uf.union(index, by_nba[item["nba_id"]])
            else:
                by_nba[item["nba_id"]] = index
        if item["bref_id"]:
            if item["bref_id"] in by_bref:
                uf.union(index, by_bref[item["bref_id"]])
            else:
                by_bref[item["bref_id"]] = index
        if item["norm"] and item["birth_year"]:
            key = (item["norm"], int(item["birth_year"]))
            if key in by_name_birth:
                uf.union(index, by_name_birth[key])
            else:
                by_name_birth[key] = index
        if item["norm"]:
            by_name[item["norm"]].append(index)
    # Unique-name cross-source matches are safe enough for a historical research crosswalk; ambiguous names stay separate.
    for indexes in by_name.values():
        roots = {uf.find(index) for index in indexes}
        sources = {candidates[index]["source_key"] for index in indexes}
        if len(roots) > 1 and len(sources) > 1:
            birth_values = {candidates[index]["birth_year"] for index in indexes if candidates[index]["birth_year"]}
            if len(birth_values) <= 1:
                base = indexes[0]
                for index in indexes[1:]:
                    uf.union(base, index)
    groups: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for index, item in enumerate(candidates):
        groups[uf.find(index)].append(item)

    id_lookup: dict[tuple[str, str], str] = {}
    name_lookup: dict[str, str] = {}
    for group in groups.values():
        ordered = sorted(group, key=lambda item: source_rank(policy, "identity", item["source_key"]))
        nba_id = next((item["nba_id"] for item in ordered if item["nba_id"]), "")
        bref_id = next((item["bref_id"] for item in ordered if item["bref_id"]), "")
        canonical_name = next((item["name"] for item in ordered if item["name"]), "Unknown")
        normalized = norm_name(canonical_name)
        birth_date = next((item["birth_date"] for item in ordered if item["birth_date"]), "")
        birth_year = next((item["birth_year"] for item in ordered if item["birth_year"]), None)
        position = next((item["position"] for item in ordered if item["position"]), "")
        starts = [item["from_year"] for item in group if item["from_year"] and 1940 <= int(item["from_year"]) <= 2100]
        ends = [item["to_year"] for item in group if item["to_year"] and 1940 <= int(item["to_year"]) <= 2100]
        active_from = f"{min(starts)}-{str(min(starts)+1)[-2:]}" if starts else None
        active_to = f"{max(ends)}-{str(max(ends)+1)[-2:]}" if ends else None
        if nba_id:
            player_key = f"nba_{nba_id}"
            confidence = 1.0
        elif bref_id:
            player_key = f"bref_{safe(bref_id)}"
            confidence = 0.99
        else:
            digest = hashlib.sha1(f"{normalized}|{birth_year or ''}".encode()).hexdigest()[:14]
            player_key = f"p_{digest}"
            confidence = 0.9 if birth_year else 0.8
        sources = sorted({item["source_key"] for item in group})
        provenance = {
            "canonicalName": ordered[0]["source_key"],
            "nbaId": next((item["source_key"] for item in ordered if item["nba_id"]), None),
            "brefId": next((item["source_key"] for item in ordered if item["bref_id"]), None),
            "birth": next((item["source_key"] for item in ordered if item["birth_date"] or item["birth_year"]), None),
            "position": next((item["source_key"] for item in ordered if item["position"]), None),
        }
        db.execute(
            "INSERT INTO canon_dim_player VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (player_key, canonical_name, normalized, nba_id or None, bref_id or None, birth_date or None, birth_year,
             position or None, active_from, active_to, len(sources), confidence, json.dumps(provenance, sort_keys=True)),
        )
        for item in group:
            method = "nba_id" if item["nba_id"] and nba_id and item["nba_id"] == nba_id else (
                "bref_id" if item["bref_id"] and bref_id and item["bref_id"] == bref_id else (
                    "name_birth" if item["birth_year"] and birth_year == item["birth_year"] else "unique_name"
                )
            )
            match_confidence = 1.0 if method in {"nba_id", "bref_id"} else (0.96 if method == "name_birth" else 0.86)
            db.execute(
                "INSERT OR REPLACE INTO canon_player_source_xref VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (item["source_key"], item["source_table"], item["source_id"], item["name"], player_key,
                 method, match_confidence, json.dumps({"birthYear": item["birth_year"], "normalizedName": item["norm"]})),
            )
            if item["source_id"]:
                id_lookup[(item["source_key"], item["source_id"])] = player_key
        if normalized and normalized not in name_lookup:
            name_lookup[normalized] = player_key
    db.commit()
    return id_lookup, name_lookup, len(groups)


def team_candidates(db: sqlite3.Connection) -> list[dict[str, Any]]:
    configured = [
        ("wyatt_nbadb", "team"), ("wyatt_nbadb", "team_history"),
        ("sumitro_bref_history", "Team Abbrev"), ("sumitro_bref_history", "Team Summaries"),
        ("gonzalo_all_time", "all_time_teams"), ("gonzalo_all_time", "current_teams"),
    ]
    candidates: list[dict[str, Any]] = []
    seen: set[tuple[str, str, str, str]] = set()
    for source_key, source_table in configured:
        table = table_for_source(db, source_key, source_table)
        if not table:
            continue
        for row in rows(db, table):
            source_id = text(first(row, ("team_id", "id", "teamid")))
            abbreviation = text(first(row, ("team_abbreviation", "abbreviation", "abbr", "tm", "team"))).upper()
            name = text(first(row, ("team_name", "full_name", "name", "franchise", "team")))
            if name == abbreviation:
                name = ""
            if not (source_id or abbreviation or name):
                continue
            league = infer_league(row, source_table)
            signature = (source_key, source_id, abbreviation, norm_name(name))
            if signature in seen:
                continue
            seen.add(signature)
            candidates.append({"source_key": source_key, "source_table": source_table, "source_id": source_id,
                               "abbreviation": abbreviation, "name": name, "league": league})
    return candidates


def build_teams(db: sqlite3.Connection, policy: dict[str, Any]) -> tuple[dict[tuple[str, str], str], dict[str, str], int]:
    candidates = team_candidates(db)
    aliases = {str(key).upper(): str(value) for key, value in policy.get("modernFranchiseAliases", {}).items()}
    grouped: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for item in candidates:
        token = item["source_id"] if item["source_key"] == "wyatt_nbadb" and item["source_id"] else item["abbreviation"] or norm_name(item["name"])
        grouped[(item["league"], token)].append(item)
    id_lookup: dict[tuple[str, str], str] = {}
    abbr_lookup: dict[str, str] = {}
    franchises: dict[str, dict[str, Any]] = {}
    for (league, token), group in grouped.items():
        ordered = sorted(group, key=lambda item: source_rank(policy, "identity", item["source_key"]))
        source_id = next((item["source_id"] for item in ordered if item["source_id"] and item["source_key"] == "wyatt_nbadb"), "")
        abbreviation = next((item["abbreviation"] for item in ordered if item["abbreviation"]), "")
        name = next((item["name"] for item in ordered if item["name"]), abbreviation or token)
        franchise_alias = aliases.get(abbreviation) or norm_name(name) or safe(token)
        franchise_key = f"fr_{safe(franchise_alias)}"
        team_key = f"nba_team_{source_id}" if source_id else f"team_{safe(league)}_{safe(abbreviation or token)}"
        sources = sorted({item["source_key"] for item in group})
        db.execute(
            "INSERT OR REPLACE INTO canon_dim_team(team_key, franchise_key, canonical_name, abbreviation, league_id, nba_team_id, source_count, provenance_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (team_key, franchise_key, name, abbreviation or None, league, source_id or None, len(sources),
             json.dumps({"name": ordered[0]["source_key"], "abbreviation": next((x["source_key"] for x in ordered if x["abbreviation"]), None)})),
        )
        franchises.setdefault(franchise_key, {"name": name, "abbr": abbreviation, "sources": set()})["sources"].update(sources)
        for item in group:
            db.execute(
                "INSERT OR REPLACE INTO canon_team_source_xref VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (item["source_key"], item["source_table"], item["source_id"], item["name"], item["abbreviation"],
                 team_key, "stable_id" if item["source_id"] and source_id == item["source_id"] else "league_abbreviation",
                 1.0 if item["source_id"] and source_id == item["source_id"] else 0.93,
                 json.dumps({"league": item["league"]})),
            )
            if item["source_id"]:
                id_lookup[(item["source_key"], item["source_id"])] = team_key
        if abbreviation:
            abbr_lookup[abbreviation] = team_key
    for franchise_key, item in franchises.items():
        db.execute("INSERT OR REPLACE INTO canon_dim_franchise VALUES (?, ?, ?, ?)",
                   (franchise_key, item["name"], item["abbr"] or None, len(item["sources"])))
    db.commit()
    return id_lookup, abbr_lookup, len(grouped)


def resolve_player(source_key: str, row: dict[str, Any], id_lookup: dict[tuple[str, str], str], name_lookup: dict[str, str]) -> str | None:
    source_id = text(first(row, ("person_id", "player_id", "playerid", "id")))
    if source_id and (source_key, source_id) in id_lookup:
        return id_lookup[(source_key, source_id)]
    name = text(first(row, ("display_first_last", "player_name", "player", "name")))
    return name_lookup.get(norm_name(name)) if name else None


def resolve_team(source_key: str, row: dict[str, Any], id_lookup: dict[tuple[str, str], str], abbr_lookup: dict[str, str], *, id_aliases: tuple[str, ...] = ("team_id",), abbr_aliases: tuple[str, ...] = ("team_abbreviation", "tm", "team")) -> str | None:
    source_id = text(first(row, id_aliases))
    if source_id and (source_key, source_id) in id_lookup:
        return id_lookup[(source_key, source_id)]
    abbreviation = text(first(row, abbr_aliases)).upper()
    return abbr_lookup.get(abbreviation) if abbreviation else None


def ensure_season(db: sqlite3.Connection, season_id: str | None, start: int | None, end: int | None) -> None:
    if not season_id or start is None or end is None:
        return
    db.execute("INSERT OR IGNORE INTO canon_dim_season VALUES (?, ?, ?, ?)", (season_id, start, end, season_id))


def record_conflict(db: sqlite3.Connection, entity_type: str, entity_key: str, field: str, selected_source: str, selected: Any, alternate_source: str, alternate: Any) -> None:
    db.execute(
        "INSERT INTO canon_conflicts(entity_type, entity_key, field_name, selected_source, selected_value, alternate_source, alternate_value, severity, detected_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'material', ?)",
        (entity_type, entity_key, field, selected_source, text(selected), alternate_source, text(alternate), now_iso()),
    )


def merge_fact(accumulator: dict[str, dict[str, Any]], key: str, incoming: dict[str, Any], source_key: str, source_table: str, policy: dict[str, Any], domain: str, db: sqlite3.Connection) -> None:
    current = accumulator.get(key)
    if current is None:
        incoming["_sources"] = {source_key}
        incoming["_provenance"] = {field: source_key for field, value in incoming.items() if not field.startswith("_") and value not in (None, "")}
        incoming["_source_table"] = {field: source_table for field in incoming["_provenance"]}
        accumulator[key] = incoming
        return
    current["_sources"].add(source_key)
    for field, value in incoming.items():
        if field.startswith("_") or value in (None, ""):
            continue
        existing = current.get(field)
        existing_source = current["_provenance"].get(field)
        if existing in (None, ""):
            current[field] = value
            current["_provenance"][field] = source_key
            current["_source_table"][field] = source_table
            continue
        if not material_conflict(existing, value, policy):
            continue
        incoming_rank = source_rank(policy, domain, source_key)
        existing_rank = source_rank(policy, domain, existing_source or "")
        if incoming_rank < existing_rank:
            record_conflict(db, domain, key, field, source_key, value, existing_source or "unknown", existing)
            current[field] = value
            current["_provenance"][field] = source_key
            current["_source_table"][field] = source_table
        else:
            record_conflict(db, domain, key, field, existing_source or "unknown", existing, source_key, value)


def extract_player_fact(row: dict[str, Any], source_key: str, source_table: str, player_ids: dict[tuple[str, str], str], player_names: dict[str, str], team_ids: dict[tuple[str, str], str], team_abbrs: dict[str, str]) -> tuple[str, dict[str, Any]] | None:
    player_key = resolve_player(source_key, row, player_ids, player_names)
    player_name = text(first(row, ("player", "player_name", "name", "display_first_last")))
    if not player_key and player_name:
        digest = hashlib.sha1(norm_name(player_name).encode()).hexdigest()[:14]
        player_key = f"unresolved_{digest}"
    if not player_key:
        return None
    season_raw = first(row, ("season", "season_id", "seas_id", "year"))
    season_id, start, end, type_hint = normalize_season(season_raw, source_key=source_key, source_table=source_table)
    if not season_id:
        table_match = LEAGUE_SEASON_TABLE_RE.match(source_table)
        if table_match:
            season_id, start, end, type_hint = normalize_season("", source_key=source_key, source_table=source_table)
    if not season_id:
        return None
    league = infer_league(row, source_table)
    season_type = infer_season_type(row, type_hint)
    team_abbr = text(first(row, ("tm", "team_abbreviation", "team", "team_abbr"))).upper()
    team_key = resolve_team(source_key, row, team_ids, team_abbrs) or team_abbrs.get(team_abbr)
    position = text(first(row, ("pos", "position")))
    age = number(first(row, ("age",)))
    values: dict[str, Any] = {
        "player_key": player_key, "season_id": season_id, "start_year": start, "end_year": end,
        "league_id": league, "season_type": season_type, "team_key": team_key,
        "team_abbreviation": team_abbr or None, "position": position or None, "age": age,
    }
    for field, aliases in PLAYER_METRICS.items():
        values[field] = number(first(row, aliases))
    fact_key = "|".join([player_key, season_id, league, season_type, team_abbr or "ALL"])
    return fact_key, values


def build_player_seasons(db: sqlite3.Connection, policy: dict[str, Any], player_ids: dict[tuple[str, str], str], player_names: dict[str, str], team_ids: dict[tuple[str, str], str], team_abbrs: dict[str, str]) -> int:
    facts: dict[str, dict[str, Any]] = {}
    sources = [
        ("sumitro_bref_history", "Player Totals"),
        ("sumitro_bref_history", "Advanced"),
        ("sumitro_bref_history", "Player Season Info"),
        ("gonzalo_all_time", "totals_stats"),
        ("gonzalo_all_time", "advanced_stats"),
    ]
    for source_key, source_table in sources:
        table = table_for_source(db, source_key, source_table)
        if not table:
            continue
        for row in rows(db, table):
            resolved = extract_player_fact(row, source_key, source_table, player_ids, player_names, team_ids, team_abbrs)
            if not resolved:
                continue
            key, payload = resolved
            ensure_season(db, payload.pop("season_id"), payload.pop("start_year"), payload.pop("end_year"))
            # Restore season after dimension insert.
            season_id, start, end, _ = normalize_season(first(row, ("season", "season_id", "seas_id", "year")), source_key=source_key, source_table=source_table)
            payload["season_id"] = season_id
            merge_fact(facts, key, payload, source_key, source_table, policy, "player_season", db)
    fields = ["player_key", "season_id", "league_id", "season_type", "team_key", "team_abbreviation", "position", "age", *PLAYER_METRICS.keys()]
    for fact_key, payload in facts.items():
        primary_source = min(payload["_sources"], key=lambda source: source_rank(policy, "player_season", source))
        values = [payload.get(field) for field in fields]
        placeholders = ",".join("?" for _ in range(4 + len(fields)))
        db.execute(
            f"INSERT INTO canon_fact_player_season(fact_key,{','.join(q(field) for field in fields)},primary_source,source_count,provenance_json) VALUES ({placeholders})",
            (fact_key, *values, primary_source, len(payload["_sources"]), json.dumps(payload["_provenance"], sort_keys=True)),
        )
        for field, source in payload["_provenance"].items():
            if field in {"start_year", "end_year"}:
                continue
            db.execute(
                "INSERT OR IGNORE INTO canon_field_provenance VALUES ('player_season', ?, ?, ?, ?, NULL, ?, 1, '{}')",
                (fact_key, field, source, payload["_source_table"].get(field), text(payload.get(field))),
            )
    db.commit()
    return len(facts)


def extract_team_fact(row: dict[str, Any], source_key: str, source_table: str, team_ids: dict[tuple[str, str], str], team_abbrs: dict[str, str]) -> tuple[str, dict[str, Any]] | None:
    season_id, start, end, type_hint = normalize_season(first(row, ("season", "season_id", "year")), source_key=source_key, source_table=source_table)
    if not season_id:
        return None
    league = infer_league(row, source_table)
    season_type = infer_season_type(row, type_hint)
    abbreviation = text(first(row, ("tm", "team_abbreviation", "abbr", "team"))).upper()
    team_name = text(first(row, ("team_name", "name", "team")))
    team_key = resolve_team(source_key, row, team_ids, team_abbrs) or team_abbrs.get(abbreviation)
    values: dict[str, Any] = {
        "team_key": team_key, "team_abbreviation": abbreviation or None, "team_name": team_name or None,
        "season_id": season_id, "start_year": start, "end_year": end, "league_id": league, "season_type": season_type,
    }
    for field, aliases in TEAM_METRICS.items():
        values[field] = number(first(row, aliases))
    key = "|".join([team_key or abbreviation or norm_name(team_name), season_id, league, season_type])
    return key, values


def build_team_seasons(db: sqlite3.Connection, policy: dict[str, Any], team_ids: dict[tuple[str, str], str], team_abbrs: dict[str, str]) -> int:
    facts: dict[str, dict[str, Any]] = {}
    for source_key, source_table in [
        ("sumitro_bref_history", "Team Totals"), ("sumitro_bref_history", "Team Summaries"),
        ("sumitro_bref_history", "Team Stats Per 100 Poss"), ("gonzalo_all_time", "all_time_teams"),
    ]:
        table = table_for_source(db, source_key, source_table)
        if not table:
            continue
        for row in rows(db, table):
            resolved = extract_team_fact(row, source_key, source_table, team_ids, team_abbrs)
            if not resolved:
                continue
            key, payload = resolved
            ensure_season(db, payload.pop("season_id"), payload.pop("start_year"), payload.pop("end_year"))
            season_id, _, _, _ = normalize_season(first(row, ("season", "season_id", "year")), source_key=source_key, source_table=source_table)
            payload["season_id"] = season_id
            merge_fact(facts, key, payload, source_key, source_table, policy, "team_season", db)
    fields = ["team_key", "team_abbreviation", "team_name", "season_id", "league_id", "season_type", *TEAM_METRICS.keys()]
    for fact_key, payload in facts.items():
        primary = min(payload["_sources"], key=lambda source: source_rank(policy, "team_season", source))
        values = [payload.get(field) for field in fields]
        placeholders = ",".join("?" for _ in range(4 + len(fields)))
        db.execute(
            f"INSERT INTO canon_fact_team_season(fact_key,{','.join(q(field) for field in fields)},primary_source,source_count,provenance_json) VALUES ({placeholders})",
            (fact_key, *values, primary, len(payload["_sources"]), json.dumps(payload["_provenance"], sort_keys=True)),
        )
    db.commit()
    return len(facts)


def home_away_value(row: dict[str, Any], side: str, aliases: Iterable[str]) -> Any:
    expanded: list[str] = []
    for alias in aliases:
        expanded.extend((f"{alias}_{side}", f"{side}_{alias}"))
    return first(row, expanded)


def build_games(db: sqlite3.Connection, policy: dict[str, Any], team_ids: dict[tuple[str, str], str], team_abbrs: dict[str, str]) -> tuple[int, int]:
    game_table = table_for_source(db, "wyatt_nbadb", "game")
    if not game_table:
        return 0, 0
    game_count = team_game_count = 0
    for row in rows(db, game_table):
        game_id = text(first(row, ("game_id", "id")))
        if not game_id:
            continue
        season_id, start, end, type_hint = normalize_season(first(row, ("season_id", "season", "year")), source_key="wyatt_nbadb", source_table="game")
        if season_id:
            ensure_season(db, season_id, start, end)
        league = infer_league(row, "game")
        season_type = infer_season_type(row, type_hint)
        game_date = text(first(row, ("game_date", "game_date_est", "date")))
        home_id = text(first(row, ("team_id_home", "home_team_id")))
        away_id = text(first(row, ("team_id_away", "away_team_id", "team_id_visitor")))
        home_abbr = text(first(row, ("team_abbreviation_home", "home_team_abbreviation"))).upper()
        away_abbr = text(first(row, ("team_abbreviation_away", "away_team_abbreviation", "visitor_team_abbreviation"))).upper()
        home_key = team_ids.get(("wyatt_nbadb", home_id)) or team_abbrs.get(home_abbr)
        away_key = team_ids.get(("wyatt_nbadb", away_id)) or team_abbrs.get(away_abbr)
        home_score = number(home_away_value(row, "home", ("pts", "points")))
        away_score = number(home_away_value(row, "away", ("pts", "points")))
        if away_score is None:
            away_score = number(home_away_value(row, "visitor", ("pts", "points")))
        winner = home_key if home_score is not None and away_score is not None and home_score > away_score else (away_key if home_score is not None and away_score is not None and away_score > home_score else None)
        game_key = f"nba_game_{safe(game_id)}"
        db.execute(
            "INSERT OR REPLACE INTO canon_dim_game VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)",
            (game_key, game_id, game_date or None, season_id, league, season_type, home_key, away_key, home_score, away_score,
             winner, text(first(row, ("game_status_text", "status"))) or None,
             json.dumps({"game": "wyatt_nbadb", "score": "wyatt_nbadb"})),
        )
        db.execute(
            "INSERT OR REPLACE INTO canon_game_source_xref VALUES ('wyatt_nbadb','game',?,?, 'nba_game_id',1.0,'{}')",
            (game_id, game_key),
        )
        game_count += 1
        for side, team_key, opponent_key, points, opponent_points in [
            ("home", home_key, away_key, home_score, away_score), ("away", away_key, home_key, away_score, home_score)
        ]:
            if not team_key:
                continue
            metrics = {}
            for field, aliases in {k: v for k, v in TEAM_METRICS.items() if k not in {"games", "wins", "losses", "pace", "ortg", "drtg", "net_rtg", "srs"}}.items():
                metrics[field] = number(home_away_value(row, side, aliases))
            result = None
            if points is not None and opponent_points is not None:
                result = "W" if points > opponent_points else ("L" if points < opponent_points else "T")
            db.execute(
                """
                INSERT OR REPLACE INTO canon_fact_team_game(
                  game_key,team_key,opponent_team_key,is_home,result,points,opponent_points,fgm,fga,three_pm,three_pa,ftm,fta,orb,drb,reb,ast,stl,blk,tov,pf,source_key,provenance_json
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                (game_key, team_key, opponent_key, 1 if side == "home" else 0, result, points, opponent_points,
                 metrics.get("fgm"), metrics.get("fga"), metrics.get("three_pm"), metrics.get("three_pa"),
                 metrics.get("ftm"), metrics.get("fta"), metrics.get("orb"), metrics.get("drb"), metrics.get("reb"),
                 metrics.get("ast"), metrics.get("stl"), metrics.get("blk"), metrics.get("tov"), metrics.get("pf"),
                 "wyatt_nbadb", json.dumps({"all": "wyatt_nbadb"})),
            )
            team_game_count += 1
    db.commit()
    return game_count, team_game_count


def create_play_by_play_view(db: sqlite3.Connection) -> bool:
    table = table_for_source(db, "wyatt_nbadb", "play_by_play")
    if not table:
        return False
    columns = {safe(column): column for column in table_columns(db, table)}
    def expr(aliases: Iterable[str], default: str = "NULL") -> str:
        for alias in aliases:
            key = safe(alias)
            if key in columns:
                return f"p.{q(columns[key])}"
        return default
    game_id = expr(("game_id",))
    event_num = expr(("eventnum", "event_num", "event_number", "action_number"))
    period = expr(("period",))
    clock = expr(("pctimestring", "clock", "game_clock"))
    home_desc = expr(("homedescription", "home_description"), "''")
    neutral_desc = expr(("neutraldescription", "neutral_description"), "''")
    visitor_desc = expr(("visitordescription", "visitor_description", "away_description"), "''")
    score = expr(("score",))
    margin = expr(("scoremargin", "score_margin"))
    player1 = expr(("player1_id", "person1_id"))
    player2 = expr(("player2_id", "person2_id"))
    player3 = expr(("player3_id", "person3_id"))
    db.execute("DROP VIEW IF EXISTS canon_fact_play_by_play")
    db.execute(
        f"""
        CREATE VIEW canon_fact_play_by_play AS
        SELECT gx.game_key,
               CAST({game_id} AS TEXT) AS source_game_id,
               {event_num} AS event_number,
               {period} AS period,
               {clock} AS clock,
               TRIM(COALESCE(CAST({home_desc} AS TEXT),'') || CASE WHEN COALESCE(CAST({neutral_desc} AS TEXT),'') <> '' THEN ' | ' || CAST({neutral_desc} AS TEXT) ELSE '' END || CASE WHEN COALESCE(CAST({visitor_desc} AS TEXT),'') <> '' THEN ' | ' || CAST({visitor_desc} AS TEXT) ELSE '' END) AS description,
               {score} AS score,
               {margin} AS score_margin,
               CAST({player1} AS TEXT) AS player1_source_id,
               p1.player_key AS player1_key,
               CAST({player2} AS TEXT) AS player2_source_id,
               p2.player_key AS player2_key,
               CAST({player3} AS TEXT) AS player3_source_id,
               p3.player_key AS player3_key,
               'wyatt_nbadb' AS source_key
        FROM {q(table)} p
        LEFT JOIN canon_game_source_xref gx ON gx.source_key='wyatt_nbadb' AND gx.source_table='game' AND gx.source_id=CAST({game_id} AS TEXT)
        LEFT JOIN canon_player_source_xref p1 ON p1.source_key='wyatt_nbadb' AND p1.source_id=CAST({player1} AS TEXT)
        LEFT JOIN canon_player_source_xref p2 ON p2.source_key='wyatt_nbadb' AND p2.source_id=CAST({player2} AS TEXT)
        LEFT JOIN canon_player_source_xref p3 ON p3.source_key='wyatt_nbadb' AND p3.source_id=CAST({player3} AS TEXT)
        """
    )
    return True


def build_player_games(db: sqlite3.Connection, player_ids: dict[tuple[str, str], str], player_names: dict[str, str], team_ids: dict[tuple[str, str], str], team_abbrs: dict[str, str]) -> int:
    inventory = source_tables(db, "gonzalo_all_time")
    game_lookup: dict[str, str] = {}
    for row in db.execute("SELECT nba_game_id, game_key FROM canon_dim_game WHERE nba_game_id IS NOT NULL"):
        game_lookup[str(row[0])] = str(row[1])
    inserted = 0
    for item in inventory:
        source_table = str(item["source_table"])
        match = LEAGUE_SEASON_TABLE_RE.match(source_table)
        if not match or match.group("kind").lower() != "advanced":
            continue
        # Player-game candidates are intentionally signature-gated. If a third-party revision changes grain,
        # the table remains losslessly available but is not misrepresented as canonical player-game data.
        table = str(item["warehouse_table"])
        cols = {safe(column) for column in table_columns(db, table)}
        has_player = bool(cols & {"player", "player_name", "player_id", "name"})
        has_game_identity = bool(cols & {"game_id", "gameid", "date", "game_date", "game_date_est"})
        has_metric = bool(cols & {"pts", "points", "mp", "minutes", "ts_percent", "ts_pct", "bpm"})
        if not (has_player and has_game_identity and has_metric):
            continue
        season_id = f"{match.group('start')}-{match.group('end')[-2:]}"
        league = match.group("league").upper()
        ensure_season(db, season_id, int(match.group("start")), int(match.group("end")))
        batch: list[tuple[Any, ...]] = []
        for row in rows(db, table):
            player_name = text(first(row, ("player", "player_name", "name")))
            player_key = resolve_player("gonzalo_all_time", row, player_ids, player_names) or player_names.get(norm_name(player_name))
            team_abbr = text(first(row, ("team", "tm", "team_abbreviation"))).upper()
            opp_abbr = text(first(row, ("opp", "opponent", "opponent_team", "opponent_abbreviation"))).upper()
            team_key = team_abbrs.get(team_abbr)
            opponent_key = team_abbrs.get(opp_abbr)
            source_game_id = text(first(row, ("game_id", "gameid")))
            game_key = game_lookup.get(source_game_id) if source_game_id else None
            source_row = integer(first(row, ("__source_row",)))
            fact_key = f"gonzalo|{safe(source_table)}|{source_row or inserted+1}"
            batch.append((
                fact_key, game_key, source_game_id or None, player_key, player_name or "Unknown", team_key, team_abbr or None,
                opponent_key, opp_abbr or None, season_id, league, infer_season_type(row),
                text(first(row, ("date", "game_date", "game_date_est"))) or None,
                number(first(row, ("mp", "minutes", "min"))), number(first(row, ("pts", "points"))),
                number(first(row, ("trb", "reb", "rebounds"))), number(first(row, ("ast", "assists"))),
                number(first(row, ("stl", "steals"))), number(first(row, ("blk", "blocks"))),
                number(first(row, ("tov", "turnovers"))), number(first(row, ("pf", "personal_fouls"))),
                number(first(row, ("ts_percent", "ts_pct"))), number(first(row, ("efg_percent", "efg_pct"))),
                number(first(row, ("usg_percent", "usg_pct"))), number(first(row, ("off_rtg", "ortg"))),
                number(first(row, ("def_rtg", "drtg"))), number(first(row, ("bpm",))),
                "gonzalo_all_time", source_table, source_row, json.dumps({"all": "gonzalo_all_time"}),
            ))
            if len(batch) >= 10000:
                db.executemany("INSERT OR REPLACE INTO canon_fact_player_game VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", batch)
                inserted += len(batch)
                batch.clear()
        if batch:
            db.executemany("INSERT OR REPLACE INTO canon_fact_player_game VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", batch)
            inserted += len(batch)
        db.commit()
    return inserted


def build_events_awards_draft(db: sqlite3.Connection, player_ids: dict[tuple[str, str], str], player_names: dict[str, str], team_ids: dict[tuple[str, str], str], team_abbrs: dict[str, str]) -> tuple[int, int, int]:
    award_count = all_star_count = draft_count = 0
    for source_table in ("Player Award Shares", "End of Season Teams", "End of Season Teams (Voting)"):
        table = table_for_source(db, "sumitro_bref_history", source_table)
        if not table:
            continue
        for row in rows(db, table):
            player_name = text(first(row, ("player", "player_name", "name")))
            player_key = resolve_player("sumitro_bref_history", row, player_ids, player_names) or player_names.get(norm_name(player_name))
            season_id, start, end, _ = normalize_season(first(row, ("season", "year")), source_key="sumitro_bref_history", source_table=source_table)
            ensure_season(db, season_id, start, end)
            league = infer_league(row, source_table)
            award = text(first(row, ("award", "award_name", "type", "team"))) or source_table
            rank_text = text(first(row, ("rank", "rank_text", "place"))) or None
            share = number(first(row, ("share", "pts_won", "points_won", "vote_share")))
            winner_raw = first(row, ("winner", "is_winner", "first"))
            winner = 1 if str(winner_raw).strip().lower() in {"1", "true", "yes", "y"} or rank_text == "1" else 0
            payload = json.dumps(row, ensure_ascii=False, default=str)
            key = hashlib.sha1(f"{source_table}|{player_name}|{season_id}|{award}|{payload}".encode()).hexdigest()[:20]
            db.execute("INSERT OR REPLACE INTO canon_fact_award VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                       (f"award_{key}", player_key, player_name or None, season_id, league, award, rank_text, winner, share, "sumitro_bref_history", payload))
            award_count += 1

    table = table_for_source(db, "sumitro_bref_history", "All-Star Selections")
    if table:
        for row in rows(db, table):
            player_name = text(first(row, ("player", "player_name", "name")))
            player_key = resolve_player("sumitro_bref_history", row, player_ids, player_names) or player_names.get(norm_name(player_name))
            season_id, start, end, _ = normalize_season(first(row, ("season", "year")), source_key="sumitro_bref_history", source_table="All-Star Selections")
            ensure_season(db, season_id, start, end)
            league = infer_league(row, "All-Star Selections")
            payload = json.dumps(row, ensure_ascii=False, default=str)
            key = hashlib.sha1(f"{player_name}|{season_id}|{payload}".encode()).hexdigest()[:20]
            db.execute("INSERT OR REPLACE INTO canon_fact_all_star VALUES (?,?,?,?,?,?,?,?)",
                       (f"allstar_{key}", player_key, player_name or None, season_id, league,
                        text(first(row, ("team", "selection", "type"))) or None, "sumitro_bref_history", payload))
            all_star_count += 1

    table = table_for_source(db, "sumitro_bref_history", "Draft Pick History")
    if table:
        for row in rows(db, table):
            player_name = text(first(row, ("player", "player_name", "name")))
            player_key = resolve_player("sumitro_bref_history", row, player_ids, player_names) or player_names.get(norm_name(player_name))
            draft_year = integer(first(row, ("season", "year", "draft_year")))
            league = infer_league(row, "Draft Pick History")
            team_text = text(first(row, ("tm", "team", "team_abbreviation"))).upper()
            team_key = team_abbrs.get(team_text)
            round_text = text(first(row, ("round", "round_number", "round_pick"))) or None
            pick_number = number(first(row, ("pick", "pick_number", "overall_pick", "overall")))
            payload = json.dumps(row, ensure_ascii=False, default=str)
            key = hashlib.sha1(f"{draft_year}|{player_name}|{pick_number}|{payload}".encode()).hexdigest()[:20]
            db.execute("INSERT OR REPLACE INTO canon_fact_draft VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                       (f"draft_{key}", player_key, player_name or None, draft_year, league, round_text, pick_number,
                        team_key, team_text or None, "sumitro_bref_history", payload))
            draft_count += 1
    db.commit()
    return award_count, all_star_count, draft_count


def build_coverage(db: sqlite3.Connection) -> int:
    db.execute("DELETE FROM canon_coverage")
    domains = [
        ("player_season", "canon_fact_player_season", "league_id", "season_id", "primary_source"),
        ("team_season", "canon_fact_team_season", "league_id", "season_id", "primary_source"),
        ("player_game", "canon_fact_player_game", "league_id", "season_id", "source_key"),
        ("game", "canon_dim_game", "league_id", "season_id", None),
        ("award", "canon_fact_award", "league_id", "season_id", "source_key"),
        ("all_star", "canon_fact_all_star", "league_id", "season_id", "source_key"),
    ]
    inserted = 0
    for domain, table, league_col, season_col, source_col in domains:
        if not table_exists(db, table):
            continue
        if source_col:
            query = f"SELECT {q(league_col)}, {q(season_col)}, COUNT(*), COUNT(DISTINCT {q(source_col)}), GROUP_CONCAT(DISTINCT {q(source_col)}) FROM {q(table)} GROUP BY {q(league_col)}, {q(season_col)}"
        else:
            query = f"SELECT {q(league_col)}, {q(season_col)}, COUNT(*), 1, 'wyatt_nbadb' FROM {q(table)} GROUP BY {q(league_col)}, {q(season_col)}"
        for league, season, count, source_count, source_list in db.execute(query):
            if season is None:
                continue
            sources = sorted(set(str(source_list or "").split(",")))
            db.execute("INSERT OR REPLACE INTO canon_coverage VALUES (?, ?, ?, ?, ?, ?)",
                       (domain, league, season, int(count), int(source_count), json.dumps([s for s in sources if s])))
            inserted += 1
    db.commit()
    return inserted


def update_league_bounds(db: sqlite3.Connection) -> None:
    for league_id, league_name in (("NBA", "National Basketball Association"), ("ABA", "American Basketball Association"), ("BAA", "Basketball Association of America")):
        row = db.execute(
            "SELECT MIN(season_id), MAX(season_id) FROM (SELECT season_id FROM canon_fact_player_season WHERE league_id=? UNION ALL SELECT season_id FROM canon_dim_game WHERE league_id=?)",
            (league_id, league_id),
        ).fetchone()
        db.execute("INSERT OR REPLACE INTO canon_dim_league VALUES (?, ?, ?, ?)", (league_id, league_name, row[0], row[1]))
    db.commit()


def main() -> int:
    args = parse_args()
    database = Path(args.database)
    policy_path = Path(args.policy)
    report_path = Path(args.report)
    if not database.exists():
        raise FileNotFoundError(f"Historical warehouse does not exist: {database}")
    policy = load_policy(policy_path)
    db = sqlite3.connect(database)
    db.row_factory = sqlite3.Row
    started = now_iso()
    report: dict[str, Any] = {"status": "running", "startedAt": started, "database": str(database), "policy": str(policy_path)}
    try:
        reset_canonical(db)
        initialize_schema(db)
        repaired = repair_inventory(db)
        for domain, sources in policy.get("sourcePriority", {}).items():
            for priority, source_key in enumerate(sources):
                db.execute("INSERT INTO canon_source_priority VALUES (?, ?, ?)", (domain, source_key, priority))
        db.commit()

        player_ids, player_names, players = build_players(db, policy)
        team_ids, team_abbrs, teams = build_teams(db, policy)
        player_seasons = build_player_seasons(db, policy, player_ids, player_names, team_ids, team_abbrs)
        team_seasons = build_team_seasons(db, policy, team_ids, team_abbrs)
        games, team_games = build_games(db, policy, team_ids, team_abbrs)
        pbp_view = create_play_by_play_view(db)
        player_games = 0 if args.skip_player_games else build_player_games(db, player_ids, player_names, team_ids, team_abbrs)
        awards, all_stars, drafts = build_events_awards_draft(db, player_ids, player_names, team_ids, team_abbrs)
        coverage_rows = build_coverage(db)
        update_league_bounds(db)
        conflicts = int(db.execute("SELECT COUNT(*) FROM canon_conflicts").fetchone()[0])
        provenance = int(db.execute("SELECT COUNT(*) FROM canon_field_provenance").fetchone()[0])
        source_summary = db.execute("SELECT COUNT(*), COALESCE(SUM(row_count),0), COALESCE(SUM(table_count),0) FROM historical_source_registry").fetchone()
        counts = {
            "players": players, "teams": teams, "playerSeasons": player_seasons, "teamSeasons": team_seasons,
            "games": games, "teamGames": team_games, "playerGames": player_games,
            "awards": awards, "allStars": all_stars, "draftPicks": drafts,
            "conflicts": conflicts, "fieldProvenance": provenance, "coverageRows": coverage_rows,
            "playByPlayView": pbp_view,
        }
        build_id = datetime.now(timezone.utc).strftime("canon-%Y%m%dT%H%M%S%fZ")
        db.execute(
            "INSERT INTO canon_build_manifest VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (build_id, str(policy.get("canonicalSchemaVersion", "1")), now_iso(), int(source_summary[1]), int(source_summary[2]), int(source_summary[0]),
             json.dumps(counts, sort_keys=True), json.dumps([])),
        )
        db.commit()
        report.update({"status": "pass", "finishedAt": now_iso(), "buildId": build_id, "repairedInventoryRows": repaired, "counts": counts})
    except Exception as error:
        report.update({"status": "fail", "finishedAt": now_iso(), "error": f"{type(error).__name__}: {error}"})
        raise
    finally:
        db.close()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
