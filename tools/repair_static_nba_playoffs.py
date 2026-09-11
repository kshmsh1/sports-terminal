from __future__ import annotations

import argparse
import json
import os
import re
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

from tools.build_static_nba_website_data import write_json  # noqa: E402

DEFAULT_OUTPUT = ROOT / "web/data/nba_static"


def _season_start(value: Any) -> int | None:
    match = re.search(r"(?<!\d)(19|20)\d{2}(?!\d)", str(value or ""))
    return int(match.group(0)) if match else None


def _valid_snapshot(path: Path) -> bool:
    if not path.is_file() or path.stat().st_size == 0:
        return False
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return False
    return isinstance(payload, dict) and isinstance(payload.get("player_season_totals"), list)


def _empty_snapshot(public_season: str) -> dict[str, Any]:
    """Valid empty fallback used only when the warehouse truly has no playoff row.

    The browser should never receive an HTML SPA fallback for a missing JSON shard.
    A valid empty payload lets the UI render a conventional no-data table instead.
    """
    return {
        "manifest": {
            "league": "NBA",
            "season": public_season,
            "seasonType": "playoffs",
            "datasetStatus": "historical-canonical",
        },
        "teams": [],
        "players": [],
        "games": [],
        "team_records": [],
        "team_game_logs": [],
        "player_season_totals": [],
        "player_leaders": {},
        "player_game_highs": {},
        "player_game_logs_top": [],
        "search_index": [],
        "data_dictionary": {},
        "standings": [],
        "play_by_play": [],
        "season_id": public_season,
        "season_type": "playoffs",
        "static_data": True,
        "static_playoff_repair": True,
    }


def _candidate_playoff_seasons(db: sqlite3.Connection) -> dict[int, list[tuple[str, int]]]:
    rows = db.execute(
        """
        SELECT season_id, COUNT(DISTINCT player_key) AS players
        FROM canon_fact_player_season
        WHERE league_id='NBA' AND lower(season_type) IN ('playoffs','postseason','playoff')
        GROUP BY season_id
        """
    ).fetchall()
    grouped: dict[int, list[tuple[str, int]]] = {}
    for season_id, player_count in rows:
        year = _season_start(season_id)
        if year is None:
            continue
        grouped.setdefault(year, []).append((str(season_id), int(player_count or 0)))
    for candidates in grouped.values():
        candidates.sort(key=lambda item: item[1], reverse=True)
    return grouped


def repair_playoff_shards(database: Path, output: Path, *, force: bool = False) -> dict[str, int]:
    os.environ["SPORTS_TERMINAL_NBA_HISTORY_DB"] = str(database)
    from app.historical_nba_compat_api import historical_seed_snapshot

    seasons_path = output / "seasons.json"
    if not seasons_path.is_file():
        raise RuntimeError(f"Static NBA season catalog is missing: {seasons_path}")
    seasons = json.loads(seasons_path.read_text(encoding="utf-8"))
    if not isinstance(seasons, list):
        raise RuntimeError("Static NBA season catalog has an invalid shape")

    repaired = 0
    preserved = 0
    empty = 0
    with sqlite3.connect(str(database)) as db:
        candidates_by_year = _candidate_playoff_seasons(db)
        for item in seasons:
            if not isinstance(item, dict):
                continue
            public_id = str(item.get("season_id") or "").strip()
            if not public_id:
                continue
            target = output / "seasons" / public_id / "playoffs.json"
            if not force and _valid_snapshot(target):
                preserved += 1
                continue

            year = _season_start(public_id)
            candidates = list(candidates_by_year.get(year or -1, []))
            source_id = str(item.get("source_season_id") or "").strip()
            if source_id and all(candidate[0] != source_id for candidate in candidates):
                source_count = db.execute(
                    """
                    SELECT COUNT(DISTINCT player_key)
                    FROM canon_fact_player_season
                    WHERE season_id=? AND league_id='NBA'
                      AND lower(season_type) IN ('playoffs','postseason','playoff')
                    """,
                    (source_id,),
                ).fetchone()[0]
                if source_count:
                    candidates.append((source_id, int(source_count)))
                    candidates.sort(key=lambda candidate: candidate[1], reverse=True)

            payload: dict[str, Any] | None = None
            for candidate, _ in candidates:
                try:
                    candidate_payload = historical_seed_snapshot(
                        candidate,
                        league="NBA",
                        season_type="playoffs",
                        include_game_logs=False,
                        player_log_limit=0,
                    )
                except Exception:
                    continue
                rows = candidate_payload.get("player_season_totals") if isinstance(candidate_payload, dict) else None
                if isinstance(rows, list) and rows:
                    payload = candidate_payload
                    payload["source_season_id"] = candidate
                    break

            if payload is None:
                payload = _empty_snapshot(public_id)
                empty += 1
            else:
                payload["season_id"] = public_id
                payload["season_type"] = "playoffs"
                payload["static_data"] = True
                payload["static_playoff_repair"] = True

            write_json(target, payload)
            repaired += 1

    return {"repaired": repaired, "preserved": preserved, "empty": empty}


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Ensure every static NBA season has a valid playoff JSON shard.")
    parser.add_argument(
        "--database",
        default=os.environ.get("SPORTS_TERMINAL_NBA_HISTORY_DB", str(ROOT / "data/warehouse/nba_history.sqlite")),
    )
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    result = repair_playoff_shards(
        Path(args.database).expanduser().resolve(),
        Path(args.output).expanduser().resolve(),
        force=args.force,
    )
    print(
        "Static NBA playoff shards: "
        f"{result['repaired']} repaired; {result['preserved']} preserved; {result['empty']} empty fallbacks"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
