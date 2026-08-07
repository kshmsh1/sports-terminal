from __future__ import annotations

import json
import math
from collections import defaultdict
from typing import Any

from fastapi import APIRouter, HTTPException, Query

from .historical_nba_api import (
    LOWER_IS_BETTER,
    PLAYER_METRICS,
    _aggregate_player_rows,
    _collapse_player_season_rows,
    _connect,
    _decode,
    _metric,
    _num,
    _rows,
    _scaled,
    _season_type,
    era_adjusted_player,
)

router = APIRouter(prefix="/v2/nba/history", tags=["nba-history-research"])


def _season_sort(value: str) -> int:
    try:
        return int(value[:4])
    except (TypeError, ValueError):
        return 0


def _player_season_rows(
    *,
    player_key: str = "",
    league: str = "NBA",
    season_type: str = "regular",
    season_from: str = "",
    season_to: str = "",
) -> list[dict[str, Any]]:
    season_type = _season_type(season_type)
    sql = """
      SELECT ps.*, p.canonical_name AS player_name, p.primary_position, p.nba_id, p.bref_id,
             t.canonical_name AS team_name
      FROM canon_fact_player_season ps
      JOIN canon_dim_player p ON p.player_key=ps.player_key
      LEFT JOIN canon_dim_team t ON t.team_key=ps.team_key
      WHERE ps.league_id=?
    """
    params: list[Any] = [league.upper()]
    if player_key:
        sql += " AND ps.player_key=?"
        params.append(player_key)
    if season_type != "combined":
        sql += " AND ps.season_type=?"
        params.append(season_type)
    if season_from:
        sql += " AND ps.season_id>=?"
        params.append(season_from)
    if season_to:
        sql += " AND ps.season_id<=?"
        params.append(season_to)
    sql += " ORDER BY ps.season_id, p.canonical_name, ps.team_abbreviation"
    with _connect() as db:
        return _rows(db.execute(sql, params).fetchall())


def _collapse_across_seasons(
    source_rows: list[dict[str, Any]],
    *,
    combine_segments: bool,
) -> list[dict[str, Any]]:
    by_season: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in source_rows:
        by_season[str(row.get("season_id") or "")].append(row)
    collapsed: list[dict[str, Any]] = []
    for season in sorted(by_season, key=_season_sort):
        collapsed.extend(
            _collapse_player_season_rows(
                by_season[season],
                team_filtered=False,
                combine_segments=combine_segments,
            )
        )
    return collapsed


def _career_projection(
    season_rows: list[dict[str, Any]],
    *,
    metric: str,
    basis: str,
    mode: str,
    best_n: int,
) -> tuple[dict[str, Any] | None, float | None, dict[str, Any] | None]:
    if not season_rows:
        return None, None, None
    scored: list[tuple[dict[str, Any], float]] = []
    for row in season_rows:
        value, _ = _scaled(row, metric, basis)
        if value is not None:
            scored.append((row, float(value)))
    if not scored:
        return None, None, None
    reverse = metric not in LOWER_IS_BETTER
    scored.sort(key=lambda item: item[1], reverse=reverse)
    peak_row, peak_value = scored[0]

    if mode == "peak":
        return dict(peak_row), peak_value, dict(peak_row)
    if mode == "best_n":
        selected = [dict(item[0]) for item in scored[: max(1, best_n)]]
    else:
        selected = [dict(item[0]) for item in scored]
    aggregate = _aggregate_player_rows(
        selected,
        label="CAREER" if mode == "career" else f"BEST{max(1, best_n)}",
    )
    value, _ = _scaled(aggregate, metric, basis)
    return aggregate, value, dict(peak_row)


