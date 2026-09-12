from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

COMPILER_VERSION = 2
NBA_FIRST_START_YEAR = 1946
NBA_LAST_START_YEAR = 2025
DEFAULT_DB = ROOT / "data/warehouse/nba_history.sqlite"
DEFAULT_OUTPUT = ROOT / "web/data/nba_static"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Compile canonical NBA history into static website JSON.")
    parser.add_argument("--database", default=str(DEFAULT_DB))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--skip-entities", action="store_true")
    parser.add_argument("--recent-player-games", type=int, default=30)
    parser.add_argument("--recent-team-games", type=int, default=30)
    return parser.parse_args()


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":"), default=str), encoding="utf-8")
    temp.replace(path)


def rows(cursor: sqlite3.Cursor) -> list[dict[str, Any]]:
    names = [item[0] for item in cursor.description or []]
    return [{names[index]: raw[index] for index in range(len(names))} for raw in cursor.fetchall()]


def file_token(value: str) -> str:
    return hashlib.sha1(value.encode("utf-8")).hexdigest()[:24]


def db_fingerprint(path: Path) -> dict[str, Any]:
    stat = path.stat()
    return {"size": stat.st_size, "mtime_ns": stat.st_mtime_ns, "compiler_version": COMPILER_VERSION}


def canonical_ready(db: sqlite3.Connection) -> bool:
    names = {str(row[0]) for row in db.execute("SELECT name FROM sqlite_master WHERE type IN ('table','view')").fetchall()}
    return {
        "canon_dim_player", "canon_dim_team", "canon_dim_season", "canon_dim_game",
        "canon_fact_player_season", "canon_fact_team_season",
    }.issubset(names)


def canonical_season_id(start_year: int) -> str:
    return f"{start_year:04d}-{(start_year + 1) % 100:02d}"


def season_start_year(value: Any) -> int | None:
    text = str(value or "").strip()
    match = re.search(r"(?<!\d)(19|20)\d{2}(?!\d)", text)
    if not match:
        return None
    year = int(match.group(0))
    return year if NBA_FIRST_START_YEAR <= year <= NBA_LAST_START_YEAR else None


def _normalize_season_id(value: Any) -> str | None:
    year = season_start_year(value)
    return canonical_season_id(year) if year is not None else None


def _non_null_score(row: dict[str, Any]) -> int:
    return sum(value not in (None, "") for value in row.values())


def normalize_season_rows(
    source_rows: Iterable[dict[str, Any]],
    *,
    identity_fields: tuple[str, ...],
) -> list[dict[str, Any]]:
    """Collapse malformed aliases such as 2023-20 into one 2023-24 season row.

    The historical import contains duplicate aliases for some source rows. We never
    sum aliases because that would double-count statistics. Instead we prefer the
    correctly named source row, then the most complete row, and retain its values.
    """
    selected: dict[tuple[Any, ...], dict[str, Any]] = {}
    quality: dict[tuple[Any, ...], tuple[int, int]] = {}
    for raw in source_rows:
        normalized = _normalize_season_id(raw.get("season_id"))
        if normalized is None:
            continue
        row = dict(raw)
        original = str(row.get("season_id") or "")
        row["season_id"] = normalized
        if original != normalized:
            row["source_season_id"] = original
        key = (normalized, *(str(row.get(field) or "") for field in identity_fields))
        candidate_quality = (1 if original == normalized else 0, _non_null_score(row))
        if key not in selected or candidate_quality > quality[key]:
            selected[key] = row
            quality[key] = candidate_quality
    return sorted(selected.values(), key=lambda row: (
        str(row.get("season_id") or ""), str(row.get("season_type") or ""),
        str(row.get("team_abbreviation") or row.get("team_key") or ""),
    ))


