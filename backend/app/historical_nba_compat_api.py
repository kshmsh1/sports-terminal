from __future__ import annotations

from collections import defaultdict
from typing import Any

from fastapi import APIRouter, HTTPException, Query

from .historical_nba_api import (
    _collapse_player_season_rows,
    _connect,
    _decode,
    _num,
    _rows,
    _season_type,
)

router = APIRouter(prefix="/v2/nba/history", tags=["nba-history-compat"])


def _player_seed_row(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "player_id": row.get("player_key"),
        "id": row.get("player_key"),
        "player_label": row.get("player_name"),
        "player_name": row.get("player_name"),
        "team_ids": row.get("team_abbreviation") or "",
        "team_id": row.get("team_key"),
        "team_name": row.get("team_name"),
        "position": row.get("position") or row.get("primary_position") or "",
        "age": row.get("age"),
        "season_type": row.get("season_type"),
        "games": row.get("games"),
        "games_started": row.get("games_started"),
        "minutes": row.get("minutes"),
        "points": row.get("pts"),
        "assists": row.get("ast"),
        "rebounds": row.get("reb"),
        "offensive_rebounds": row.get("orb"),
        "defensive_rebounds": row.get("drb"),
        "steals": row.get("stl"),
        "blocks": row.get("blk"),
        "turnovers": row.get("tov"),
        "personal_fouls": row.get("pf"),
        "field_goals_made": row.get("fgm"),
        "field_goal_attempts": row.get("fga"),
        "field_goal_percentage": row.get("fg_pct"),
        "two_pointers_made": row.get("two_pm"),
        "two_point_attempts": row.get("two_pa"),
        "two_point_percentage": row.get("two_pct"),
        "three_pointers_made": row.get("three_pm"),
        "three_point_attempts": row.get("three_pa"),
        "three_point_percentage": row.get("three_pct"),
        "free_throws_made": row.get("ftm"),
        "free_throw_attempts": row.get("fta"),
        "free_throw_percentage": row.get("ft_pct"),
        "true_shooting_percentage": row.get("ts_pct"),
        "effective_field_goal_percentage": row.get("efg_pct"),
        "per": row.get("per"),
        "win_shares": row.get("ws"),
        "win_shares_per_48": row.get("ws48"),
        "offensive_bpm": row.get("obpm"),
        "defensive_bpm": row.get("dbpm"),
        "avg_bpm": row.get("bpm"),
        "vorp": row.get("vorp"),
        "usage_percentage": row.get("usg_pct"),
        "offensive_rating": row.get("ortg"),
        "defensive_rating": row.get("drtg"),
        "primary_source": row.get("primary_source"),
        "source_count": row.get("source_count"),
        "synthetic_aggregate": bool(row.get("synthetic_aggregate")),
        "canonical_fact_key": row.get("fact_key") or "",
    }


def _player_profile(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "player_id": row.get("player_key"),
        "id": row.get("player_key"),
        "player_name": row.get("player_name"),
        "display_name": row.get("player_name"),
        "position": row.get("position") or row.get("primary_position") or "",
        "team_id": row.get("team_key"),
        "team_abbreviation": row.get("team_abbreviation"),
        "nba_id": row.get("nba_id"),
        "bref_id": row.get("bref_id"),
        "age": row.get("age"),
    }


def _team_record(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "team_id": row.get("team_key"),
        "team_abbreviation": row.get("team_abbreviation"),
        "team_name": row.get("team_name") or row.get("canonical_team_name"),
        "season_type": row.get("season_type"),
        "games": row.get("games"),
        "wins": row.get("wins"),
        "losses": row.get("losses"),
        "points": row.get("pts"),
        "opponent_points": row.get("opp_pts"),
        "pace": row.get("pace"),
        "offensive_rating": row.get("ortg"),
        "defensive_rating": row.get("drtg"),
        "net_rating": row.get("net_rtg"),
        "srs": row.get("srs"),
        "primary_source": row.get("primary_source"),
        "source_count": row.get("source_count"),
    }


def _game_row(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "game_id": row.get("game_key"),
        "id": row.get("game_key"),
        "nba_game_id": row.get("nba_game_id"),
        "game_date": row.get("game_date"),
        "season_type": row.get("season_type"),
        "home_team_id": row.get("home_team_key"),
        "away_team_id": row.get("away_team_key"),
        "home_team": row.get("home_team_abbreviation"),
        "away_team": row.get("away_team_abbreviation"),
        "home_team_name": row.get("home_team_name"),
        "away_team_name": row.get("away_team_name"),
        "home_score": row.get("home_score"),
        "away_score": row.get("away_score"),
        "winner_team_id": row.get("winner_team_key"),
        "status": row.get("status"),
    }


