from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

from tools.build_static_nba_website_data import (  # noqa: E402
    COMPILER_VERSION,
    canonical_ready,
    db_fingerprint,
    file_token,
    game_index,
    now_iso,
    player_index,
    rows,
    static_player_dossier,
    static_team_dossier,
    team_index,
    write_json,
)

DEFAULT_DB = ROOT / "data/warehouse/nba_history.sqlite"
DEFAULT_OUTPUT = ROOT / "web/data/nba_static"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compile canonical NBA history into immutable sharded website JSON."
    )
    parser.add_argument("--database", default=str(DEFAULT_DB))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--skip-entities", action="store_true")
    parser.add_argument("--recent-player-games", type=int, default=30)
    parser.add_argument("--recent-team-games", type=int, default=30)
    return parser.parse_args()


def season_catalog(db: sqlite3.Connection) -> list[dict[str, Any]]:
    # Deliberately use correlated aggregates instead of joining three fact
    # tables. A join would create a players × teams × games fanout per season.
    return rows(
        db.execute(
            """
            SELECT s.season_id,s.start_year,s.end_year,s.label,
                   (SELECT COUNT(DISTINCT ps.player_key)
                      FROM canon_fact_player_season ps
                     WHERE ps.season_id=s.season_id AND ps.league_id='NBA') AS players,
                   (SELECT COUNT(DISTINCT ts.team_key)
                      FROM canon_fact_team_season ts
                     WHERE ts.season_id=s.season_id AND ts.league_id='NBA') AS teams,
                   (SELECT COUNT(DISTINCT g.game_key)
                      FROM canon_dim_game g
                     WHERE g.season_id=s.season_id AND g.league_id='NBA') AS games
            FROM canon_dim_season s
            WHERE EXISTS (
              SELECT 1 FROM canon_fact_player_season p2
              WHERE p2.season_id=s.season_id AND p2.league_id='NBA'
            )
            ORDER BY s.start_year DESC
            """
        )
    )


def build() -> int:
    args = parse_args()
    database = Path(args.database).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()
    if not database.is_file():
        raise SystemExit(f"NBA history warehouse not found: {database}")

    fingerprint = db_fingerprint(database)
    fingerprint["compiler_entrypoint"] = "v2"
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
            raise SystemExit(
                "Canonical NBA tables are missing; run build_historical_nba_canonical.py first."
            )

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

        generated_season_files = 0
        for season in seasons:
            season_id = str(season["season_id"])
            for season_type in ("regular", "playoffs"):
                count = int(
                    db.execute(
                        """
                        SELECT COUNT(*) FROM canon_fact_player_season
                        WHERE season_id=? AND league_id='NBA' AND season_type=?
                        """,
                        (season_id, season_type),
                    ).fetchone()[0]
                )
                if count == 0:
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
                write_json(
                    staging / f"seasons/{season_id}/{season_type}.json",
                    payload,
                )
                generated_season_files += 1

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
                    print(f"  player dossiers: {index}/{len(players)}")

            for index, team in enumerate(teams, start=1):
                key = str(team["team_key"])
                dossier = static_team_dossier(
                    db,
                    key,
                    recent_games=max(0, args.recent_team_games),
                )
                dossier["static_data"] = True
                write_json(staging / str(team["file"]), dossier)
                if index % 50 == 0:
                    print(f"  team dossiers: {index}/{len(teams)}")

        awards = rows(
            db.execute(
                "SELECT * FROM canon_fact_award ORDER BY season_id,award,player_name"
            )
        )
        all_star = rows(
            db.execute(
                "SELECT * FROM canon_fact_all_star ORDER BY season_id,player_name"
            )
        )
        draft = rows(
            db.execute(
                "SELECT * FROM canon_fact_draft ORDER BY draft_year,pick_number,player_name"
            )
        )
        coverage = rows(
            db.execute(
                "SELECT * FROM canon_coverage WHERE league_id='NBA' ORDER BY season_id,domain"
            )
        )
        write_json(staging / "history/awards.json", awards)
        write_json(staging / "history/all_star.json", all_star)
        write_json(staging / "history/draft.json", draft)
        write_json(staging / "history/coverage.json", coverage)

        manifest = {
            "contract": "sports-terminal-static-nba-website-v2",
            "compiler_version": COMPILER_VERSION,
            "generated_at": now_iso(),
            "database_fingerprint": fingerprint,
            "latest_season": seasons[0]["season_id"] if seasons else None,
            "season_count": len(seasons),
            "season_file_count": generated_season_files,
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
                "static_browser_cache": True,
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