def _source_season_candidates(db: sqlite3.Connection) -> dict[int, list[dict[str, Any]]]:
    candidates = rows(db.execute("""
        SELECT s.season_id,s.start_year,s.end_year,s.label,
               (SELECT COUNT(*) FROM canon_fact_player_season ps
                 WHERE ps.season_id=s.season_id AND ps.league_id='NBA') AS player_rows,
               (SELECT COUNT(*) FROM canon_fact_team_season ts
                 WHERE ts.season_id=s.season_id AND ts.league_id='NBA') AS team_rows,
               (SELECT COUNT(*) FROM canon_dim_game g
                 WHERE g.season_id=s.season_id AND g.league_id='NBA') AS games
        FROM canon_dim_season s
        ORDER BY s.start_year,s.season_id
    """))
    grouped: dict[int, list[dict[str, Any]]] = {}
    for row in candidates:
        year = row.get("start_year")
        try:
            year = int(year)
        except (TypeError, ValueError):
            year = season_start_year(row.get("season_id"))
        if year is None or not (NBA_FIRST_START_YEAR <= year <= NBA_LAST_START_YEAR):
            continue
        if int(row.get("player_rows") or 0) <= 0:
            continue
        grouped.setdefault(year, []).append(row)
    return grouped


def season_catalog(db: sqlite3.Connection) -> list[dict[str, Any]]:
    grouped = _source_season_candidates(db)
    result: list[dict[str, Any]] = []
    for year in range(NBA_LAST_START_YEAR, NBA_FIRST_START_YEAR - 1, -1):
        candidates = grouped.get(year, [])
        if not candidates:
            continue
        canonical = canonical_season_id(year)
        best = max(candidates, key=lambda row: (
            1 if str(row.get("season_id")) == canonical else 0,
            int(row.get("player_rows") or 0), int(row.get("team_rows") or 0), int(row.get("games") or 0),
        ))
        result.append({
            "season_id": canonical,
            "label": f"{year}-{year + 1}",
            "start_year": year,
            "end_year": year + 1,
            "source_season_id": str(best.get("season_id") or canonical),
            "players": int(best.get("player_rows") or 0),
            "teams": int(best.get("team_rows") or 0),
            "games": int(best.get("games") or 0),
        })
    return result


def _season_years_for_entity(db: sqlite3.Connection, table: str, key_field: str, key: str) -> list[int]:
    result: set[int] = set()
    for row in db.execute(f"SELECT DISTINCT season_id FROM {table} WHERE {key_field}=? AND league_id='NBA'", (key,)).fetchall():
        year = season_start_year(row[0])
        if year is not None:
            result.add(year)
    return sorted(result)


def player_index(db: sqlite3.Connection) -> list[dict[str, Any]]:
    records = rows(db.execute("""
        SELECT p.player_key,p.canonical_name,p.primary_position,p.nba_id,p.bref_id,p.active_from,p.active_to
        FROM canon_dim_player p
        WHERE EXISTS (SELECT 1 FROM canon_fact_player_season ps WHERE ps.player_key=p.player_key AND ps.league_id='NBA')
        ORDER BY p.canonical_name
    """))
    for row in records:
        years = _season_years_for_entity(db, "canon_fact_player_season", "player_key", str(row["player_key"]))
        row["first_season"] = canonical_season_id(years[0]) if years else None
        row["last_season"] = canonical_season_id(years[-1]) if years else None
        row["seasons"] = len(years)
        row["file"] = f"players/{file_token(str(row['player_key']))}.json"
    return records


def team_index(db: sqlite3.Connection) -> list[dict[str, Any]]:
    records = rows(db.execute("""
        SELECT t.team_key,t.franchise_key,t.canonical_name,t.abbreviation,t.active_from,t.active_to
        FROM canon_dim_team t
        WHERE EXISTS (SELECT 1 FROM canon_fact_team_season ts WHERE ts.team_key=t.team_key AND ts.league_id='NBA')
        ORDER BY t.canonical_name
    """))
    for row in records:
        years = _season_years_for_entity(db, "canon_fact_team_season", "team_key", str(row["team_key"]))
        row["first_season"] = canonical_season_id(years[0]) if years else None
        row["last_season"] = canonical_season_id(years[-1]) if years else None
        row["seasons"] = len(years)
        row["file"] = f"teams/{file_token(str(row['team_key']))}.json"
    return records


