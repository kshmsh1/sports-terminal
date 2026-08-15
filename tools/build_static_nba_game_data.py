from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path
from typing import Any, Iterator

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB = ROOT / "data/warehouse/nba_history.sqlite"
DEFAULT_OUTPUT = ROOT / "web/data/nba_static"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Materialize canonical historical NBA game detail and PBP into static per-game shards."
    )
    parser.add_argument("--database", default=str(DEFAULT_DB))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--include-pbp", action="store_true")
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def token(value: str) -> str:
    import hashlib

    return hashlib.sha1(value.encode("utf-8")).hexdigest()[:24]


def row_dict(row: sqlite3.Row) -> dict[str, Any]:
    return {key: row[key] for key in row.keys()}


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":"), default=str),
        encoding="utf-8",
    )
    temp.replace(path)


def table_or_view_exists(db: sqlite3.Connection, name: str) -> bool:
    return (
        db.execute(
            "SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name=?",
            (name,),
        ).fetchone()
        is not None
    )


def grouped(cursor: sqlite3.Cursor, key: str) -> Iterator[tuple[str, list[dict[str, Any]]]]:
    current_key: str | None = None
    batch: list[dict[str, Any]] = []
    for raw in cursor:
        item = row_dict(raw)
        value = str(item.get(key) or "")
        if not value:
            continue
        if current_key is None:
            current_key = value
        if value != current_key:
            yield current_key, batch
            current_key = value
            batch = []
        batch.append(item)
    if current_key is not None:
        yield current_key, batch


def game_metadata(db: sqlite3.Connection) -> dict[str, dict[str, Any]]:
    return {
        str(row["game_key"]): row_dict(row)
        for row in db.execute(
            """
            SELECT g.*,ht.canonical_name AS home_team_name,ht.abbreviation AS home_team_abbreviation,
                   at.canonical_name AS away_team_name,at.abbreviation AS away_team_abbreviation
            FROM canon_dim_game g
            LEFT JOIN canon_dim_team ht ON ht.team_key=g.home_team_key
            LEFT JOIN canon_dim_team at ON at.team_key=g.away_team_key
            WHERE g.league_id='NBA'
            """
        )
    }


def team_rows(db: sqlite3.Connection) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = {}
    cursor = db.execute(
        "SELECT * FROM canon_fact_team_game WHERE league_id='NBA' ORDER BY game_key,is_home DESC"
    )
    for game_key, rows in grouped(cursor, "game_key"):
        result[game_key] = rows
    return result


def materialize_games(
    db: sqlite3.Connection,
    output: Path,
    games: dict[str, dict[str, Any]],
) -> tuple[int, dict[str, str]]:
    teams = team_rows(db)
    files: dict[str, str] = {}
    count = 0
    cursor = db.execute(
        """
        SELECT * FROM canon_fact_player_game
        WHERE league_id='NBA'
        ORDER BY game_key,team_abbreviation,player_name,source_row
        """
    )
    seen: set[str] = set()
    for game_key, players in grouped(cursor, "game_key"):
        game = games.get(game_key)
        if game is None:
            continue
        season = str(game.get("season_id") or "unknown")
        relative = f"games/{season}/{token(game_key)}.json"
        write_json(
            output / relative,
            {
                "contract": "sports-terminal-static-game-v1",
                "game": game,
                "teams": teams.get(game_key, []),
                "players": players,
                "source": "canonical-historical-warehouse",
            },
        )
        files[game_key] = relative
        seen.add(game_key)
        count += 1
        if count % 5000 == 0:
            print(f"  game detail shards: {count}")

    # Preserve games for which team rows exist but player rows do not.
    for game_key, game in games.items():
        if game_key in seen or game_key not in teams:
            continue
        season = str(game.get("season_id") or "unknown")
        relative = f"games/{season}/{token(game_key)}.json"
        write_json(
            output / relative,
            {
                "contract": "sports-terminal-static-game-v1",
                "game": game,
                "teams": teams.get(game_key, []),
                "players": [],
                "source": "canonical-historical-warehouse",
            },
        )
        files[game_key] = relative
        count += 1
    return count, files


def materialize_pbp(
    db: sqlite3.Connection,
    output: Path,
    games: dict[str, dict[str, Any]],
) -> tuple[int, int, dict[str, str]]:
    if not table_or_view_exists(db, "canon_fact_play_by_play"):
        return 0, 0, {}
    files: dict[str, str] = {}
    game_count = 0
    event_count = 0
    cursor = db.execute(
        """
        SELECT * FROM canon_fact_play_by_play
        ORDER BY game_key,period,event_number
        """
    )
    for game_key, events in grouped(cursor, "game_key"):
        game = games.get(game_key)
        if game is None:
            continue
        season = str(game.get("season_id") or "unknown")
        relative = f"pbp/{season}/{token(game_key)}.json"
        write_json(
            output / relative,
            {
                "contract": "sports-terminal-static-pbp-v1",
                "game_key": game_key,
                "season_id": season,
                "row_count": len(events),
                "rows": events,
                "source": "canon_fact_play_by_play",
            },
        )
        files[game_key] = relative
        game_count += 1
        event_count += len(events)
        if game_count % 5000 == 0:
            print(f"  PBP shards: {game_count} games / {event_count} events")
    return game_count, event_count, files


def main() -> int:
    args = parse_args()
    database = Path(args.database).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()
    if not database.is_file():
        raise SystemExit(f"NBA history warehouse not found: {database}")
    manifest_path = output / "manifest.json"
    if not manifest_path.is_file():
        raise SystemExit(
            "Core static NBA corpus is missing. Run build_static_nba_website_data_v2.py first."
        )
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    with sqlite3.connect(str(database)) as db:
        db.row_factory = sqlite3.Row
        games = game_metadata(db)
        detail_count, detail_files = materialize_games(db, output, games)
        pbp_game_count = 0
        pbp_event_count = 0
        pbp_files: dict[str, str] = {}
        if args.include_pbp:
            pbp_game_count, pbp_event_count, pbp_files = materialize_pbp(
                db, output, games
            )

    index_path = output / "games/index.json"
    index = json.loads(index_path.read_text(encoding="utf-8")) if index_path.is_file() else []
    if isinstance(index, list):
        for item in index:
            if not isinstance(item, dict):
                continue
            key = str(item.get("game_key") or "")
            if key in detail_files:
                item["file"] = detail_files[key]
            if key in pbp_files:
                item["pbp_file"] = pbp_files[key]
        write_json(index_path, index)

    manifest["game_detail"] = {
        "contract": "sports-terminal-static-game-v1",
        "game_files": detail_count,
        "runtime_api_required": False,
    }
    manifest["play_by_play"] = {
        "contract": "sports-terminal-static-pbp-v1",
        "materialized": bool(args.include_pbp),
        "game_files": pbp_game_count,
        "event_rows": pbp_event_count,
        "runtime_api_required": False,
        "coverage_is_source_bounded": True,
    }
    write_json(manifest_path, manifest)
    print(
        f"Static game materialization complete: {detail_count} game files; "
        f"{pbp_game_count} PBP files / {pbp_event_count} PBP rows"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