@router.get("/research/summary")
def historical_research_summary() -> dict[str, Any]:
    with _connect() as db:
        manifest = db.execute(
            "SELECT * FROM canon_build_manifest ORDER BY built_at DESC LIMIT 1"
        ).fetchone()
        manifest_payload = dict(manifest) if manifest else {}
        if manifest_payload:
            manifest_payload["canonical_counts"] = _decode(
                manifest_payload.pop("canonical_counts_json", "{}"), {}
            )
            manifest_payload["warnings"] = _decode(
                manifest_payload.pop("warnings_json", "[]"), []
            )
        sources = _rows(
            db.execute(
                """
                SELECT source_key,label,license,coverage,file_count,table_count,row_count,priority
                FROM historical_source_registry
                ORDER BY priority,source_key
                """
            ).fetchall()
        )
        coverage = _rows(
            db.execute(
                """
                SELECT domain,league_id,MIN(season_id) AS first_season,MAX(season_id) AS last_season,
                       COUNT(DISTINCT season_id) AS seasons,SUM(row_count) AS rows,MAX(source_count) AS max_sources
                FROM canon_coverage
                GROUP BY domain,league_id
                ORDER BY domain,league_id
                """
            ).fetchall()
        )
        conflicts = _rows(
            db.execute(
                """
                SELECT entity_type,field_name,COUNT(*) AS conflicts
                FROM canon_conflicts
                GROUP BY entity_type,field_name
                ORDER BY conflicts DESC,entity_type,field_name
                LIMIT 100
                """
            ).fetchall()
        )
        counts = {
            "field_provenance": int(db.execute("SELECT COUNT(*) FROM canon_field_provenance").fetchone()[0]),
            "material_conflicts": int(db.execute("SELECT COUNT(*) FROM canon_conflicts").fetchone()[0]),
            "players": int(db.execute("SELECT COUNT(*) FROM canon_dim_player").fetchone()[0]),
            "teams": int(db.execute("SELECT COUNT(*) FROM canon_dim_team").fetchone()[0]),
            "franchises": int(db.execute("SELECT COUNT(*) FROM canon_dim_franchise").fetchone()[0]),
            "games": int(db.execute("SELECT COUNT(*) FROM canon_dim_game").fetchone()[0]),
            "player_games": int(db.execute("SELECT COUNT(*) FROM canon_fact_player_game").fetchone()[0]),
        }
        return {
            "manifest": manifest_payload,
            "counts": counts,
            "sources": sources,
            "coverage": coverage,
            "top_conflict_fields": conflicts,
        }


@router.get("/players/{player_key}/games")
def historical_player_games(
    player_key: str,
    season: str = "",
    season_type: str = "combined",
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=1000),
) -> dict[str, Any]:
    season_type = _season_type(season_type)
    sql = """
      SELECT pg.*, t.canonical_name AS team_name, ot.canonical_name AS opponent_name,
             g.home_score,g.away_score,g.home_team_key,g.away_team_key
      FROM canon_fact_player_game pg
      LEFT JOIN canon_dim_team t ON t.team_key=pg.team_key
      LEFT JOIN canon_dim_team ot ON ot.team_key=pg.opponent_team_key
      LEFT JOIN canon_dim_game g ON g.game_key=pg.game_key
      WHERE pg.player_key=?
    """
    params: list[Any] = [player_key]
    if season:
        sql += " AND pg.season_id=?"
        params.append(season)
    if season_type != "combined":
        sql += " AND pg.season_type=?"
        params.append(season_type)
    count_sql = f"SELECT COUNT(*) FROM ({sql})"
    sql += " ORDER BY pg.game_date DESC,pg.source_row DESC LIMIT ? OFFSET ?"
    with _connect() as db:
        player = db.execute(
            "SELECT canonical_name FROM canon_dim_player WHERE player_key=?", (player_key,)
        ).fetchone()
        if player is None:
            raise HTTPException(status_code=404, detail="Historical player not found")
        total = int(db.execute(count_sql, params).fetchone()[0])
        rows = _rows(db.execute(sql, [*params, limit, offset]).fetchall())
        for row in rows:
            row["provenance"] = _decode(row.pop("provenance_json", "{}"), {})
        return {
            "player_key": player_key,
            "player_name": player[0],
            "matched_rows": total,
            "offset": offset,
            "limit": limit,
            "next_offset": offset + limit if offset + limit < total else None,
            "rows": rows,
        }