def game_index(db: sqlite3.Connection) -> list[dict[str, Any]]:
    result = rows(db.execute("""
        SELECT g.game_key,g.nba_game_id,g.game_date,g.season_id,g.season_type,
               g.home_team_key,g.away_team_key,g.home_score,g.away_score,g.status,
               ht.canonical_name AS home_team_name,ht.abbreviation AS home_team_abbreviation,
               at.canonical_name AS away_team_name,at.abbreviation AS away_team_abbreviation
        FROM canon_dim_game g
        LEFT JOIN canon_dim_team ht ON ht.team_key=g.home_team_key
        LEFT JOIN canon_dim_team at ON at.team_key=g.away_team_key
        WHERE g.league_id='NBA' ORDER BY g.game_date,g.game_key
    """))
    for row in result:
        normalized = _normalize_season_id(row.get("season_id"))
        if normalized:
            row["season_id"] = normalized
    return result


def _position_tokens(value: Any) -> list[str]:
    text = str(value or "").upper().replace("POINT GUARD", "PG").replace("SHOOTING GUARD", "SG")
    text = text.replace("SMALL FORWARD", "SF").replace("POWER FORWARD", "PF").replace("CENTER", "C")
    tokens = re.findall(r"(?<![A-Z])(PG|SG|SF|PF|C)(?![A-Z])", text)
    return list(dict.fromkeys(tokens))


def _season_position(row: dict[str, Any]) -> str:
    for key in ("positions", "position", "pos", "position_text", "primary_position"):
        tokens = _position_tokens(row.get(key))
        if tokens:
            return ", ".join(tokens)
    return ""


def static_player_dossier(db: sqlite3.Connection, player_key: str, *, recent_games: int) -> dict[str, Any]:
    cursor = db.execute("SELECT * FROM canon_dim_player WHERE player_key=?", (player_key,))
    raw = cursor.fetchone()
    if raw is None:
        return {}
    profile = dict(zip([item[0] for item in cursor.description], raw))
    profile.pop("provenance_json", None)

    season_rows = rows(db.execute("""
        SELECT ps.*,t.canonical_name AS team_name
        FROM canon_fact_player_season ps
        LEFT JOIN canon_dim_team t ON t.team_key=ps.team_key
        WHERE ps.player_key=? AND ps.league_id='NBA'
        ORDER BY ps.season_id,ps.season_type,ps.team_abbreviation
    """, (player_key,)))
    seasons = normalize_season_rows(season_rows, identity_fields=("season_type", "team_key", "team_abbreviation"))
    for row in seasons:
        position = _season_position(row)
        if position:
            row["positions"] = position

    career_positions: list[str] = []
    for row in seasons:
        for token in _position_tokens(row.get("positions")):
            if token not in career_positions:
                career_positions.append(token)
    if not career_positions:
        career_positions = _position_tokens(profile.get("primary_position"))
    if career_positions:
        profile["positions"] = ", ".join(career_positions)

    awards = rows(db.execute("SELECT * FROM canon_fact_award WHERE player_key=? ORDER BY season_id,award", (player_key,)))
    for row in awards:
        normalized = _normalize_season_id(row.get("season_id"))
        if normalized:
            row["season_id"] = normalized
    all_star = rows(db.execute("SELECT * FROM canon_fact_all_star WHERE player_key=? ORDER BY season_id", (player_key,)))
    for row in all_star:
        normalized = _normalize_season_id(row.get("season_id"))
        if normalized:
            row["season_id"] = normalized
    draft = rows(db.execute("SELECT * FROM canon_fact_draft WHERE player_key=? ORDER BY draft_year", (player_key,)))

    recent: list[dict[str, Any]] = []
    if recent_games > 0:
        recent = rows(db.execute("""
            SELECT pg.*,t.canonical_name AS team_name,ot.canonical_name AS opponent_name,
                   g.home_score,g.away_score,g.home_team_key,g.away_team_key
            FROM canon_fact_player_game pg
            LEFT JOIN canon_dim_team t ON t.team_key=pg.team_key
            LEFT JOIN canon_dim_team ot ON ot.team_key=pg.opponent_team_key
            LEFT JOIN canon_dim_game g ON g.game_key=pg.game_key
            WHERE pg.player_key=? AND pg.league_id='NBA'
            ORDER BY pg.game_date DESC,pg.source_row DESC LIMIT ?
        """, (player_key, recent_games)))

    regular = [row for row in seasons if str(row.get("season_type") or "") == "regular"]
    playoffs = [row for row in seasons if str(row.get("season_type") or "") == "playoffs"]
    return {
        "kind": "player", "profile": profile, "seasons": seasons,
        "regular_seasons": regular, "playoff_seasons": playoffs,
        "awards": awards, "all_star": all_star, "draft": draft, "recent_games": recent,
        "summary": {
            "season_rows": len(seasons),
            "regular_seasons": len({str(r.get("season_id")) for r in regular}),
            "playoff_seasons": len({str(r.get("season_id")) for r in playoffs}),
            "awards": len(awards), "all_star_selections": len(all_star),
            "draft_rows": len(draft), "recent_games": len(recent),
        },
    }


