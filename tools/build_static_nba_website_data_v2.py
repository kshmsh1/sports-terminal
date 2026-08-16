from __future__ import annotations

import argparse
import json
import os
import re
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
    game_index,
    now_iso,
    player_index,
    rows,
    season_catalog as _base_season_catalog,
    static_player_dossier,
    static_team_dossier,
    team_index,
    write_json,
)

DEFAULT_DB = ROOT / "data/warehouse/nba_history.sqlite"
DEFAULT_OUTPUT = ROOT / "web/data/nba_static"
STATIC_SCHEMA_VERSION = 4
KNOWN_MISSING_SEASONS = {"1946-47", "1947-48", "1948-49"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Compile canonical NBA history into immutable sharded website JSON.")
    parser.add_argument("--database", default=str(DEFAULT_DB))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--skip-entities", action="store_true")
    parser.add_argument("--recent-player-games", type=int, default=30)
    parser.add_argument("--recent-team-games", type=int, default=30)
    return parser.parse_args()


def season_catalog(db: sqlite3.Connection) -> list[dict[str, Any]]:
    """Return one canonical NBA season per start year with distinct entity counts."""
    result = _base_season_catalog(db)
    for season in result:
        source_id = str(season.get("source_season_id") or season["season_id"])
        season["players"] = int(
            db.execute(
                "SELECT COUNT(DISTINCT player_key) FROM canon_fact_player_season WHERE season_id=? AND league_id='NBA'",
                (source_id,),
            ).fetchone()[0]
        )
        season["teams"] = int(
            db.execute(
                "SELECT COUNT(DISTINCT team_key) FROM canon_fact_team_season WHERE season_id=? AND league_id='NBA'",
                (source_id,),
            ).fetchone()[0]
        )
        season["games"] = int(
            db.execute(
                "SELECT COUNT(DISTINCT game_key) FROM canon_dim_game WHERE season_id=? AND league_id='NBA'",
                (source_id,),
            ).fetchone()[0]
        )
    return result


def _number(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _truthy_database_flag(value: Any) -> bool:
    if value is True:
        return True
    if isinstance(value, (int, float)):
        return value != 0
    return str(value or "").strip().lower() in {"1", "true", "yes", "y", "winner", "selected"}


def _selection_team(award_name: Any, rank_text: Any) -> str | None:
    """Recognize explicit team selections without promoting ordinary vote ranks."""
    award = str(award_name or "").lower().replace("_", " ").replace("-", " ")
    if not any(family in award for family in ("all nba", "all defense", "all rookie")):
        return None
    rank = str(rank_text or "").strip().lower()
    normalized = re.sub(r"[^a-z0-9]+", " ", rank).strip()
    if re.search(r"\b(first|1st|team 1|1 team)\b", normalized):
        return "First Team"
    if re.search(r"\b(second|2nd|team 2|2 team)\b", normalized):
        return "Second Team"
    if "all nba" in award and re.search(r"\b(third|3rd|team 3|3 team)\b", normalized):
        return "Third Team"
    return None


def _normalize_award(award: dict[str, Any]) -> None:
    if "winner" in award:
        award["winner"] = _truthy_database_flag(award.get("winner"))
    selection = _selection_team(award.get("award") or award.get("award_name"), award.get("rank_text"))
    if selection:
        award["selected"] = True
        award["selection_team"] = selection


def _normalize_player_dossier(dossier: dict[str, Any]) -> dict[str, Any]:
    awards = dossier.get("awards")
    if isinstance(awards, list):
        for award in awards:
            if isinstance(award, dict):
                _normalize_award(award)
    return dossier


def _first_number(row: dict[str, Any], *fields: str) -> float | None:
    for field in fields:
        value = _number(row.get(field))
        if value is not None:
            return value
    return None


def _per_game(row: dict[str, Any], *fields: str) -> float | None:
    games = _first_number(row, "games", "gp")
    total = _first_number(row, *fields)
    if games is None or games <= 0 or total is None:
        return None
    return round(total / games, 3)


def _dashboard_player(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "player_id": row.get("player_id"),
        "player_name": row.get("player_name") or row.get("player_label"),
        "team_id": row.get("team_id"),
        "team": row.get("team_ids") or row.get("team") or "",
        "position": row.get("positions") or row.get("position") or "",
        "games": row.get("games"),
        "ppg": _per_game(row, "points", "pts"),
        "rpg": _per_game(row, "rebounds", "reb"),
        "apg": _per_game(row, "assists", "ast"),
        "spg": _per_game(row, "steals", "stl"),
        "bpg": _per_game(row, "blocks", "blk"),
        "tpg": _per_game(row, "turnovers", "tov"),
        "pfpg": _per_game(row, "personal_fouls", "pf"),
        "fgmpg": _per_game(row, "field_goals_made", "fgm", "fg"),
        "three_pmg": _per_game(row, "three_pointers_made", "three_pm", "fg3"),
        "ftmpg": _per_game(row, "free_throws_made", "ftm", "ft"),
    }


def _leader_rows(records: list[dict[str, Any]], metric: str, *, entity: str, limit: int = 10) -> list[dict[str, Any]]:
    eligible = [row for row in records if _number(row.get(metric)) is not None]
    eligible.sort(key=lambda row: float(row.get(metric) or 0), reverse=True)
    result: list[dict[str, Any]] = []
    for index, row in enumerate(eligible[:limit], start=1):
        item = {"rank": index, "value": row.get(metric)}
        if entity == "player":
            item.update({
                "player_id": row.get("player_id"),
                "player_name": row.get("player_name"),
                "team_id": row.get("team_id"),
                "team": row.get("team"),
                "position": row.get("position"),
            })
        else:
            item.update({
                "team_key": row.get("team_key"),
                "team_id": row.get("team_key"),
                "team_name": row.get("team_name"),
                "team": row.get("team_name"),
                "abbreviation": row.get("abbreviation"),
            })
        result.append(item)
    return result


def _team_dashboard_rows(db: sqlite3.Connection, source_season_id: str) -> list[dict[str, Any]]:
    raw = rows(
        db.execute(
            """
            SELECT ts.*,t.canonical_name AS team_name,t.abbreviation
            FROM canon_fact_team_season ts
            LEFT JOIN canon_dim_team t ON t.team_key=ts.team_key
            WHERE ts.season_id=? AND ts.league_id='NBA' AND ts.season_type='regular'
            """,
            (source_season_id,),
        )
    )
    result: list[dict[str, Any]] = []
    for row in raw:
        result.append({
            "team_key": row.get("team_key"),
            "team_name": row.get("team_name"),
            "abbreviation": row.get("abbreviation"),
            "ppg": _per_game(row, "pts", "points"),
            "rpg": _per_game(row, "reb", "rebounds"),
            "apg": _per_game(row, "ast", "assists"),
            "spg": _per_game(row, "stl", "steals"),
            "bpg": _per_game(row, "blk", "blocks"),
            "tpg": _per_game(row, "tov", "turnovers"),
            "pfpg": _per_game(row, "pf", "personal_fouls"),
            "fgmpg": _per_game(row, "fg", "fgm", "field_goals_made"),
            "three_pmg": _per_game(row, "fg3", "three_pm", "three_pointers_made"),
            "ftmpg": _per_game(row, "ft", "ftm", "free_throws_made"),
        })
    return result


_LEADER_SPECS = {
    "points": "ppg",
    "rebounds": "rpg",
    "assists": "apg",
    "steals": "spg",
    "blocks": "bpg",
    "turnovers": "tpg",
    "personal_fouls": "pfpg",
    "field_goals_made": "fgmpg",
    "three_pointers_made": "three_pmg",
    "free_throws_made": "ftmpg",
}


def dashboard_payload(db: sqlite3.Connection, season_id: str, source_season_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    player_totals = payload.get("player_season_totals")
    raw_players = player_totals if isinstance(player_totals, list) else []
    players = [_dashboard_player(row) for row in raw_players if isinstance(row, dict) and row.get("player_id")]
    players.sort(key=lambda row: str(row.get("player_name") or ""))
    team_stats = _team_dashboard_rows(db, source_season_id)

    raw_games = payload.get("games")
    games = [row for row in raw_games if isinstance(row, dict)] if isinstance(raw_games, list) else []
    completed_games = [
        row for row in games
        if _number(row.get("home_score")) is not None and _number(row.get("away_score")) is not None
    ]
    completed_games.sort(
        key=lambda row: (str(row.get("game_date") or ""), str(row.get("game_id") or "")),
        reverse=True,
    )
    teams = payload.get("teams") if isinstance(payload.get("teams"), list) else []
    team_records = payload.get("team_records") if isinstance(payload.get("team_records"), list) else []

    return {
        "contract": "sports-terminal-static-dashboard-v2",
        "season_id": season_id,
        "season_type": "regular",
        "players": players,
        "leaders": {name: _leader_rows(players, metric, entity="player") for name, metric in _LEADER_SPECS.items()},
        "team_leaders": {name: _leader_rows(team_stats, metric, entity="team") for name, metric in _LEADER_SPECS.items()},
        "teams": teams,
        "team_records": team_records,
        "recent_games": completed_games[:12],
        "runtime_api_required": False,
    }


def build() -> int:
    args = parse_args()
    database = Path(args.database).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()
    if not database.is_file():
        raise SystemExit(f"NBA history warehouse not found: {database}")

    fingerprint = db_fingerprint(database)
    fingerprint["compiler_entrypoint"] = f"v2-static-schema-{STATIC_SCHEMA_VERSION}"
    manifest_path = output / "manifest.json"
    if not args.force and manifest_path.exists():
        try:
            current = json.loads(manifest_path.read_text(encoding="utf-8"))
            if current.get("database_fingerprint") == fingerprint:
                required = [
                    output / "seasons.json",
                    output / "players/index.json",
                    output / "teams/index.json",
                    output / "games/index.json",
                ]
                latest = str(current.get("latest_season") or "")
                if latest:
                    required.extend([
                        output / f"seasons/{latest}/regular.json",
                        output / f"dashboard/{latest}.json",
                    ])
                if all(path.is_file() for path in required):
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

        expected = {f"{year:04d}-{(year + 1) % 100:02d}" for year in range(1946, 2026)}
        actual = {str(row["season_id"]) for row in seasons}
        missing = expected - actual
        extra = actual - expected
        unexpected_missing = missing - KNOWN_MISSING_SEASONS
        if unexpected_missing or extra:
            raise SystemExit(
                "NBA season catalog failed canonical coverage: "
                f"missing={sorted(unexpected_missing)[:10]} extra={sorted(extra)[:10]}"
            )
        known_missing = sorted(missing & KNOWN_MISSING_SEASONS)
        if known_missing:
            print(
                "NBA season catalog continuing with known historical coverage gaps: "
                + ", ".join(known_missing)
            )

        staging = output.parent / f".{output.name}.staging"
        if staging.exists():
            shutil.rmtree(staging)
        staging.mkdir(parents=True, exist_ok=True)

        write_json(staging / "seasons.json", seasons)
        write_json(staging / "players/index.json", players)
        write_json(staging / "teams/index.json", teams)
        write_json(staging / "games/index.json", games)

        generated_season_files = 0
        dashboard_files = 0
        for season in seasons:
            season_id = str(season["season_id"])
            source_id = str(season.get("source_season_id") or season_id)
            for season_type in ("regular", "playoffs"):
                count = int(
                    db.execute(
                        "SELECT COUNT(*) FROM canon_fact_player_season WHERE season_id=? AND league_id='NBA' AND season_type=?",
                        (source_id, season_type),
                    ).fetchone()[0]
                )
                if count == 0:
                    continue
                payload = historical_seed_snapshot(
                    source_id,
                    league="NBA",
                    season_type=season_type,
                    include_game_logs=False,
                    player_log_limit=0,
                )
                payload["season_id"] = season_id
                payload["static_data"] = True
                payload["static_compiler_version"] = COMPILER_VERSION
                write_json(staging / f"seasons/{season_id}/{season_type}.json", payload)
                generated_season_files += 1
                if season_type == "regular":
                    write_json(
                        staging / f"dashboard/{season_id}.json",
                        dashboard_payload(db, season_id, source_id, payload),
                    )
                    dashboard_files += 1

        if not args.skip_entities:
            for index, player in enumerate(players, start=1):
                dossier = static_player_dossier(
                    db,
                    str(player["player_key"]),
                    recent_games=max(0, args.recent_player_games),
                )
                dossier = _normalize_player_dossier(dossier)
                dossier["static_data"] = True
                write_json(staging / str(player["file"]), dossier)
                if index % 500 == 0:
                    print(f"  player dossiers: {index}/{len(players)}")

            for index, team in enumerate(teams, start=1):
                dossier = static_team_dossier(
                    db,
                    str(team["team_key"]),
                    recent_games=max(0, args.recent_team_games),
                )
                dossier["static_data"] = True
                write_json(staging / str(team["file"]), dossier)
                if index % 50 == 0:
                    print(f"  team dossiers: {index}/{len(teams)}")

        awards = rows(db.execute("SELECT * FROM canon_fact_award ORDER BY season_id,award,player_name"))
        for award in awards:
            _normalize_award(award)
        all_star = rows(db.execute("SELECT * FROM canon_fact_all_star ORDER BY season_id,player_name"))
        draft = rows(db.execute("SELECT * FROM canon_fact_draft ORDER BY draft_year,pick_number,player_name"))
        coverage = rows(db.execute("SELECT * FROM canon_coverage WHERE league_id='NBA' ORDER BY season_id,domain"))
        write_json(staging / "history/awards.json", awards)
        write_json(staging / "history/all_star.json", all_star)
        write_json(staging / "history/draft.json", draft)
        write_json(staging / "history/coverage.json", coverage)

        manifest = {
            "contract": "sports-terminal-static-nba-website-v4",
            "static_schema_version": STATIC_SCHEMA_VERSION,
            "compiler_version": COMPILER_VERSION,
            "generated_at": now_iso(),
            "database_fingerprint": fingerprint,
            "latest_season": seasons[0]["season_id"] if seasons else None,
            "season_count": len(seasons),
            "known_missing_seasons": known_missing,
            "season_file_count": generated_season_files,
            "dashboard_file_count": dashboard_files,
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
                "dashboard_precomputed": True,
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
