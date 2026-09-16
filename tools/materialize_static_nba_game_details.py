from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB = ROOT / "data/warehouse/nba_history.sqlite"
DEFAULT_OUTPUT = ROOT / "web/data/nba_static"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Materialize source-backed historical NBA game/box-score detail files "
            "from the local canonical warehouse. No network requests are performed."
        )
    )
    parser.add_argument("--database", default=str(DEFAULT_DB))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def _rows(cursor: sqlite3.Cursor) -> list[dict[str, Any]]:
    columns = [item[0] for item in cursor.description or []]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def _token(value: str) -> str:
    safe = "".join(ch.lower() if ch.isalnum() else "-" for ch in value).strip("-")
    safe = "-".join(part for part in safe.split("-") if part)
    if len(safe) <= 96:
        return safe or hashlib.sha1(value.encode()).hexdigest()[:16]
    digest = hashlib.sha1(value.encode()).hexdigest()[:12]
    return f"{safe[:80]}-{digest}"


def _write(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    temp.replace(path)


def _fingerprint(path: Path) -> dict[str, Any]:
    stat = path.stat()
    return {"size": stat.st_size, "mtime_ns": stat.st_mtime_ns}


def _columns(db: sqlite3.Connection, table: str) -> set[str]:
    return {str(row[1]) for row in db.execute(f"PRAGMA table_info({table})").fetchall()}


def _league_where(alias: str, columns: set[str]) -> str:
    return f" AND {alias}.league_id='NBA'" if "league_id" in columns else ""


def main() -> int:
    args = parse_args()
    database = Path(args.database).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()
    index_path = output / "games/index.json"
    state_path = output / "games/detail_manifest.json"
    if not database.is_file() or not index_path.is_file():
        raise SystemExit("Canonical NBA database/static game index is missing.")

    fingerprint = _fingerprint(database)
    if not args.force and state_path.is_file():
        try:
            state = json.loads(state_path.read_text(encoding="utf-8"))
            if state.get("database_fingerprint") == fingerprint:
                print("Static NBA game details are current.")
                return 0
        except Exception:
            pass

    index = json.loads(index_path.read_text(encoding="utf-8"))
    if not isinstance(index, list):
        raise SystemExit("Static NBA game index has an invalid shape.")

    written = 0
    with sqlite3.connect(str(database)) as db:
        db.row_factory = sqlite3.Row
        player_columns = _columns(db, "canon_fact_player_game")
        team_columns = _columns(db, "canon_fact_team_game")
        player_league_filter = _league_where("pg", player_columns)
        team_league_filter = _league_where("tg", team_columns)

        counts = {
            str(row[0]): int(row[1] or 0)
            for row in db.execute(
                "SELECT game_key,COUNT(*) FROM canon_fact_player_game pg "
                f"WHERE 1=1{player_league_filter} GROUP BY game_key"
            ).fetchall()
        }
        team_counts = {
            str(row[0]): int(row[1] or 0)
            for row in db.execute(
                "SELECT game_key,COUNT(*) FROM canon_fact_team_game tg "
                f"WHERE 1=1{team_league_filter} GROUP BY game_key"
            ).fetchall()
        }

        for game in index:
            if not isinstance(game, dict):
                continue
            game_key = str(game.get("game_key") or "")
            if not game_key:
                continue
            has_players = counts.get(game_key, 0) > 0
            has_teams = team_counts.get(game_key, 0) > 0
            if not has_players and not has_teams:
                game.pop("file", None)
                game["box_score_available"] = False
                continue

            relative = f"games/detail/{_token(game_key)}.json"
            game["file"] = relative
            game["box_score_available"] = True
            player_rows = _rows(
                db.execute(
                    f"""
                    SELECT pg.*,p.canonical_name AS player_name,
                           t.canonical_name AS team_name,t.abbreviation AS team_abbreviation,
                           ot.canonical_name AS opponent_name,ot.abbreviation AS opponent_abbreviation
                    FROM canon_fact_player_game pg
                    LEFT JOIN canon_dim_player p ON p.player_key=pg.player_key
                    LEFT JOIN canon_dim_team t ON t.team_key=pg.team_key
                    LEFT JOIN canon_dim_team ot ON ot.team_key=pg.opponent_team_key
                    WHERE pg.game_key=?{player_league_filter}
                    ORDER BY pg.team_key,COALESCE(pg.minutes,0) DESC,p.canonical_name
                    """,
                    (game_key,),
                )
            ) if has_players else []
            team_rows = _rows(
                db.execute(
                    f"""
                    SELECT tg.*,t.canonical_name AS team_name,t.abbreviation AS team_abbreviation,
                           ot.canonical_name AS opponent_name,ot.abbreviation AS opponent_abbreviation
                    FROM canon_fact_team_game tg
                    LEFT JOIN canon_dim_team t ON t.team_key=tg.team_key
                    LEFT JOIN canon_dim_team ot ON ot.team_key=tg.opponent_team_key
                    WHERE tg.game_key=?{team_league_filter}
                    ORDER BY tg.team_key
                    """,
                    (game_key,),
                )
            ) if has_teams else []
            _write(
                output / relative,
                {
                    "contract": "sports-terminal-static-box-score-v1",
                    "static_data": True,
                    "game": game,
                    "team_box_scores": team_rows,
                    "player_box_scores": player_rows,
                    "player_rows": len(player_rows),
                    "team_rows": len(team_rows),
                },
            )
            written += 1

    _write(index_path, index)
    _write(
        state_path,
        {
            "contract": "sports-terminal-static-box-score-manifest-v1",
            "database_fingerprint": fingerprint,
            "game_details": written,
            "network_requests": 0,
        },
    )
    print(f"Materialized {written} historical NBA game detail/box-score files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
