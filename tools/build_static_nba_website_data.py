from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

COMPILER_VERSION = 1
DEFAULT_DB = ROOT / "data/warehouse/nba_history.sqlite"
DEFAULT_OUTPUT = ROOT / "web/data/nba_static"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compile immutable canonical NBA history into sharded static website JSON."
    )
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
    temp.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":"), default=str),
        encoding="utf-8",
    )
    temp.replace(path)


def rows(cursor: sqlite3.Cursor) -> list[dict[str, Any]]:
    names = [item[0] for item in cursor.description or []]
    return [
        {names[index]: raw[index] for index in range(len(names))}
        for raw in cursor.fetchall()
    ]


def file_token(value: str) -> str:
    return hashlib.sha1(value.encode("utf-8")).hexdigest()[:24]


def db_fingerprint(path: Path) -> dict[str, Any]:
    stat = path.stat()
    return {
        "size": stat.st_size,
        "mtime_ns": stat.st_mtime_ns,
        "compiler_version": COMPILER_VERSION,
    }


def canonical_ready(db: sqlite3.Connection) -> bool:
    names = {
        str(row[0])
        for row in db.execute(
            "SELECT name FROM sqlite_master WHERE type IN ('table','view')"
        ).fetchall()
    }
    return {
        "canon_dim_player",
        "canon_dim_team",
        "canon_dim_season",
        "canon_dim_game",
        "canon_fact_player_season",
        "canon_fact_team_season",
    }.issubset(names)


def season_catalog(db: sqlite3.Connection) -> list[dict[str, Any]]:
    return rows(
        db.execute(
            """
            SELECT s.season_id,s.start_year,s.end_year,s.label,
                   COUNT(DISTINCT ps.player_key) AS players,
                   COUNT(DISTINCT ts.team_key) AS teams,
                   COUNT(DISTINCT g.game_key) AS games
            FROM canon_dim_season s
            LEFT JOIN canon_fact_player_season ps
              ON ps.season_id=s.season_id AND ps.league_id='NBA'
            LEFT JOIN canon_fact_team_season ts
              ON ts.season_id=s.season_id AND ts.league_id='NBA'
            LEFT JOIN canon_dim_game g
              ON g.season_id=s.season_id AND g.league_id='NBA'
            WHERE EXISTS (
              SELECT 1 FROM canon_fact_player_season p2
              WHERE p2.season_id=s.season_id AND p2.league_id='NBA'
            )
            GROUP BY s.season_id,s.start_year,s.end_year,s.label
            ORDER BY s.start_year DESC
            """
        )
    )


def player_index(db: sqlite3.Connection) -> list[dict[str, Any]]:
    records = rows(
        db.execute(
            """
            SELECT p.player_key,p.canonical_name,p.primary_position,p.nba_id,p.bref_id,
                   p.active_from,p.active_to,
                   MIN(ps.season_id) AS first_season,MAX(ps.season_id) AS last_season,
                   COUNT(DISTINCT ps.season_id) AS seasons
            FROM canon_dim_player p
            JOIN canon_fact_player_season ps ON ps.player_key=p.player_key
            WHERE ps.league_id='NBA'
            GROUP BY p.player_key
            ORDER BY p.canonical_name
            """
        )
    )
    for row in records:
        row["file"] = f"players/{file_token(str(row['player_key']))}.json"
    return records


def team_index(db: sqlite3.Connection) -> list[dict[str, Any]]:
    records = rows(
        db.execute(
            """
            SELECT t.team_key,t.franchise_key,t.canonical_name,t.abbreviation,t.active_from,t.active_to,
                   MIN(ts.season_id) AS first_season,MAX(ts.season_id) AS last_season,
                   COUNT(DISTINCT ts.season_id) AS seasons
            FROM canon_dim_team t
            JOIN canon_fact_team_season ts ON ts.team_key=t.team_key
            WHERE ts.league_id='NBA'
            GROUP BY t.team_key
            ORDER BY t.canonical_name
            """
        )
    )
    for row in records:
        row["file"] = f"teams/{file_token(str(row['team_key']))}.json"
    return records


def game_index(db: sqlite3.Connection) -> list[dict[str, Any]]:
    return rows(
        db.execute(
            """
            SELECT g.game_key,g.nba_game_id,g.game_date,g.season_id,g.season_type,
                   g.home_team_key,g.away_team_key,g.home_score,g.away_score,g.status,
                   ht.canonical_name AS home_team_name,ht.abbreviation AS home_team_abbreviation,
                   at.canonical_name AS away_team_name,at.abbreviation AS away_team_abbreviation
            FROM canon_dim_game g
            LEFT JOIN canon_dim_team ht ON ht.team_key=g.home_team_key
            LEFT JOIN canon_dim_team at ON at.team_key=g.away_team_key
            WHERE g.league_id='NBA'
            ORDER BY g.game_date,g.game_key
            """
        )
    )


