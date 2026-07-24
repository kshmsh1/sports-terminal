from __future__ import annotations

import argparse
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Export launch-only NBA supplements that are intentionally larger than the compact "
            "Flutter seed: complete player game logs, loaded standings, and a release manifest."
        )
    )
    parser.add_argument("--warehouse", required=True)
    parser.add_argument("--seed", required=True)
    parser.add_argument("--season", type=int, default=2026)
    return parser.parse_args()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, ensure_ascii=False, default=str) + "\n",
        encoding="utf-8",
    )


def rows(connection: sqlite3.Connection, query: str) -> list[dict[str, Any]]:
    return [dict(row) for row in connection.execute(query).fetchall()]


def count(connection: sqlite3.Connection, table: str) -> int:
    return int(connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0])


def season_label(season_end_year: int) -> str:
    return f"{season_end_year - 1}-{str(season_end_year)[-2:]}"


def main() -> int:
    args = parse_args()
    warehouse = Path(args.warehouse)
    seed = Path(args.seed)
    if not warehouse.exists():
        raise FileNotFoundError(f"Warehouse does not exist: {warehouse}")
    seed.mkdir(parents=True, exist_ok=True)

    connection = sqlite3.connect(warehouse)
    connection.row_factory = sqlite3.Row
    try:
        player_logs = rows(
            connection,
            """
            SELECT pgs.game_id,
                   g.game_date,
                   pgs.team_id,
                   CASE WHEN g.home_team_id = pgs.team_id THEN g.away_team_id ELSE g.home_team_id END AS opponent_team_id,
                   CASE WHEN g.home_team_id = pgs.team_id THEN 1 ELSE 0 END AS is_home,
                   pgs.player_id,
                   pgs.player_label,
                   pgs.mp_text,
                   pgs.mp_seconds,
                   pgs.fg,
                   pgs.fga,
                   pgs.fg_pct,
                   pgs.fg3,
                   pgs.fg3a,
                   pgs.fg3_pct,
                   pgs.ft,
                   pgs.fta,
                   pgs.ft_pct,
                   pgs.orb,
                   pgs.drb,
                   pgs.trb,
                   pgs.ast,
                   pgs.stl,
                   pgs.blk,
                   pgs.tov,
                   pgs.pf,
                   pgs.pts,
                   pgs.plus_minus,
                   pgs.ts_pct,
                   pgs.efg_pct,
                   pgs.usg_pct,
                   pgs.off_rtg,
                   pgs.def_rtg,
                   pgs.bpm
            FROM player_game_stats AS pgs
            LEFT JOIN games AS g ON g.game_id = pgs.game_id
            WHERE COALESCE(pgs.mp_seconds, 0) > 0
            ORDER BY g.game_date, pgs.game_id, pgs.team_id, pgs.player_label
            """,
        )
        standings = rows(
            connection,
            """
            SELECT team_id,
                   COUNT(*) AS games,
                   SUM(CASE WHEN result = 'W' THEN 1 ELSE 0 END) AS wins,
                   SUM(CASE WHEN result = 'L' THEN 1 ELSE 0 END) AS losses,
                   SUM(CASE WHEN is_home = 1 AND result = 'W' THEN 1 ELSE 0 END) AS home_wins,
                   SUM(CASE WHEN is_home = 1 AND result = 'L' THEN 1 ELSE 0 END) AS home_losses,
                   SUM(CASE WHEN is_home = 0 AND result = 'W' THEN 1 ELSE 0 END) AS away_wins,
                   SUM(CASE WHEN is_home = 0 AND result = 'L' THEN 1 ELSE 0 END) AS away_losses,
                   ROUND(AVG(points), 3) AS points_per_game,
                   ROUND(AVG(opponent_points), 3) AS opponent_points_per_game,
                   ROUND(AVG(points - opponent_points), 3) AS average_margin
            FROM team_game_stats
            GROUP BY team_id
            ORDER BY wins DESC, losses ASC, team_id
            """,
        )
        quality_checks = rows(
            connection,
            "SELECT check_name, status, expected, actual, details_json FROM warehouse_quality_checks ORDER BY check_name",
        )
        counts = {
            table: count(connection, table)
            for table in [
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
        }
    finally:
        connection.close()

    critical_failures = [
        check["check_name"]
        for check in quality_checks
        if str(check["status"]).lower() not in {"pass", "ok", "success"}
    ]
    minimums = {
        "teams": counts["teams"] == 30,
        "games": counts["games"] >= 1200,
        "player_game_stats": counts["player_game_stats"] >= 10000,
        "team_game_stats": counts["team_game_stats"] >= counts["games"] * 2,
        "players": counts["players"] >= 400,
        "play_by_play": counts["play_by_play_events_normalized"] > 0,
    }
    status = "candidate" if all(minimums.values()) and not critical_failures else "incomplete"
    generated_at = datetime.now(timezone.utc).isoformat()
    release_manifest = {
        "id": f"nba-{season_label(args.season)}-local-release",
        "league": "NBA",
        "season": season_label(args.season),
        "seasonEndYear": args.season,
        "status": status,
        "version": generated_at.replace(":", "").replace("-", ""),
        "generatedAt": generated_at,
        "warehouse": str(warehouse),
        "seed": str(seed),
        "counts": counts,
        "minimumChecks": minimums,
        "warehouseQualityChecks": quality_checks,
        "criticalFailures": critical_failures,
        "files": {
            "playerGameLogs": "player_game_logs.json",
            "standings": "standings.json",
            "releaseManifest": "release_manifest.json",
        },
        "sourceNotes": [
            "Generated from the local normalized NBA warehouse.",
            "Commercial launch still requires approved source rights and customer-facing attribution policy.",
            "Standings summarize all loaded team-game rows; the release validator must certify schedule scope.",
        ],
    }

    write_json(seed / "player_game_logs.json", player_logs)
    write_json(seed / "standings.json", standings)
    write_json(seed / "release_manifest.json", release_manifest)
    print(
        json.dumps(
            {
                "status": status,
                "season": season_label(args.season),
                "playerGameLogs": len(player_logs),
                "teams": counts["teams"],
                "games": counts["games"],
                "output": str(seed),
            },
            indent=2,
        )
    )
    return 0 if status == "candidate" else 2


if __name__ == "__main__":
    raise SystemExit(main())
