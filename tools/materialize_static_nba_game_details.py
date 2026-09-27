from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import unicodedata
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB = ROOT / "data/warehouse/nba_history.sqlite"
DEFAULT_OUTPUT = ROOT / "web/data/nba_static"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Materialize source-backed historical NBA game/box-score detail files "
            "from the local canonical warehouse and already-captured NBA.com "
            "traditional player game logs. No network requests are performed."
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


def _content_fingerprint(path: Path) -> str | None:
    if not path.is_file():
        return None
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _columns(db: sqlite3.Connection, table: str) -> set[str]:
    return {str(row[1]) for row in db.execute(f"PRAGMA table_info({table})").fetchall()}


def _league_where(alias: str, columns: set[str]) -> str:
    return f" AND {alias}.league_id='NBA'" if "league_id" in columns else ""


def _number(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).replace(",", "").strip())
    except ValueError:
        return None


def _name_token(value: Any) -> str:
    text = unicodedata.normalize("NFKD", str(value or "").strip().lower())
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9]+", "", text)


def _game_id_token(value: Any) -> str:
    text = str(value or "").strip()
    digits = re.sub(r"\D+", "", text)
    if digits:
        return digits.lstrip("0") or "0"
    return re.sub(r"[^a-z0-9]+", "", text.lower())


def _normalized_season_type(value: Any) -> str:
    return "playoffs" if "play" in str(value or "").lower() else "regular"


def _surface_rows(path: Path) -> list[dict[str, Any]]:
    if not path.is_file():
        return []
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    tables = payload.get("tables") if isinstance(payload, dict) else None
    rows: list[dict[str, Any]] = []
    if isinstance(tables, list):
        for table in tables:
            if not isinstance(table, dict):
                continue
            source = table.get("rows")
            if isinstance(source, list):
                rows.extend(dict(row) for row in source if isinstance(row, dict))
    return rows


def _normalize_nba_com_player_row(row: dict[str, Any]) -> dict[str, Any]:
    field_map = {
        "PLAYER_ID": "nba_player_id",
        "PLAYER_NAME": "player_name",
        "TEAM_ID": "nba_team_id",
        "TEAM_ABBREVIATION": "team_abbreviation",
        "TEAM_NAME": "team_name",
        "GAME_ID": "nba_game_id",
        "GAME_DATE": "game_date",
        "MATCHUP": "matchup",
        "WL": "wl",
        "MIN": "minutes",
        "PTS": "pts",
        "FGM": "fgm",
        "FGA": "fga",
        "FG_PCT": "fg_pct",
        "FG3M": "three_pm",
        "FG3A": "three_pa",
        "FG3_PCT": "three_pct",
        "FTM": "ftm",
        "FTA": "fta",
        "FT_PCT": "ft_pct",
        "OREB": "oreb",
        "DREB": "dreb",
        "REB": "reb",
        "AST": "ast",
        "STL": "stl",
        "BLK": "blk",
        "TOV": "tov",
        "PF": "pf",
        "PLUS_MINUS": "plus_minus",
        "FANTASY_PTS": "fantasy_pts",
        "VIDEO_AVAILABLE": "video_available",
    }
    result = {
        target: row.get(source)
        for source, target in field_map.items()
        if row.get(source) is not None
    }
    result["source"] = "nba_com/leaguegamelog"
    return result


class _NbaComTraditionalLookup:
    """Loads only one season/segment at a time to keep the 80-season corpus cheap."""

    def __init__(self, output: Path):
        self.output = output
        self.scope: tuple[str, str] | None = None
        self.games: dict[str, list[dict[str, Any]]] = {}

    def _load(self, season: str, season_type: str) -> None:
        normalized_type = _normalized_season_type(season_type)
        scope = (season, normalized_type)
        if scope == self.scope:
            return
        path = (
            self.output
            / "nba_com/surfaces/players_boxscores_traditional/default"
            / season
            / f"{normalized_type}.json"
        )
        grouped: dict[str, list[dict[str, Any]]] = {}
        for row in _surface_rows(path):
            token = _game_id_token(row.get("GAME_ID"))
            if token:
                grouped.setdefault(token, []).append(row)
        self.scope = scope
        self.games = grouped

    def rows_for(self, season: str, season_type: str, *game_ids: Any) -> list[dict[str, Any]]:
        self._load(season, season_type)
        for game_id in game_ids:
            token = _game_id_token(game_id)
            if token and token in self.games:
                return self.games[token]
        return []