def _player_game_row(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "player_id": row.get("player_key"),
        "player_name": row.get("player_name"),
        "game_id": row.get("game_key") or row.get("source_game_id"),
        "game_date": row.get("game_date"),
        "season_type": row.get("season_type"),
        "team_id": row.get("team_key"),
        "team": row.get("team_abbreviation"),
        "opponent_team_id": row.get("opponent_team_key"),
        "opponent": row.get("opponent_abbreviation"),
        "minutes": row.get("minutes"),
        "points": row.get("pts"),
        "rebounds": row.get("reb"),
        "assists": row.get("ast"),
        "steals": row.get("stl"),
        "blocks": row.get("blk"),
        "turnovers": row.get("tov"),
        "personal_fouls": row.get("pf"),
        "true_shooting_percentage": row.get("ts_pct"),
        "effective_field_goal_percentage": row.get("efg_pct"),
        "usage_percentage": row.get("usg_pct"),
        "offensive_rating": row.get("ortg"),
        "defensive_rating": row.get("drtg"),
        "bpm": row.get("bpm"),
        "source": row.get("source_key"),
    }


def _team_game_row(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "game_id": row.get("game_key"),
        "game_date": row.get("game_date"),
        "team_id": row.get("team_key"),
        "team": row.get("team_abbreviation"),
        "team_name": row.get("team_name"),
        "opponent_team_id": row.get("opponent_team_key"),
        "opponent": row.get("opponent_abbreviation"),
        "opponent_name": row.get("opponent_name"),
        "is_home": bool(row.get("is_home")),
        "result": row.get("result"),
        "points": row.get("points"),
        "opponent_points": row.get("opponent_points"),
        "field_goals_made": row.get("fgm"),
        "field_goal_attempts": row.get("fga"),
        "three_pointers_made": row.get("three_pm"),
        "three_point_attempts": row.get("three_pa"),
        "free_throws_made": row.get("ftm"),
        "free_throw_attempts": row.get("fta"),
        "offensive_rebounds": row.get("orb"),
        "defensive_rebounds": row.get("drb"),
        "rebounds": row.get("reb"),
        "assists": row.get("ast"),
        "steals": row.get("stl"),
        "blocks": row.get("blk"),
        "turnovers": row.get("tov"),
        "personal_fouls": row.get("pf"),
        "source": row.get("source_key"),
    }


def _leader_rows(players: list[dict[str, Any]], field: str, *, limit: int = 10) -> list[dict[str, Any]]:
    eligible = [row for row in players if isinstance(row.get(field), (int, float))]
    eligible.sort(key=lambda row: float(row.get(field) or 0), reverse=True)
    return [
        {
            "rank": index,
            "player_id": row.get("player_id"),
            "player_label": row.get("player_label"),
            "team_ids": row.get("team_ids"),
            "value": row.get(field),
        }
        for index, row in enumerate(eligible[:limit], start=1)
    ]


def _game_highs(logs: list[dict[str, Any]]) -> dict[str, Any]:
    fields = ("points", "rebounds", "assists", "steals", "blocks")
    output: dict[str, dict[str, Any]] = {}
    for row in logs:
        player_id = str(row.get("player_id") or "")
        if not player_id:
            continue
        item = output.setdefault(player_id, {"player_id": player_id, "player_name": row.get("player_name")})
        for field in fields:
            value = row.get(field)
            if not isinstance(value, (int, float)):
                continue
            key = f"max_{field}"
            if key not in item or float(value) > float(item[key]):
                item[key] = value
                item[f"{field}_game_id"] = row.get("game_id")
                item[f"{field}_game_date"] = row.get("game_date")
    return output