@router.get("/all-time")
def historical_all_time(
    metric: str = "pts",
    basis: str = "totals",
    mode: str = "career",
    best_n: int = Query(default=5, ge=1, le=20),
    league: str = "NBA",
    season_type: str = "regular",
    season_from: str = "",
    season_to: str = "",
    min_seasons: int = Query(default=1, ge=1),
    min_games: float = Query(default=0, ge=0),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=1000),
) -> dict[str, Any]:
    metric = _metric(metric)
    season_type = _season_type(season_type)
    mode = mode.strip().lower()
    if mode not in {"career", "peak", "best_n"}:
        raise HTTPException(status_code=400, detail="mode must be career, peak, or best_n")
    if basis not in {"totals", "per_game", "per36", "per48", "per75", "per100"}:
        raise HTTPException(status_code=400, detail="Invalid basis")
    raw = _player_season_rows(
        league=league,
        season_type=season_type,
        season_from=season_from,
        season_to=season_to,
    )
    collapsed = _collapse_across_seasons(
        raw,
        combine_segments=season_type == "combined",
    )
    by_player: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in collapsed:
        by_player[str(row.get("player_key") or "")].append(row)
    results: list[dict[str, Any]] = []
    for player_key, player_rows in by_player.items():
        season_count = len({str(row.get("season_id") or "") for row in player_rows})
        games = sum(_num(row, "games") or 0 for row in player_rows)
        if season_count < min_seasons or games < min_games:
            continue
        aggregate, value, peak = _career_projection(
            player_rows,
            metric=metric,
            basis=basis,
            mode=mode,
            best_n=best_n,
        )
        if value is None or aggregate is None or peak is None:
            continue
        seasons = sorted(
            {str(row.get("season_id") or "") for row in player_rows},
            key=_season_sort,
        )
        results.append(
            {
                "player_key": player_key,
                "player_name": aggregate.get("player_name") or peak.get("player_name"),
                "nba_id": aggregate.get("nba_id") or peak.get("nba_id"),
                "bref_id": aggregate.get("bref_id") or peak.get("bref_id"),
                "metric": metric,
                "basis": basis,
                "mode": mode,
                "metric_value": value,
                "career_games": games,
                "seasons": season_count,
                "first_season": seasons[0] if seasons else None,
                "last_season": seasons[-1] if seasons else None,
                "peak_season": peak.get("season_id"),
                "peak_team": peak.get("team_abbreviation"),
                "peak_metric_value": _scaled(peak, metric, basis)[0],
                "aggregate": {
                    field: aggregate.get(field)
                    for field in (
                        "games","minutes","pts","reb","ast","stl","blk","tov",
                        "fg_pct","three_pct","ft_pct","ts_pct","efg_pct","per","ws","ws48","bpm","vorp"
                    )
                },
            }
        )
    results.sort(
        key=lambda row: float(row["metric_value"]),
        reverse=metric not in LOWER_IS_BETTER,
    )
    page = results[offset : offset + limit]
    for rank, row in enumerate(page, start=offset + 1):
        row["rank"] = rank
    return {
        "metric": metric,
        "basis": basis,
        "mode": mode,
        "best_n": best_n if mode == "best_n" else None,
        "league": league.upper(),
        "season_type": season_type,
        "matched_rows": len(results),
        "offset": offset,
        "limit": limit,
        "next_offset": offset + limit if offset + limit < len(results) else None,
        "rows": page,
    }