def _merge_player_rows(
    canonical_rows: list[dict[str, Any]],
    nba_rows: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    if not nba_rows:
        return canonical_rows

    normalized_nba = [_normalize_nba_com_player_row(row) for row in nba_rows]
    by_identity: dict[tuple[str, str], list[int]] = {}
    by_name: dict[str, list[int]] = {}
    for index, row in enumerate(normalized_nba):
        name = _name_token(row.get("player_name"))
        team = str(row.get("team_abbreviation") or "").upper()
        if name:
            by_identity.setdefault((name, team), []).append(index)
            by_name.setdefault(name, []).append(index)

    consumed: set[int] = set()
    merged: list[dict[str, Any]] = []
    for canonical in canonical_rows:
        row = dict(canonical)
        name = _name_token(row.get("player_name"))
        team = str(row.get("team_abbreviation") or "").upper()
        candidates = by_identity.get((name, team), []) if name else []
        if len(candidates) != 1 and name:
            candidates = by_name.get(name, [])
        match = candidates[0] if len(candidates) == 1 else None
        if match is not None:
            consumed.add(match)
            source = normalized_nba[match]
            for key, value in source.items():
                if row.get(key) in (None, "") and value not in (None, ""):
                    row[key] = value
            row["nba_com_box_score"] = True
        merged.append(row)

    for index, row in enumerate(normalized_nba):
        if index not in consumed:
            merged.append({**row, "nba_com_box_score": True})

    merged.sort(
        key=lambda row: (
            str(row.get("team_abbreviation") or ""),
            -(_number(row.get("minutes")) or 0),
            str(row.get("player_name") or ""),
        )
    )
    return merged


def _fill_scores_from_nba(game: dict[str, Any], nba_rows: list[dict[str, Any]]) -> None:
    if not nba_rows:
        return
    totals: dict[str, float] = {}
    for row in nba_rows:
        team = str(row.get("TEAM_ABBREVIATION") or "").upper()
        points = _number(row.get("PTS"))
        if team and points is not None:
            totals[team] = totals.get(team, 0.0) + points

    home = str(game.get("home_team_abbreviation") or "").upper()
    away = str(game.get("away_team_abbreviation") or "").upper()
    if game.get("home_score") is None and home in totals:
        game["home_score"] = totals[home]
    if game.get("away_score") is None and away in totals:
        game["away_score"] = totals[away]


def main() -> int:
    args = parse_args()
    database = Path(args.database).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()
    index_path = output / "games/index.json"
    state_path = output / "games/detail_manifest.json"
    nba_com_manifest = output / "nba_com/manifest.json"
    if not database.is_file() or not index_path.is_file():
        raise SystemExit("Canonical NBA database/static game index is missing.")

    fingerprint = _fingerprint(database)
    nba_com_fingerprint = _content_fingerprint(nba_com_manifest)
    if not args.force and state_path.is_file():
        try:
            state = json.loads(state_path.read_text(encoding="utf-8"))
            if (
                state.get("database_fingerprint") == fingerprint
                and state.get("nba_com_fingerprint") == nba_com_fingerprint
            ):
                print("Static NBA game details are current.")
                return 0
        except Exception:
            pass

    index = json.loads(index_path.read_text(encoding="utf-8"))
    if not isinstance(index, list):
        raise SystemExit("Static NBA game index has an invalid shape.")

    written = 0
    unavailable = 0
    nba_augmented_games = 0
    nba_only_games = 0
    nba_player_rows = 0
    lookup = _NbaComTraditionalLookup(output)

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

            season = str(game.get("season_id") or "")
            season_type = str(game.get("season_type") or "regular")
            nba_rows = lookup.rows_for(
                season,
                season_type,
                game.get("nba_game_id"),
                game_key,
            )
            has_players = counts.get(game_key, 0) > 0
            has_teams = team_counts.get(game_key, 0) > 0
            if not has_players and not has_teams and not nba_rows:
                game.pop("file", None)
                game["box_score_available"] = False
                game["box_score_source"] = "unavailable"
                unavailable += 1
                continue

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

            canonical_player_count = len(player_rows)
            if nba_rows:
                player_rows = _merge_player_rows(player_rows, nba_rows)
                nba_player_rows += len(nba_rows)
                _fill_scores_from_nba(game, nba_rows)
                if canonical_player_count:
                    nba_augmented_games += 1
                    game["box_score_source"] = "canonical+nba_com"
                else:
                    nba_only_games += 1
                    game["box_score_source"] = "nba_com"
            else:
                game["box_score_source"] = "canonical"

            relative = f"games/detail/{_token(game_key)}.json"
            game["file"] = relative
            game["box_score_available"] = bool(player_rows)
            _write(
                output / relative,
                {
                    "contract": "sports-terminal-static-box-score-v2",
                    "static_data": True,
                    "game": game,
                    "team_box_scores": team_rows,
                    "player_box_scores": player_rows,
                    "player_rows": len(player_rows),
                    "team_rows": len(team_rows),
                    "sources": [
                        source
                        for source, available in (
                            ("canonical_warehouse", bool(canonical_player_count or team_rows)),
                            ("nba_com/leaguegamelog", bool(nba_rows)),
                        )
                        if available
                    ],
                },
            )
            written += 1

    _write(index_path, index)
    manifest = {
        "contract": "sports-terminal-static-box-score-manifest-v2",
        "database_fingerprint": fingerprint,
        "nba_com_fingerprint": nba_com_fingerprint,
        "game_details": written,
        "unavailable_games": unavailable,
        "nba_com_augmented_games": nba_augmented_games,
        "nba_com_only_games": nba_only_games,
        "nba_com_player_rows": nba_player_rows,
        "network_requests": 0,
    }
    _write(state_path, manifest)
    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