def static_player_dossier(
    db: sqlite3.Connection,
    player_key: str,
    *,
    recent_games: int,
) -> dict[str, Any]:
    profile_row = db.execute(
        "SELECT * FROM canon_dim_player WHERE player_key=?", (player_key,)
    ).fetchone()
    if profile_row is None:
        return {}
    profile = dict(zip([c[0] for c in db.execute("SELECT * FROM canon_dim_player LIMIT 0").description], profile_row))
    profile.pop("provenance_json", None)

    seasons = rows(
        db.execute(
            """
            SELECT ps.*,t.canonical_name AS team_name
            FROM canon_fact_player_season ps
            LEFT JOIN canon_dim_team t ON t.team_key=ps.team_key
            WHERE ps.player_key=? AND ps.league_id='NBA'
            ORDER BY ps.season_id,ps.season_type,ps.team_abbreviation
            """,
            (player_key,),
        )
    )
    awards = rows(
        db.execute(
            "SELECT * FROM canon_fact_award WHERE player_key=? ORDER BY season_id,award",
            (player_key,),
        )
    )
    all_star = rows(
        db.execute(
            "SELECT * FROM canon_fact_all_star WHERE player_key=? ORDER BY season_id",
            (player_key,),
        )
    )
    draft = rows(
        db.execute(
            "SELECT * FROM canon_fact_draft WHERE player_key=? ORDER BY draft_year",
            (player_key,),
        )
    )
    recent: list[dict[str, Any]] = []
    if recent_games > 0:
        recent = rows(
            db.execute(
                """
                SELECT pg.*,t.canonical_name AS team_name,ot.canonical_name AS opponent_name,
                       g.home_score,g.away_score,g.home_team_key,g.away_team_key
                FROM canon_fact_player_game pg
                LEFT JOIN canon_dim_team t ON t.team_key=pg.team_key
                LEFT JOIN canon_dim_team ot ON ot.team_key=pg.opponent_team_key
                LEFT JOIN canon_dim_game g ON g.game_key=pg.game_key
                WHERE pg.player_key=? AND pg.league_id='NBA'
                ORDER BY pg.game_date DESC,pg.source_row DESC LIMIT ?
                """,
                (player_key, recent_games),
            )
        )
    regular = [row for row in seasons if str(row.get("season_type") or "") == "regular"]
    playoffs = [row for row in seasons if str(row.get("season_type") or "") == "playoffs"]
    return {
        "kind": "player",
        "profile": profile,
        "seasons": seasons,
        "regular_seasons": regular,
        "playoff_seasons": playoffs,
        "awards": awards,
        "all_star": all_star,
        "draft": draft,
        "recent_games": recent,
        "summary": {
            "season_rows": len(seasons),
            "regular_seasons": len({str(r.get('season_id')) for r in regular}),
            "playoff_seasons": len({str(r.get('season_id')) for r in playoffs}),
            "awards": len(awards),
            "all_star_selections": len(all_star),
            "draft_rows": len(draft),
            "recent_games": len(recent),
        },
    }


def static_team_dossier(
    db: sqlite3.Connection,
    team_key: str,
    *,
    recent_games: int,
) -> dict[str, Any]:
    profile_cursor = db.execute("SELECT * FROM canon_dim_team WHERE team_key=?", (team_key,))
    raw = profile_cursor.fetchone()
    if raw is None:
        return {}
    profile = dict(zip([item[0] for item in profile_cursor.description], raw))
    profile.pop("provenance_json", None)
    franchise = None
    if profile.get("franchise_key"):
        cursor = db.execute(
            "SELECT * FROM canon_dim_franchise WHERE franchise_key=?",
            (profile["franchise_key"],),
        )
        franchise_row = cursor.fetchone()
        if franchise_row is not None:
            franchise = dict(zip([item[0] for item in cursor.description], franchise_row))
    seasons = rows(
        db.execute(
            """
            SELECT * FROM canon_fact_team_season
            WHERE team_key=? AND league_id='NBA'
            ORDER BY season_id,season_type
            """,
            (team_key,),
        )
    )
    for row in seasons:
        wins = row.get("wins")
        losses = row.get("losses")
        total = (float(wins or 0) + float(losses or 0))
        row["win_pct"] = None if total <= 0 else float(wins or 0) / total
    games: list[dict[str, Any]] = []
    if recent_games > 0:
        games = rows(
            db.execute(
                """
                SELECT g.*,home.canonical_name AS home_team_name,away.canonical_name AS away_team_name
                FROM canon_dim_game g
                LEFT JOIN canon_dim_team home ON home.team_key=g.home_team_key
                LEFT JOIN canon_dim_team away ON away.team_key=g.away_team_key
                WHERE g.league_id='NBA' AND (g.home_team_key=? OR g.away_team_key=?)
                ORDER BY g.game_date DESC LIMIT ?
                """,
                (team_key, team_key, recent_games),
            )
        )
    notable = rows(
        db.execute(
            """
            SELECT ps.player_key,p.canonical_name AS player_name,COUNT(DISTINCT ps.season_id) AS seasons,
                   SUM(COALESCE(ps.games,0)) AS games,SUM(COALESCE(ps.pts,0)) AS pts,
                   SUM(COALESCE(ps.reb,0)) AS reb,SUM(COALESCE(ps.ast,0)) AS ast,
                   MIN(ps.season_id) AS first_season,MAX(ps.season_id) AS last_season
            FROM canon_fact_player_season ps
            JOIN canon_dim_player p ON p.player_key=ps.player_key
            WHERE ps.team_key=? AND ps.league_id='NBA' AND ps.season_type='regular'
            GROUP BY ps.player_key ORDER BY games DESC,pts DESC LIMIT 50
            """,
            (team_key,),
        )
    )
    return {
        "kind": "team",
        "profile": profile,
        "franchise": franchise,
        "seasons": seasons,
        "recent_games": games,
        "notable_players": notable,
        "summary": {
            "seasons": len({str(row.get('season_id')) for row in seasons}),
            "recent_games": len(games),
            "notable_players": len(notable),
        },
    }