@router.get("/seed/{season}")
def historical_seed_snapshot(
    season: str,
    league: str = "NBA",
    season_type: str = "regular",
    include_game_logs: bool = True,
    player_log_limit: int = Query(default=50000, ge=0, le=100000),
) -> dict[str, Any]:
    """Project a canonical historical season into the original terminal-seed contract.

    This endpoint is intentionally compatibility-oriented. Existing product surfaces that
    were built around the original 2024-25 JSON seed can consume historical seasons without
    carrying a second analytics model in the browser. The canonical warehouse remains the
    authoritative source and every projected snapshot identifies itself as historical.
    """
    season_type = _season_type(season_type)
    league = league.upper().strip() or "NBA"

    with _connect() as db:
        season_exists = db.execute(
            "SELECT 1 FROM canon_dim_season WHERE season_id=?",
            (season,),
        ).fetchone()
        if season_exists is None:
            raise HTTPException(status_code=404, detail="Historical season not found")

        player_sql = """
          SELECT ps.*,p.canonical_name AS player_name,p.primary_position,p.nba_id,p.bref_id,
                 t.canonical_name AS team_name
          FROM canon_fact_player_season ps
          JOIN canon_dim_player p ON p.player_key=ps.player_key
          LEFT JOIN canon_dim_team t ON t.team_key=ps.team_key
          WHERE ps.season_id=? AND ps.league_id=?
        """
        player_params: list[Any] = [season, league]
        if season_type != "combined":
            player_sql += " AND ps.season_type=?"
            player_params.append(season_type)
        player_source_rows = _rows(db.execute(player_sql, player_params).fetchall())
        collapsed = _collapse_player_season_rows(
            player_source_rows,
            team_filtered=False,
            combine_segments=season_type == "combined",
        )
        player_totals = [_player_seed_row(row) for row in collapsed]
        players = [_player_profile(row) for row in collapsed]

        team_sql = """
          SELECT ts.*,t.canonical_name AS canonical_team_name,t.franchise_key
          FROM canon_fact_team_season ts
          LEFT JOIN canon_dim_team t ON t.team_key=ts.team_key
          WHERE ts.season_id=? AND ts.league_id=?
        """
        team_params: list[Any] = [season, league]
        if season_type != "combined":
            team_sql += " AND ts.season_type=?"
            team_params.append(season_type)
        team_source_rows = _rows(db.execute(team_sql, team_params).fetchall())
        team_records = [_team_record(row) for row in team_source_rows]

        game_sql = """
          SELECT g.*,ht.canonical_name AS home_team_name,ht.abbreviation AS home_team_abbreviation,
                 at.canonical_name AS away_team_name,at.abbreviation AS away_team_abbreviation
          FROM canon_dim_game g
          LEFT JOIN canon_dim_team ht ON ht.team_key=g.home_team_key
          LEFT JOIN canon_dim_team at ON at.team_key=g.away_team_key
          WHERE g.season_id=? AND g.league_id=?
        """
        game_params: list[Any] = [season, league]
        if season_type != "combined":
            game_sql += " AND g.season_type=?"
            game_params.append(season_type)
        game_sql += " ORDER BY g.game_date,g.game_key"
        game_source_rows = _rows(db.execute(game_sql, game_params).fetchall())
        games = [_game_row(row) for row in game_source_rows]
        game_keys = [str(row.get("game_key") or "") for row in game_source_rows if row.get("game_key")]

        team_game_logs: list[dict[str, Any]] = []
        player_game_logs: list[dict[str, Any]] = []
        if game_keys:
            placeholders = ",".join("?" for _ in game_keys)
            team_game_sql = f"""
              SELECT tg.*,g.game_date,t.abbreviation AS team_abbreviation,t.canonical_name AS team_name,
                     ot.abbreviation AS opponent_abbreviation,ot.canonical_name AS opponent_name
              FROM canon_fact_team_game tg
              JOIN canon_dim_game g ON g.game_key=tg.game_key
              LEFT JOIN canon_dim_team t ON t.team_key=tg.team_key
              LEFT JOIN canon_dim_team ot ON ot.team_key=tg.opponent_team_key
              WHERE tg.game_key IN ({placeholders})
              ORDER BY g.game_date,t.abbreviation
            """
            team_game_logs = [_team_game_row(row) for row in _rows(db.execute(team_game_sql, game_keys).fetchall())]

            if include_game_logs and player_log_limit > 0:
                player_game_sql = f"""
                  SELECT pg.* FROM canon_fact_player_game pg
                  WHERE pg.game_key IN ({placeholders})
                  ORDER BY pg.game_date DESC,pg.source_row DESC
                  LIMIT ?
                """
                player_rows = _rows(db.execute(player_game_sql, [*game_keys, player_log_limit]).fetchall())
                player_game_logs = [_player_game_row(row) for row in player_rows]

        team_ids = {str(row.get("team_id") or "") for row in team_records if row.get("team_id")}
        if not team_ids:
            for row in game_source_rows:
                if row.get("home_team_key"):
                    team_ids.add(str(row["home_team_key"]))
                if row.get("away_team_key"):
                    team_ids.add(str(row["away_team_key"]))
        teams: list[dict[str, Any]] = []
        if team_ids:
            placeholders = ",".join("?" for _ in team_ids)
            team_dim_rows = _rows(
                db.execute(
                    f"""
                    SELECT t.*,f.canonical_name AS franchise_name
                    FROM canon_dim_team t
                    LEFT JOIN canon_dim_franchise f ON f.franchise_key=t.franchise_key
                    WHERE t.team_key IN ({placeholders})
                    ORDER BY t.canonical_name
                    """,
                    list(team_ids),
                ).fetchall()
            )
            teams = [
                {
                    "team_id": row.get("team_key"),
                    "id": row.get("team_key"),
                    "team_name": row.get("canonical_name"),
                    "abbreviation": row.get("abbreviation"),
                    "league": row.get("league_id"),
                    "franchise_id": row.get("franchise_key"),
                    "franchise_name": row.get("franchise_name"),
                    "nba_team_id": row.get("nba_team_id"),
                }
                for row in team_dim_rows
            ]

        manifest_row = db.execute(
            "SELECT * FROM canon_build_manifest ORDER BY built_at DESC LIMIT 1"
        ).fetchone()
        manifest = dict(manifest_row) if manifest_row else {}
        canonical_counts = _decode(manifest.pop("canonical_counts_json", "{}"), {}) if manifest else {}
        warnings = _decode(manifest.pop("warnings_json", "[]"), []) if manifest else []
        pbp_coverage = db.execute(
            "SELECT COALESCE(SUM(row_count),0) FROM canon_coverage WHERE domain='play_by_play' AND league_id=? AND season_id=?",
            (league, season),
        ).fetchone()
        play_by_play_events = int(pbp_coverage[0] or 0) if pbp_coverage else 0
        source_rows = int(
            db.execute("SELECT COALESCE(SUM(row_count),0) FROM historical_source_registry").fetchone()[0]
        )

    standings = sorted(
        team_records,
        key=lambda row: (float(row.get("wins") or 0), -float(row.get("losses") or 0)),
        reverse=True,
    )
    leaders = {
        "points": _leader_rows(player_totals, "points"),
        "rebounds": _leader_rows(player_totals, "rebounds"),
        "assists": _leader_rows(player_totals, "assists"),
        "steals": _leader_rows(player_totals, "steals"),
        "blocks": _leader_rows(player_totals, "blocks"),
        "bpm": _leader_rows(player_totals, "avg_bpm"),
        "win_shares": _leader_rows(player_totals, "win_shares"),
    }
    search_index = [
        {
            "type": "player",
            "id": row.get("player_id"),
            "label": row.get("player_name"),
            "team": row.get("team_abbreviation"),
        }
        for row in players
    ] + [
        {
            "type": "team",
            "id": row.get("team_id"),
            "label": row.get("team_name"),
            "team": row.get("abbreviation"),
        }
        for row in teams
    ]

    return {
        "manifest": {
            "generatedAt": manifest.get("built_at"),
            "source": "Sports Terminal canonical historical NBA warehouse",
            "season": season,
            "league": league,
            "seasonType": season_type,
            "warehouseBuild": {
                "generatedAt": manifest.get("built_at"),
                "playByPlayEventsNormalized": play_by_play_events,
                "canonicalCounts": canonical_counts,
                "sourceRows": source_rows,
            },
            "warnings": warnings,
        },
        "teams": teams,
        "players": players,
        "games": games,
        "team_records": team_records,
        "team_game_logs": team_game_logs,
        "player_season_totals": player_totals,
        "player_leaders": leaders,
        "player_game_highs": _game_highs(player_game_logs),
        "player_game_logs_top": player_game_logs,
        "search_index": search_index,
        "data_dictionary": {
            "source": "canonical historical warehouse",
            "season": season,
            "league": league,
            "season_type": season_type,
            "provenance": "Canonical facts preserve selected source, source count and field-level evidence in the historical warehouse.",
            "compatibility": "Field aliases mirror the original terminal seed contract so existing NBA analytics surfaces can consume history.",
        },
        "validation_report": {
            "status": "pass",
            "dataset": "historical-canonical",
            "canonical_ready": True,
            "warnings": warnings,
        },
        "asset_manifest": None,
        "release_manifest": {
            "status": "historical-canonical",
            "season": season,
            "league": league,
            "season_type": season_type,
            "build_id": manifest.get("build_id"),
            "schema_version": manifest.get("schema_version"),
        },
        "standings": standings,
        "launch_config": {
            "supportedSeason": season,
            "datasetStatus": "historical-canonical",
            "allowFallback": False,
        },
        "asset_path": f"backend://v2/nba/history/seed/{season}",
        "used_fallback": False,
        "compatibility": {
            "contract": "nba-terminal-seed-v1",
            "historical": True,
            "season": season,
            "league": league,
            "season_type": season_type,
            "player_rows": len(player_totals),
            "team_rows": len(team_records),
            "game_rows": len(games),
            "player_game_rows": len(player_game_logs),
        },
    }