@router.get("/compare")
def historical_compare(
    player_keys: str,
    metric: str = "pts",
    basis: str = "per_game",
    league: str = "NBA",
    season_type: str = "regular",
    min_games: float = Query(default=10, ge=0),
) -> dict[str, Any]:
    metric = _metric(metric)
    season_type = _season_type(season_type)
    keys = [key.strip() for key in player_keys.split(",") if key.strip()]
    keys = list(dict.fromkeys(keys))
    if not 2 <= len(keys) <= 6:
        raise HTTPException(status_code=400, detail="Compare requires 2 to 6 unique player keys")
    output: list[dict[str, Any]] = []
    with _connect() as db:
        identities = {
            str(row["player_key"]): dict(row)
            for row in db.execute(
                f"SELECT * FROM canon_dim_player WHERE player_key IN ({','.join('?' for _ in keys)})",
                keys,
            ).fetchall()
        }
    for player_key in keys:
        identity = identities.get(player_key)
        if identity is None:
            continue
        raw = _player_season_rows(
            player_key=player_key,
            league=league,
            season_type=season_type,
        )
        seasons = _collapse_across_seasons(
            raw,
            combine_segments=season_type == "combined",
        )
        seasons = [row for row in seasons if (_num(row, "games") or 0) >= min_games]
        aggregate, career_value, peak = _career_projection(
            seasons,
            metric=metric,
            basis=basis,
            mode="career",
            best_n=5,
        )
        era = era_adjusted_player(
            player_key=player_key,
            metric=metric,
            basis=basis,
            league=league,
            season_type=season_type,
            min_games=min_games,
        )
        era_rows = era.get("rows", [])
        peak_era = max(
            era_rows,
            key=lambda row: float(row.get("z_score") or -999),
            default=None,
        )
        output.append(
            {
                "identity": identity,
                "season_rows": seasons,
                "career_metric_value": career_value,
                "career_aggregate": aggregate,
                "peak_season": peak,
                "peak_era": peak_era,
            }
        )
    return {
        "metric": metric,
        "basis": basis,
        "league": league.upper(),
        "season_type": season_type,
        "players": output,
    }


@router.get("/franchises")
def historical_franchises(
    query: str = "",
    league: str = "",
    limit: int = Query(default=200, ge=1, le=1000),
) -> dict[str, Any]:
    sql = """
      SELECT f.franchise_key,f.canonical_name,f.current_abbreviation,f.source_count,
             COUNT(DISTINCT t.team_key) AS team_identities,
             GROUP_CONCAT(DISTINCT t.abbreviation) AS abbreviations,
             MIN(ts.season_id) AS first_season,MAX(ts.season_id) AS last_season,
             COUNT(DISTINCT ts.season_id) AS seasons
      FROM canon_dim_franchise f
      LEFT JOIN canon_dim_team t ON t.franchise_key=f.franchise_key
      LEFT JOIN canon_fact_team_season ts ON ts.team_key=t.team_key
      WHERE 1=1
    """
    params: list[Any] = []
    if query:
        sql += " AND lower(f.canonical_name) LIKE ?"
        params.append(f"%{query.lower()}%")
    if league:
        sql += " AND t.league_id=?"
        params.append(league.upper())
    sql += " GROUP BY f.franchise_key ORDER BY f.canonical_name LIMIT ?"
    params.append(limit)
    with _connect() as db:
        rows = _rows(db.execute(sql, params).fetchall())
        return {"rows": rows, "count": len(rows)}


@router.get("/franchises/{franchise_key}")
def historical_franchise(franchise_key: str) -> dict[str, Any]:
    with _connect() as db:
        franchise = db.execute(
            "SELECT * FROM canon_dim_franchise WHERE franchise_key=?", (franchise_key,)
        ).fetchone()
        if franchise is None:
            raise HTTPException(status_code=404, detail="Historical franchise not found")
        teams = _rows(
            db.execute(
                """
                SELECT * FROM canon_dim_team
                WHERE franchise_key=?
                ORDER BY active_from,canonical_name
                """,
                (franchise_key,),
            ).fetchall()
        )
        team_keys = [str(team["team_key"]) for team in teams]
        seasons: list[dict[str, Any]] = []
        if team_keys:
            seasons = _rows(
                db.execute(
                    f"""
                    SELECT ts.*,t.canonical_name AS team_identity_name
                    FROM canon_fact_team_season ts
                    LEFT JOIN canon_dim_team t ON t.team_key=ts.team_key
                    WHERE ts.team_key IN ({','.join('?' for _ in team_keys)})
                    ORDER BY ts.season_id,ts.team_abbreviation
                    """,
                    team_keys,
                ).fetchall()
            )
        return {
            "franchise": dict(franchise),
            "teams": teams,
            "seasons": seasons,
        }