def build() -> int:
    args = parse_args()
    database = Path(args.database).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()
    if not database.exists() or not database.is_file():
        raise SystemExit(f"NBA history warehouse not found: {database}")

    fingerprint = db_fingerprint(database)
    manifest_path = output / "manifest.json"
    if not args.force and manifest_path.exists():
        try:
            current = json.loads(manifest_path.read_text(encoding="utf-8"))
            if current.get("database_fingerprint") == fingerprint:
                print(f"Static NBA website data is current: {output}")
                return 0
        except Exception:
            pass

    os.environ["SPORTS_TERMINAL_NBA_HISTORY_DB"] = str(database)
    from app.historical_nba_compat_api import historical_seed_snapshot

    with sqlite3.connect(str(database)) as db:
        db.row_factory = sqlite3.Row
        if not canonical_ready(db):
            raise SystemExit("Canonical NBA tables are missing; run build_historical_nba_canonical.py first.")

        seasons = season_catalog(db)
        players = player_index(db)
        teams = team_index(db)
        games = game_index(db)

        staging = output.parent / f".{output.name}.staging"
        if staging.exists():
            shutil.rmtree(staging)
        staging.mkdir(parents=True, exist_ok=True)

        write_json(staging / "seasons.json", seasons)
        write_json(staging / "players/index.json", players)
        write_json(staging / "teams/index.json", teams)
        write_json(staging / "games/index.json", games)

        for season in seasons:
            season_id = str(season["season_id"])
            for season_type in ("regular", "playoffs"):
                count = db.execute(
                    "SELECT COUNT(*) FROM canon_fact_player_season WHERE season_id=? AND league_id='NBA' AND season_type=?",
                    (season_id, season_type),
                ).fetchone()[0]
                if not count:
                    continue
                payload = historical_seed_snapshot(
                    season_id,
                    league="NBA",
                    season_type=season_type,
                    include_game_logs=False,
                    player_log_limit=0,
                )
                payload["static_data"] = True
                payload["static_compiler_version"] = COMPILER_VERSION
                write_json(staging / f"seasons/{season_id}/{season_type}.json", payload)

        if not args.skip_entities:
            for index, player in enumerate(players, start=1):
                key = str(player["player_key"])
                dossier = static_player_dossier(
                    db,
                    key,
                    recent_games=max(0, args.recent_player_games),
                )
                dossier["static_data"] = True
                write_json(staging / str(player["file"]), dossier)
                if index % 500 == 0:
                    print(f"  players: {index}/{len(players)}")

            for team in teams:
                key = str(team["team_key"])
                dossier = static_team_dossier(
                    db,
                    key,
                    recent_games=max(0, args.recent_team_games),
                )
                dossier["static_data"] = True
                write_json(staging / str(team["file"]), dossier)

        awards = rows(db.execute("SELECT * FROM canon_fact_award ORDER BY season_id,award,player_name"))
        all_star = rows(db.execute("SELECT * FROM canon_fact_all_star ORDER BY season_id,player_name"))
        draft = rows(db.execute("SELECT * FROM canon_fact_draft ORDER BY draft_year,pick_number,player_name"))
        coverage = rows(db.execute("SELECT * FROM canon_coverage WHERE league_id='NBA' ORDER BY season_id,domain"))
        write_json(staging / "history/awards.json", awards)
        write_json(staging / "history/all_star.json", all_star)
        write_json(staging / "history/draft.json", draft)
        write_json(staging / "history/coverage.json", coverage)

        manifest = {
            "contract": "sports-terminal-static-nba-website-v1",
            "compiler_version": COMPILER_VERSION,
            "generated_at": now_iso(),
            "database_fingerprint": fingerprint,
            "latest_season": seasons[0]["season_id"] if seasons else None,
            "season_count": len(seasons),
            "player_count": len(players),
            "team_count": len(teams),
            "game_count": len(games),
            "award_count": len(awards),
            "all_star_count": len(all_star),
            "draft_count": len(draft),
            "entity_dossiers": not args.skip_entities,
            "runtime": {
                "historical_http_api_required": False,
                "sqlite_required_by_browser": False,
                "live_overlay_supported": True,
            },
        }
        write_json(staging / "manifest.json", manifest)

    if output.exists():
        shutil.rmtree(output)
    staging.replace(output)
    print(f"Built static NBA website data: {output}")
    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(build())