def static_team_dossier(db: sqlite3.Connection, team_key: str, *, recent_games: int) -> dict[str, Any]:
    cursor = db.execute("SELECT * FROM canon_dim_team WHERE team_key=?", (team_key,))
    raw = cursor.fetchone()
    if raw is None:
        return {}
    profile = dict(zip([item[0] for item in cursor.description], raw))
    profile.pop("provenance_json", None)
    franchise = None
    if profile.get("franchise_key"):
        fc = db.execute("SELECT * FROM canon_dim_franchise WHERE franchise_key=?", (profile["franchise_key"],))
        fr = fc.fetchone()
        if fr is not None:
            franchise = dict(zip([item[0] for item in fc.description], fr))

    raw_seasons = rows(db.execute("SELECT * FROM canon_fact_team_season WHERE team_key=? AND league_id='NBA' ORDER BY season_id,season_type", (team_key,)))
    seasons = normalize_season_rows(raw_seasons, identity_fields=("season_type",))
    for row in seasons:
        wins, losses = row.get("wins"), row.get("losses")
        total = float(wins or 0) + float(losses or 0)
        row["win_pct"] = None if total <= 0 else float(wins or 0) / total

    games: list[dict[str, Any]] = []
    if recent_games > 0:
        games = rows(db.execute("""
            SELECT g.*,home.canonical_name AS home_team_name,away.canonical_name AS away_team_name
            FROM canon_dim_game g
            LEFT JOIN canon_dim_team home ON home.team_key=g.home_team_key
            LEFT JOIN canon_dim_team away ON away.team_key=g.away_team_key
            WHERE g.league_id='NBA' AND (g.home_team_key=? OR g.away_team_key=?)
            ORDER BY g.game_date DESC LIMIT ?
        """, (team_key, team_key, recent_games)))

    notable = rows(db.execute("""
        SELECT ps.player_key,p.canonical_name AS player_name,COUNT(DISTINCT substr(ps.season_id,1,4)) AS seasons,
               SUM(COALESCE(ps.games,0)) AS games,SUM(COALESCE(ps.pts,0)) AS pts,
               SUM(COALESCE(ps.reb,0)) AS reb,SUM(COALESCE(ps.ast,0)) AS ast,
               MIN(ps.season_id) AS first_season,MAX(ps.season_id) AS last_season
        FROM canon_fact_player_season ps JOIN canon_dim_player p ON p.player_key=ps.player_key
        WHERE ps.team_key=? AND ps.league_id='NBA' AND ps.season_type='regular'
        GROUP BY ps.player_key ORDER BY games DESC,pts DESC LIMIT 50
    """, (team_key,)))
    for row in notable:
        first = _normalize_season_id(row.get("first_season")); last = _normalize_season_id(row.get("last_season"))
        if first: row["first_season"] = first
        if last: row["last_season"] = last

    return {
        "kind": "team", "profile": profile, "franchise": franchise,
        "seasons": seasons, "recent_games": games, "notable_players": notable,
        "summary": {"seasons": len({str(row.get("season_id")) for row in seasons}), "recent_games": len(games), "notable_players": len(notable)},
    }


