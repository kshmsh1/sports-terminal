from __future__ import annotations

import argparse
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_DATABASE = "data/warehouse/nba_2025.sqlite"
DEFAULT_OUTPUT = "data/terminal_seed/nba_2025"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Export compact Sports Terminal JSON seed files from the local NBA warehouse. "
            "This is a product-facing layer and makes no network requests."
        )
    )
    parser.add_argument("--database", default=DEFAULT_DATABASE)
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    parser.add_argument("--leader-limit", type=int, default=100)
    parser.add_argument("--high-limit", type=int, default=100)
    return parser.parse_args()


def connect(path: str | Path) -> sqlite3.Connection:
    db = sqlite3.connect(path)
    db.row_factory = sqlite3.Row
    return db


def rows(db: sqlite3.Connection, query: str, params: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
    return [dict(row) for row in db.execute(query, params)]


def one(db: sqlite3.Connection, query: str, params: tuple[Any, ...] = ()) -> Any:
    return db.execute(query, params).fetchone()[0]


def write_json(path: Path, document: Any) -> None:
    path.write_text(json.dumps(document, indent=2, ensure_ascii=False, default=str) + "\n", encoding="utf-8")


def table_count(db: sqlite3.Connection, name: str) -> int:
    return int(one(db, f"SELECT COUNT(*) FROM {name}"))


def build_manifest(db: sqlite3.Connection, output: Path) -> dict[str, Any]:
    tables = [
        "teams",
        "players",
        "games",
        "team_game_stats",
        "player_game_stats",
        "play_by_play_events_normalized",
        "source_pages",
        "source_tables",
        "warehouse_rows",
    ]
    build_row = db.execute(
        "SELECT value_json FROM warehouse_build_manifest WHERE key = 'build'"
    ).fetchone()
    warehouse_build = json.loads(build_row["value_json"]) if build_row else None
    return {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "output": str(output),
        "source": "local NBA warehouse",
        "warehouseBuild": warehouse_build,
        "counts": {name: table_count(db, name) for name in tables},
        "notes": [
            "Team records are computed across all loaded games in the warehouse, including postseason games.",
            "Leaderboards are derived from materialized player_game_stats and can be recalculated from the warehouse.",
            "Seed files are meant for early Sports Terminal product screens, not as a replacement for the full warehouse.",
        ],
    }


def export_teams(db: sqlite3.Connection) -> list[dict[str, Any]]:
    return rows(
        db,
        """
        SELECT t.team_id,
               t.season_end_year,
               t.team_abbreviation,
               t.team_name,
               t.team_url,
               COALESCE(r.games, 0) AS games,
               COALESCE(r.wins, 0) AS wins,
               COALESCE(r.losses, 0) AS losses,
               COALESCE(r.points, 0) AS points,
               COALESCE(r.opponent_points, 0) AS opponent_points,
               ROUND(COALESCE(r.points, 0) * 1.0 / NULLIF(r.games, 0), 3) AS points_per_game,
               ROUND(COALESCE(r.opponent_points, 0) * 1.0 / NULLIF(r.games, 0), 3) AS opponent_points_per_game
        FROM teams AS t
        LEFT JOIN (
          SELECT team_id,
                 COUNT(*) AS games,
                 SUM(CASE WHEN result = 'W' THEN 1 ELSE 0 END) AS wins,
                 SUM(CASE WHEN result = 'L' THEN 1 ELSE 0 END) AS losses,
                 SUM(COALESCE(points, 0)) AS points,
                 SUM(COALESCE(opponent_points, 0)) AS opponent_points
          FROM team_game_stats
          GROUP BY team_id
        ) AS r ON r.team_id = t.team_id
        ORDER BY wins DESC, losses ASC, team_id
        """,
    )


def export_games(db: sqlite3.Connection) -> list[dict[str, Any]]:
    return rows(
        db,
        """
        SELECT game_id,
               season_end_year,
               game_date,
               away_team_id,
               away_score,
               home_team_id,
               home_score,
               winner_team_id,
               loser_team_id,
               page_url
        FROM games
        ORDER BY game_date, game_id
        """,
    )


def export_players(db: sqlite3.Connection) -> list[dict[str, Any]]:
    return rows(
        db,
        """
        SELECT p.player_id,
               p.player_name,
               p.profile_url,
               COALESCE(s.games, 0) AS games,
               COALESCE(s.points, 0) AS points,
               COALESCE(s.rebounds, 0) AS rebounds,
               COALESCE(s.assists, 0) AS assists,
               ROUND(COALESCE(s.points, 0) * 1.0 / NULLIF(s.games, 0), 3) AS points_per_game,
               ROUND(COALESCE(s.rebounds, 0) * 1.0 / NULLIF(s.games, 0), 3) AS rebounds_per_game,
               ROUND(COALESCE(s.assists, 0) * 1.0 / NULLIF(s.games, 0), 3) AS assists_per_game
        FROM players AS p
        LEFT JOIN (
          SELECT player_id,
                 COUNT(*) AS games,
                 SUM(COALESCE(pts, 0)) AS points,
                 SUM(COALESCE(trb, 0)) AS rebounds,
                 SUM(COALESCE(ast, 0)) AS assists
          FROM player_game_stats
          WHERE player_id IS NOT NULL
            AND COALESCE(mp_seconds, 0) > 0
          GROUP BY player_id
        ) AS s ON s.player_id = p.player_id
        ORDER BY points DESC, player_name
        """,
    )


def export_player_leaders(db: sqlite3.Connection, limit: int) -> dict[str, list[dict[str, Any]]]:
    base = """
        WITH player_totals AS (
          SELECT player_id,
                 player_label,
                 COUNT(*) AS games,
                 SUM(COALESCE(pts, 0)) AS points,
                 SUM(COALESCE(trb, 0)) AS rebounds,
                 SUM(COALESCE(ast, 0)) AS assists,
                 SUM(COALESCE(stl, 0)) AS steals,
                 SUM(COALESCE(blk, 0)) AS blocks,
                 SUM(COALESCE(tov, 0)) AS turnovers,
                 SUM(COALESCE(fg, 0)) AS fg,
                 SUM(COALESCE(fga, 0)) AS fga,
                 SUM(COALESCE(fg3, 0)) AS fg3,
                 SUM(COALESCE(fg3a, 0)) AS fg3a,
                 SUM(COALESCE(ft, 0)) AS ft,
                 SUM(COALESCE(fta, 0)) AS fta,
                 AVG(CASE WHEN bpm IS NOT NULL THEN bpm END) AS avg_bpm
          FROM player_game_stats
          WHERE COALESCE(mp_seconds, 0) > 0
          GROUP BY player_id, player_label
        )
        SELECT player_id,
               player_label,
               games,
               points,
               rebounds,
               assists,
               steals,
               blocks,
               turnovers,
               ROUND(points * 1.0 / NULLIF(games, 0), 3) AS points_per_game,
               ROUND(rebounds * 1.0 / NULLIF(games, 0), 3) AS rebounds_per_game,
               ROUND(assists * 1.0 / NULLIF(games, 0), 3) AS assists_per_game,
               ROUND(steals * 1.0 / NULLIF(games, 0), 3) AS steals_per_game,
               ROUND(blocks * 1.0 / NULLIF(games, 0), 3) AS blocks_per_game,
               ROUND(fg * 1.0 / NULLIF(fga, 0), 4) AS fg_pct,
               ROUND(fg3 * 1.0 / NULLIF(fg3a, 0), 4) AS fg3_pct,
               ROUND(ft * 1.0 / NULLIF(fta, 0), 4) AS ft_pct,
               ROUND(avg_bpm, 3) AS avg_bpm
        FROM player_totals
    """
    specs = {
        "points": "points DESC",
        "points_per_game": "points_per_game DESC",
        "rebounds": "rebounds DESC",
        "rebounds_per_game": "rebounds_per_game DESC",
        "assists": "assists DESC",
        "assists_per_game": "assists_per_game DESC",
        "steals": "steals DESC",
        "blocks": "blocks DESC",
        "avg_bpm": "avg_bpm DESC",
    }
    return {
        name: rows(db, f"{base} ORDER BY {order}, player_label LIMIT ?", (limit,))
        for name, order in specs.items()
    }


def export_player_game_highs(db: sqlite3.Connection, limit: int) -> dict[str, list[dict[str, Any]]]:
    select = """
        SELECT game_id,
               team_id,
               player_id,
               player_label,
               pts,
               trb,
               ast,
               stl,
               blk,
               plus_minus,
               mp_text
        FROM player_game_stats
        WHERE COALESCE(mp_seconds, 0) > 0
    """
    specs = {
        "points": "pts DESC",
        "rebounds": "trb DESC",
        "assists": "ast DESC",
        "steals": "stl DESC",
        "blocks": "blk DESC",
        "plus_minus": "plus_minus DESC",
    }
    return {
        name: rows(db, f"{select} ORDER BY {order}, game_id LIMIT ?", (limit,))
        for name, order in specs.items()
    }


def export_team_records(db: sqlite3.Connection) -> list[dict[str, Any]]:
    return rows(
        db,
        """
        SELECT team_id,
               COUNT(*) AS games,
               SUM(CASE WHEN result = 'W' THEN 1 ELSE 0 END) AS wins,
               SUM(CASE WHEN result = 'L' THEN 1 ELSE 0 END) AS losses,
               SUM(CASE WHEN is_home = 1 THEN 1 ELSE 0 END) AS home_games,
               SUM(CASE WHEN is_home = 0 THEN 1 ELSE 0 END) AS away_games,
               SUM(COALESCE(points, 0)) AS points,
               SUM(COALESCE(opponent_points, 0)) AS opponent_points,
               ROUND(AVG(points), 3) AS points_per_game,
               ROUND(AVG(opponent_points), 3) AS opponent_points_per_game,
               ROUND(AVG(points - opponent_points), 3) AS average_margin
        FROM team_game_stats
        GROUP BY team_id
        ORDER BY wins DESC, losses ASC, team_id
        """,
    )


def export_search_index(db: sqlite3.Connection) -> list[dict[str, Any]]:
    team_rows = rows(
        db,
        """
        SELECT 'team' AS type,
               team_id AS id,
               COALESCE(team_name, team_abbreviation) AS label,
               team_abbreviation AS subtitle
        FROM teams
        ORDER BY label
        """,
    )
    player_rows = rows(
        db,
        """
        SELECT 'player' AS type,
               player_id AS id,
               player_name AS label,
               profile_url AS subtitle
        FROM players
        ORDER BY player_name
        """,
    )
    return team_rows + player_rows


def main() -> int:
    args = parse_args()
    database = Path(args.database)
    if not database.exists():
        raise FileNotFoundError(f"Warehouse does not exist: {database}")
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)

    with connect(database) as db:
        documents: dict[str, Any] = {
            "manifest.json": build_manifest(db, output),
            "teams.json": export_teams(db),
            "players.json": export_players(db),
            "games.json": export_games(db),
            "team_records.json": export_team_records(db),
            "player_leaders.json": export_player_leaders(db, max(1, args.leader_limit)),
            "player_game_highs.json": export_player_game_highs(db, max(1, args.high_limit)),
            "search_index.json": export_search_index(db),
        }

    for filename, document in documents.items():
        write_json(output / filename, document)

    summary = {
        "output": str(output),
        "files": sorted(documents.keys()),
        "counts": {
            filename: len(document) if isinstance(document, list) else len(document.keys())
            for filename, document in documents.items()
        },
    }
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