def build() -> int:
    args = parse_args()
    database = Path(args.database).expanduser().resolve(); output = Path(args.output).expanduser().resolve()
    if not database.is_file():
        raise SystemExit(f"NBA history warehouse not found: {database}")
    fingerprint = db_fingerprint(database)
    manifest_path = output / "manifest.json"
    if not args.force and manifest_path.exists():
        try:
            if json.loads(manifest_path.read_text(encoding="utf-8")).get("database_fingerprint") == fingerprint:
                print(f"Static NBA website data is current: {output}"); return 0
        except Exception:
            pass

    os.environ["SPORTS_TERMINAL_NBA_HISTORY_DB"] = str(database)
    from app.historical_nba_compat_api import historical_seed_snapshot

    with sqlite3.connect(str(database)) as db:
        db.row_factory = sqlite3.Row
        if not canonical_ready(db):
            raise SystemExit("Canonical NBA tables are missing; run build_historical_nba_canonical.py first.")
        seasons = season_catalog(db); players = player_index(db); teams = team_index(db); games = game_index(db)
        staging = output.parent / f".{output.name}.staging"
        if staging.exists(): shutil.rmtree(staging)
        staging.mkdir(parents=True, exist_ok=True)
        write_json(staging / "seasons.json", seasons); write_json(staging / "players/index.json", players)
        write_json(staging / "teams/index.json", teams); write_json(staging / "games/index.json", games)

        for season in seasons:
            public_id = str(season["season_id"]); source_id = str(season.get("source_season_id") or public_id)
            for season_type in ("regular", "playoffs"):
                count = db.execute("SELECT COUNT(*) FROM canon_fact_player_season WHERE season_id=? AND league_id='NBA' AND season_type=?", (source_id, season_type)).fetchone()[0]
                if not count: continue
                payload = historical_seed_snapshot(source_id, league="NBA", season_type=season_type, include_game_logs=False, player_log_limit=0)
                payload["season_id"] = public_id; payload["static_data"] = True; payload["static_compiler_version"] = COMPILER_VERSION
                write_json(staging / f"seasons/{public_id}/{season_type}.json", payload)

        if not args.skip_entities:
            for index, player in enumerate(players, start=1):
                dossier = static_player_dossier(db, str(player["player_key"]), recent_games=max(0, args.recent_player_games)); dossier["static_data"] = True
                write_json(staging / str(player["file"]), dossier)
                if index % 500 == 0: print(f"  players: {index}/{len(players)}")
            for team in teams:
                dossier = static_team_dossier(db, str(team["team_key"]), recent_games=max(0, args.recent_team_games)); dossier["static_data"] = True
                write_json(staging / str(team["file"]), dossier)

        awards = rows(db.execute("SELECT * FROM canon_fact_award ORDER BY season_id,award,player_name"))
        all_star = rows(db.execute("SELECT * FROM canon_fact_all_star ORDER BY season_id,player_name"))
        draft = rows(db.execute("SELECT * FROM canon_fact_draft ORDER BY draft_year,pick_number,player_name"))
        coverage = rows(db.execute("SELECT * FROM canon_coverage WHERE league_id='NBA' ORDER BY season_id,domain"))
        write_json(staging / "history/awards.json", awards); write_json(staging / "history/all_star.json", all_star)
        write_json(staging / "history/draft.json", draft); write_json(staging / "history/coverage.json", coverage)
        manifest = {
            "contract": "sports-terminal-static-nba-website-v2", "compiler_version": COMPILER_VERSION,
            "generated_at": now_iso(), "database_fingerprint": fingerprint,
            "latest_season": seasons[0]["season_id"] if seasons else None,
            "season_count": len(seasons), "player_count": len(players), "team_count": len(teams), "game_count": len(games),
            "award_count": len(awards), "all_star_count": len(all_star), "draft_count": len(draft),
            "entity_dossiers": not args.skip_entities,
            "runtime": {"historical_http_api_required": False, "sqlite_required_by_browser": False, "live_overlay_supported": True},
        }
        write_json(staging / "manifest.json", manifest)
    if output.exists(): shutil.rmtree(output)
    staging.replace(output)
    print(f"Built static NBA website data: {output}"); print(json.dumps(manifest, indent=2)); return 0


if __name__ == "__main__":
    raise SystemExit(build())
