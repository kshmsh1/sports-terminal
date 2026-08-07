from __future__ import annotations

import json
import math
import os
import sqlite3
from collections import defaultdict
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException, Query

router = APIRouter(prefix="/v2/nba/history", tags=["nba-history"])
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_HISTORY_DB = REPOSITORY_ROOT / "data" / "warehouse" / "nba_history.sqlite"

PLAYER_METRICS = {
    "games", "games_started", "minutes", "fgm", "fga", "fg_pct", "three_pm", "three_pa", "three_pct",
    "two_pm", "two_pa", "two_pct", "ftm", "fta", "ft_pct", "orb", "drb", "reb", "ast", "stl", "blk",
    "tov", "pf", "pts", "per", "ts_pct", "efg_pct", "ws", "ws48", "obpm", "dbpm", "bpm", "vorp",
    "usg_pct", "ortg", "drtg",
}
COUNTING_METRICS = {
    "minutes", "fgm", "fga", "three_pm", "three_pa", "two_pm", "two_pa", "ftm", "fta", "orb", "drb",
    "reb", "ast", "stl", "blk", "tov", "pf", "pts",
}
PERCENT_METRICS = {"fg_pct", "three_pct", "two_pct", "ft_pct", "ts_pct", "efg_pct", "usg_pct"}
LOWER_IS_BETTER = {"tov", "drtg"}
_MULTI_TEAM_CODES = {"TOT", "MULTI"}


def _path() -> Path:
    configured = os.getenv("SPORTS_TERMINAL_NBA_HISTORY_DB")
    return Path(configured).expanduser().resolve() if configured else DEFAULT_HISTORY_DB


def _connect(*, require_canonical: bool = True) -> sqlite3.Connection:
    path = _path()
    if not path.exists():
        raise HTTPException(
            status_code=503,
            detail="Historical NBA warehouse is not installed. Run the historical source import first.",
        )
    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    if require_canonical:
        row = connection.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='canon_build_manifest'").fetchone()
        if row is None:
            connection.close()
            raise HTTPException(
                status_code=503,
                detail="Historical sources are installed but canonicalization has not been built. Run tools/build_historical_nba_canonical.py.",
            )
    return connection


def _rows(rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
    return [dict(row) for row in rows]


def _decode(value: str | None, fallback: Any) -> Any:
    if not value:
        return fallback
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return fallback


def _table_count(db: sqlite3.Connection, table: str) -> int:
    exists = db.execute("SELECT 1 FROM sqlite_master WHERE name=?", (table,)).fetchone()
    if exists is None:
        return 0
    return int(db.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0])


def _metric(metric: str) -> str:
    key = metric.strip().lower()
    if key not in PLAYER_METRICS:
        raise HTTPException(status_code=400, detail=f"Unknown metric '{metric}'.")
    return key


def _season_type(value: str) -> str:
    normalized = value.strip().lower()
    if normalized not in {"regular", "playoffs", "preseason", "all_star", "combined"}:
        raise HTTPException(status_code=400, detail="season_type must be regular, playoffs, preseason, all_star, or combined")
    return normalized


def _scaled(row: dict[str, Any], metric: str, basis: str) -> tuple[float | None, bool]:
    value = row.get(metric)
    if value is None:
        return None, False
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        return None, False
    if metric in PERCENT_METRICS or metric in {"per", "ws48", "obpm", "dbpm", "bpm", "vorp", "ortg", "drtg"}:
        return numeric, False
    if basis == "totals" or metric in {"games", "games_started"}:
        return numeric, False
    games = float(row.get("games") or 0)
    minutes = float(row.get("minutes") or 0)
    if basis == "per_game":
        return (numeric / games if games > 0 else None), False
    if basis == "per36":
        return (numeric * 36 / minutes if minutes > 0 else None), False
    if basis == "per48":
        return (numeric * 48 / minutes if minutes > 0 else None), False
    if basis in {"per75", "per100"}:
        fga = float(row.get("fga") or 0)
        fta = float(row.get("fta") or 0)
        orb = float(row.get("orb") or 0)
        tov = float(row.get("tov") or 0)
        possessions = max(0.0, fga + 0.44 * fta - orb + tov)
        if possessions <= 0 and minutes > 0:
            possessions = minutes * 2.05
        target = 75.0 if basis == "per75" else 100.0
        return (numeric * target / possessions if possessions > 0 else None), True
    raise HTTPException(status_code=400, detail="basis must be totals, per_game, per36, per48, per75, or per100")


def _season_clause(season_type: str) -> tuple[str, list[Any]]:
    if season_type == "combined":
        return "", []
    return " AND ps.season_type = ?", [season_type]


def _num(row: dict[str, Any], field: str) -> float | None:
    value = row.get(field)
    if value in (None, ""):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _is_multi_team_row(row: dict[str, Any]) -> bool:
    abbreviation = str(row.get("team_abbreviation") or "").strip().upper()
    return abbreviation in _MULTI_TEAM_CODES or (
        len(abbreviation) >= 3 and abbreviation.endswith("TM") and abbreviation[:-2].isdigit()
    )


def _weighted(rows: list[dict[str, Any]], field: str) -> float | None:
    weighted = 0.0
    weight_total = 0.0
    for row in rows:
        value = _num(row, field)
        if value is None:
            continue
        weight = _num(row, "minutes") or _num(row, "games") or 1.0
        if weight <= 0:
            continue
        weighted += value * weight
        weight_total += weight
    return weighted / weight_total if weight_total > 0 else None


def _ratio(numerator: float | None, denominator: float | None) -> float | None:
    if numerator is None or denominator is None or denominator <= 0:
        return None
    return numerator / denominator


def _aggregate_player_rows(rows: list[dict[str, Any]], *, label: str) -> dict[str, Any]:
    """Create one transparent season record when an upstream total row is absent.

    Counting values are additive; shooting percentages are rebuilt from makes/attempts;
    TS% and eFG% are rebuilt from canonical counting fields; non-additive advanced rates
    use a minutes-weighted average. The synthesized row is intentionally not given a
    canonical fact key so the UI cannot imply it has direct field-level source evidence.
    """
    if not rows:
        return {}
    base = dict(max(rows, key=lambda row: (_num(row, "minutes") or 0.0, _num(row, "games") or 0.0)))
    additive = set(COUNTING_METRICS) | {"games", "games_started", "ws", "vorp"}
    for field in additive:
        values = [_num(row, field) for row in rows]
        present = [value for value in values if value is not None]
        base[field] = sum(present) if present else None

    base["fg_pct"] = _ratio(_num(base, "fgm"), _num(base, "fga"))
    base["three_pct"] = _ratio(_num(base, "three_pm"), _num(base, "three_pa"))
    base["two_pct"] = _ratio(_num(base, "two_pm"), _num(base, "two_pa"))
    base["ft_pct"] = _ratio(_num(base, "ftm"), _num(base, "fta"))
    fga = _num(base, "fga")
    three_pm = _num(base, "three_pm")
    fgm = _num(base, "fgm")
    pts = _num(base, "pts")
    fta = _num(base, "fta")
    base["efg_pct"] = (
        (fgm + 0.5 * three_pm) / fga
        if fgm is not None and three_pm is not None and fga is not None and fga > 0
        else None
    )
    ts_denominator = 2 * (fga + 0.44 * fta) if fga is not None and fta is not None else None
    base["ts_pct"] = pts / ts_denominator if pts is not None and ts_denominator and ts_denominator > 0 else None
    minutes = _num(base, "minutes")
    ws = _num(base, "ws")
    base["ws48"] = ws * 48 / minutes if ws is not None and minutes is not None and minutes > 0 else None
    for field in {"per", "obpm", "dbpm", "bpm", "usg_pct", "ortg", "drtg"}:
        base[field] = _weighted(rows, field)

    base["fact_key"] = ""
    base["team_key"] = None
    base["team_abbreviation"] = label
    base["team_name"] = "Multiple teams" if label == "MULTI" else label
    base["primary_source"] = "synthesized_from_canonical_rows"
    base["source_count"] = max(int(row.get("source_count") or 1) for row in rows)
    base["synthetic_aggregate"] = True
    base["aggregate_components"] = [str(row.get("fact_key") or "") for row in rows if row.get("fact_key")]
    base["provenance_json"] = json.dumps({"aggregation": "derived_from_canonical_component_rows"})
    return base


def _collapse_player_season_rows(
    source_rows: list[dict[str, Any]],
    *,
    team_filtered: bool,
    combine_segments: bool,
) -> list[dict[str, Any]]:
    """Return at most one league-wide leaderboard row per player.

    Historical season tables commonly include a multi-team aggregate row plus individual
    team stints. League-wide leaderboards prefer that explicit total. If no total exists,
    Sports Terminal synthesizes one from the canonical stints. Team-filtered queries keep
    the requested stint. A combined segment then aggregates regular/playoff segment rows.
    """
    by_player_segment: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in source_rows:
        by_player_segment[(str(row.get("player_key") or ""), str(row.get("season_type") or "regular"))].append(row)

    collapsed_segments: list[dict[str, Any]] = []
    for group in by_player_segment.values():
        if team_filtered or len(group) == 1:
            collapsed_segments.extend(group)
            continue
        explicit_totals = [row for row in group if _is_multi_team_row(row)]
        if explicit_totals:
            collapsed_segments.append(
                max(
                    explicit_totals,
                    key=lambda row: (
                        _num(row, "games") or 0.0,
                        _num(row, "minutes") or 0.0,
                        int(row.get("source_count") or 0),
                    ),
                )
            )
        else:
            collapsed_segments.append(_aggregate_player_rows(group, label="MULTI"))

    if not combine_segments:
        return collapsed_segments

    by_player: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in collapsed_segments:
        by_player[str(row.get("player_key") or "")].append(row)
    combined: list[dict[str, Any]] = []
    for group in by_player.values():
        if len(group) == 1:
            item = dict(group[0])
            item["season_type"] = "combined"
            combined.append(item)
        else:
            item = _aggregate_player_rows(group, label="ALL")
            item["season_type"] = "combined"
            combined.append(item)
    return combined


@router.get("/status")
def history_status() -> dict[str, Any]:
    with _connect(require_canonical=False) as db:
        raw_sources = _table_count(db, "historical_source_registry")
        raw_tables = _table_count(db, "historical_table_inventory")
        raw_rows = 0
        if raw_sources:
            raw_rows = int(db.execute("SELECT COALESCE(SUM(row_count),0) FROM historical_source_registry").fetchone()[0])
        canonical = db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='canon_build_manifest'").fetchone() is not None
        manifest = None
        if canonical:
            row = db.execute("SELECT * FROM canon_build_manifest ORDER BY built_at DESC LIMIT 1").fetchone()
            if row:
                manifest = dict(row)
                manifest["canonical_counts"] = _decode(manifest.pop("canonical_counts_json", "{}"), {})
                manifest["warnings"] = _decode(manifest.pop("warnings_json", "[]"), [])
        return {
            "available": True,
            "canonical_ready": canonical,
            "database": str(_path()),
            "raw": {"sources": raw_sources, "tables": raw_tables, "rows": raw_rows},
            "canonical": manifest,
        }


@router.get("/metrics")
def history_metrics() -> dict[str, Any]:
    return {
        "metrics": sorted(PLAYER_METRICS),
        "counting_metrics": sorted(COUNTING_METRICS),
        "percent_metrics": sorted(PERCENT_METRICS),
        "lower_is_better": sorted(LOWER_IS_BETTER),
        "bases": ["totals", "per_game", "per36", "per48", "per75", "per100"],
        "per75_per100_note": "Possession-rate bases use the transparent FGA + 0.44*FTA - ORB + TOV estimate when direct possessions are unavailable.",
    }


@router.get("/coverage")
def history_coverage(
    domain: str = "",
    league: str = "",
    season: str = "",
) -> dict[str, Any]:
    sql = "SELECT domain, league_id, season_id, row_count, source_count, sources_json FROM canon_coverage WHERE 1=1"
    params: list[Any] = []
    if domain:
        sql += " AND domain = ?"
        params.append(domain)
    if league:
        sql += " AND league_id = ?"
        params.append(league.upper())
    if season:
        sql += " AND season_id = ?"
        params.append(season)
    sql += " ORDER BY season_id, domain, league_id"
    with _connect() as db:
        items = _rows(db.execute(sql, params).fetchall())
        for item in items:
            item["sources"] = _decode(item.pop("sources_json", "[]"), [])
        return {"rows": items, "count": len(items)}


@router.get("/seasons")
def history_seasons(
    league: str = "",
    domain: str = "player_season",
) -> dict[str, Any]:
    with _connect() as db:
        if league:
            rows = db.execute(
                """
                SELECT s.*, COALESCE(c.row_count,0) AS row_count, COALESCE(c.source_count,0) AS source_count
                FROM canon_dim_season s
                LEFT JOIN canon_coverage c ON c.season_id=s.season_id AND c.domain=? AND c.league_id=?
                WHERE COALESCE(c.row_count,0) > 0
                ORDER BY s.start_year
                """,
                (domain, league.upper()),
            ).fetchall()
        else:
            rows = db.execute(
                """
                SELECT s.*, COALESCE(SUM(c.row_count),0) AS row_count, COALESCE(MAX(c.source_count),0) AS source_count
                FROM canon_dim_season s
                LEFT JOIN canon_coverage c ON c.season_id=s.season_id AND c.domain=?
                GROUP BY s.season_id ORDER BY s.start_year
                """,
                (domain,),
            ).fetchall()
        return {"rows": _rows(rows), "count": len(rows)}


@router.get("/leagues")
def history_leagues() -> list[dict[str, Any]]:
    with _connect() as db:
        return _rows(db.execute("SELECT * FROM canon_dim_league ORDER BY first_season, league_id").fetchall())


@router.get("/players")
def history_players(
    query: str = "",
    season: str = "",
    league: str = "",
    team: str = "",
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=1000),
) -> dict[str, Any]:
    sql = """
        SELECT p.*, COUNT(DISTINCT ps.season_id) AS seasons,
               MIN(ps.season_id) AS first_stat_season, MAX(ps.season_id) AS last_stat_season
        FROM canon_dim_player p
        LEFT JOIN canon_fact_player_season ps ON ps.player_key=p.player_key
        WHERE 1=1
    """
    params: list[Any] = []
    if query:
        sql += " AND (lower(p.canonical_name) LIKE ? OR lower(COALESCE(p.nba_id,'')) LIKE ? OR lower(COALESCE(p.bref_id,'')) LIKE ?)"
        needle = f"%{query.lower()}%"
        params.extend([needle, needle, needle])
    if season:
        sql += " AND ps.season_id = ?"
        params.append(season)
    if league:
        sql += " AND ps.league_id = ?"
        params.append(league.upper())
    if team:
        sql += " AND ps.team_abbreviation = ?"
        params.append(team.upper())
    sql += " GROUP BY p.player_key ORDER BY p.canonical_name LIMIT ? OFFSET ?"
    params.extend([limit, offset])
    with _connect() as db:
        results = _rows(db.execute(sql, params).fetchall())
        return {"rows": results, "offset": offset, "limit": limit, "next_offset": offset + limit if len(results) == limit else None}


@router.get("/players/{player_key}")
def history_player(player_key: str) -> dict[str, Any]:
    with _connect() as db:
        row = db.execute("SELECT * FROM canon_dim_player WHERE player_key=?", (player_key,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Historical player not found")
        item = dict(row)
        item["provenance"] = _decode(item.pop("provenance_json", "{}"), {})
        item["identities"] = _rows(db.execute(
            "SELECT source_key, source_table, source_id, source_name, match_method, confidence, evidence_json FROM canon_player_source_xref WHERE player_key=? ORDER BY confidence DESC, source_key",
            (player_key,),
        ).fetchall())
        for identity in item["identities"]:
            identity["evidence"] = _decode(identity.pop("evidence_json", "{}"), {})
        item["awards"] = _rows(db.execute("SELECT season_id, league_id, award, rank_text, winner, share FROM canon_fact_award WHERE player_key=? ORDER BY season_id", (player_key,)).fetchall())
        item["all_star"] = _rows(db.execute("SELECT season_id, league_id, team_text FROM canon_fact_all_star WHERE player_key=? ORDER BY season_id", (player_key,)).fetchall())
        item["draft"] = _rows(db.execute("SELECT draft_year, league_id, round_text, pick_number, drafting_team_text FROM canon_fact_draft WHERE player_key=? ORDER BY draft_year", (player_key,)).fetchall())
        return item


@router.get("/players/{player_key}/career")
def history_player_career(
    player_key: str,
    league: str = "",
    season_type: str = "regular",
) -> dict[str, Any]:
    season_type = _season_type(season_type)
    sql = "SELECT ps.*, t.canonical_name AS team_name FROM canon_fact_player_season ps LEFT JOIN canon_dim_team t ON t.team_key=ps.team_key WHERE ps.player_key=?"
    params: list[Any] = [player_key]
    if league:
        sql += " AND ps.league_id=?"
        params.append(league.upper())
    clause, type_params = _season_clause(season_type)
    sql += clause + " ORDER BY ps.season_id, ps.team_abbreviation"
    params.extend(type_params)
    with _connect() as db:
        rows = _rows(db.execute(sql, params).fetchall())
        if not rows:
            player = db.execute("SELECT canonical_name FROM canon_dim_player WHERE player_key=?", (player_key,)).fetchone()
            if player is None:
                raise HTTPException(status_code=404, detail="Historical player not found")
        for row in rows:
            row["provenance"] = _decode(row.pop("provenance_json", "{}"), {})
        return {"player_key": player_key, "rows": rows, "season_count": len({row["season_id"] for row in rows})}


@router.get("/leaderboard")
def history_leaderboard(
    season: str,
    metric: str = "pts",
    basis: str = "per_game",
    league: str = "NBA",
    season_type: str = "regular",
    team: str = "",
    min_games: float = Query(default=0, ge=0),
    min_minutes: float = Query(default=0, ge=0),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=1000),
) -> dict[str, Any]:
    metric = _metric(metric)
    season_type = _season_type(season_type)
    basis = basis.strip().lower()
    if basis not in {"totals", "per_game", "per36", "per48", "per75", "per100"}:
        raise HTTPException(status_code=400, detail="Invalid basis")
    sql = """
      SELECT ps.*, p.canonical_name AS player_name, p.primary_position, p.nba_id, p.bref_id,
             t.canonical_name AS team_name
      FROM canon_fact_player_season ps
      JOIN canon_dim_player p ON p.player_key=ps.player_key
      LEFT JOIN canon_dim_team t ON t.team_key=ps.team_key
      WHERE ps.season_id=? AND ps.league_id=?
    """
    params: list[Any] = [season, league.upper()]
    clause, type_params = _season_clause(season_type)
    sql += clause
    params.extend(type_params)
    if team:
        sql += " AND ps.team_abbreviation=?"
        params.append(team.upper())
    with _connect() as db:
        source_rows = _rows(db.execute(sql, params).fetchall())

    source_rows = _collapse_player_season_rows(
        source_rows,
        team_filtered=bool(team),
        combine_segments=season_type == "combined",
    )
    source_rows = [
        row
        for row in source_rows
        if (_num(row, "games") or 0.0) >= min_games and (_num(row, "minutes") or 0.0) >= min_minutes
    ]

    projected: list[dict[str, Any]] = []
    for row in source_rows:
        scaled, estimated = _scaled(row, metric, basis)
        if scaled is None:
            continue
        item = dict(row)
        item["metric"] = metric
        item["basis"] = basis
        item["metric_value"] = scaled
        item["possessions_estimated"] = estimated
        item["provenance"] = _decode(item.pop("provenance_json", "{}"), {})
        projected.append(item)
    projected.sort(key=lambda item: float(item["metric_value"]), reverse=metric not in LOWER_IS_BETTER)
    page = projected[offset: offset + limit]
    for index, item in enumerate(page, start=offset + 1):
        item["rank"] = index
    return {
        "season": season, "league": league.upper(), "season_type": season_type, "metric": metric, "basis": basis,
        "matched_rows": len(projected), "offset": offset, "limit": limit,
        "next_offset": offset + limit if offset + limit < len(projected) else None, "rows": page,
    }


@router.get("/era-adjusted/{player_key}")
def era_adjusted_player(
    player_key: str,
    metric: str = "pts",
    basis: str = "per_game",
    league: str = "NBA",
    season_type: str = "regular",
    min_games: float = Query(default=10, ge=0),
) -> dict[str, Any]:
    metric = _metric(metric)
    season_type = _season_type(season_type)
    with _connect() as db:
        seasons = [str(row[0]) for row in db.execute(
            "SELECT DISTINCT season_id FROM canon_fact_player_season WHERE player_key=? AND league_id=? ORDER BY season_id",
            (player_key, league.upper()),
        ).fetchall()]
    output: list[dict[str, Any]] = []
    for season in seasons:
        board = history_leaderboard(season=season, metric=metric, basis=basis, league=league, season_type=season_type, min_games=min_games, min_minutes=0, offset=0, limit=1000)
        values = [float(row["metric_value"]) for row in board["rows"] if row.get("metric_value") is not None]
        target = next((row for row in board["rows"] if row["player_key"] == player_key), None)
        if target is None or not values:
            continue
        mean = sum(values) / len(values)
        variance = sum((value - mean) ** 2 for value in values) / len(values)
        std = math.sqrt(variance)
        value = float(target["metric_value"])
        z = (value - mean) / std if std > 0 else 0.0
        if metric in LOWER_IS_BETTER:
            z *= -1
        ordered = sorted(values, reverse=metric not in LOWER_IS_BETTER)
        rank = ordered.index(value) + 1 if value in ordered else None
        percentile = 1.0 - ((rank - 1) / max(1, len(ordered) - 1)) if rank else None
        output.append({
            "season": season, "metric_value": value, "league_mean": mean, "league_stddev": std,
            "z_score": z, "percentile": percentile, "peer_count": len(values), "rank": rank,
        })
    return {"player_key": player_key, "metric": metric, "basis": basis, "league": league.upper(), "rows": output}


@router.get("/teams")
def history_teams(
    query: str = "",
    league: str = "",
    limit: int = Query(default=200, ge=1, le=1000),
) -> dict[str, Any]:
    sql = "SELECT t.*, f.canonical_name AS franchise_name FROM canon_dim_team t LEFT JOIN canon_dim_franchise f ON f.franchise_key=t.franchise_key WHERE 1=1"
    params: list[Any] = []
    if query:
        sql += " AND (lower(t.canonical_name) LIKE ? OR lower(COALESCE(t.abbreviation,'')) LIKE ?)"
        needle = f"%{query.lower()}%"
        params.extend([needle, needle])
    if league:
        sql += " AND t.league_id=?"
        params.append(league.upper())
    sql += " ORDER BY t.canonical_name LIMIT ?"
    params.append(limit)
    with _connect() as db:
        items = _rows(db.execute(sql, params).fetchall())
        for item in items:
            item["provenance"] = _decode(item.pop("provenance_json", "{}"), {})
        return {"rows": items, "count": len(items)}


@router.get("/teams/{team_key}/history")
def history_team_seasons(team_key: str) -> dict[str, Any]:
    with _connect() as db:
        team = db.execute("SELECT * FROM canon_dim_team WHERE team_key=?", (team_key,)).fetchone()
        if team is None:
            raise HTTPException(status_code=404, detail="Historical team not found")
        seasons = _rows(db.execute("SELECT * FROM canon_fact_team_season WHERE team_key=? ORDER BY season_id", (team_key,)).fetchall())
        return {"team": dict(team), "rows": seasons}


@router.get("/games")
def history_games(
    season: str = "",
    league: str = "NBA",
    season_type: str = "regular",
    team_key: str = "",
    date_from: str = "",
    date_to: str = "",
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=1000),
) -> dict[str, Any]:
    season_type = _season_type(season_type)
    sql = """
      SELECT g.*, ht.canonical_name AS home_team_name, ht.abbreviation AS home_team_abbreviation,
             at.canonical_name AS away_team_name, at.abbreviation AS away_team_abbreviation
      FROM canon_dim_game g
      LEFT JOIN canon_dim_team ht ON ht.team_key=g.home_team_key
      LEFT JOIN canon_dim_team at ON at.team_key=g.away_team_key
      WHERE g.league_id=?
    """
    params: list[Any] = [league.upper()]
    if season:
        sql += " AND g.season_id=?"
        params.append(season)
    if season_type != "combined":
        sql += " AND g.season_type=?"
        params.append(season_type)
    if team_key:
        sql += " AND (g.home_team_key=? OR g.away_team_key=?)"
        params.extend([team_key, team_key])
    if date_from:
        sql += " AND g.game_date>=?"
        params.append(date_from)
    if date_to:
        sql += " AND g.game_date<=?"
        params.append(date_to)
    sql += " ORDER BY g.game_date, g.game_key LIMIT ? OFFSET ?"
    params.extend([limit, offset])
    with _connect() as db:
        rows = _rows(db.execute(sql, params).fetchall())
        return {"rows": rows, "offset": offset, "limit": limit, "next_offset": offset + limit if len(rows) == limit else None}


@router.get("/games/{game_key}")
def history_game(game_key: str) -> dict[str, Any]:
    with _connect() as db:
        row = db.execute("SELECT * FROM canon_dim_game WHERE game_key=?", (game_key,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Historical game not found")
        item = dict(row)
        item["provenance"] = _decode(item.pop("provenance_json", "{}"), {})
        item["teams"] = _rows(db.execute("SELECT * FROM canon_fact_team_game WHERE game_key=? ORDER BY is_home DESC", (game_key,)).fetchall())
        item["players"] = _rows(db.execute("SELECT * FROM canon_fact_player_game WHERE game_key=? ORDER BY team_abbreviation, player_name", (game_key,)).fetchall())
        return item


@router.get("/games/{game_key}/play-by-play")
def history_game_play_by_play(
    game_key: str,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=500, ge=1, le=5000),
) -> dict[str, Any]:
    with _connect() as db:
        exists = db.execute("SELECT 1 FROM sqlite_master WHERE type='view' AND name='canon_fact_play_by_play'").fetchone()
        if exists is None:
            raise HTTPException(status_code=404, detail="Canonical play-by-play view is unavailable")
        matched = int(db.execute("SELECT COUNT(*) FROM canon_fact_play_by_play WHERE game_key=?", (game_key,)).fetchone()[0])
        rows = _rows(db.execute(
            "SELECT * FROM canon_fact_play_by_play WHERE game_key=? ORDER BY period, event_number LIMIT ? OFFSET ?",
            (game_key, limit, offset),
        ).fetchall())
        return {"game_key": game_key, "matched_rows": matched, "offset": offset, "limit": limit, "next_offset": offset + limit if offset + limit < matched else None, "rows": rows}


@router.get("/conflicts")
def history_conflicts(
    entity_type: str = "",
    entity_key: str = "",
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=1000),
) -> dict[str, Any]:
    sql = "SELECT * FROM canon_conflicts WHERE 1=1"
    params: list[Any] = []
    if entity_type:
        sql += " AND entity_type=?"
        params.append(entity_type)
    if entity_key:
        sql += " AND entity_key=?"
        params.append(entity_key)
    sql += " ORDER BY conflict_id DESC LIMIT ? OFFSET ?"
    params.extend([limit, offset])
    with _connect() as db:
        rows = _rows(db.execute(sql, params).fetchall())
        return {"rows": rows, "offset": offset, "limit": limit}


@router.get("/provenance/{entity_type}/{entity_key}")
def history_provenance(entity_type: str, entity_key: str) -> dict[str, Any]:
    with _connect() as db:
        evidence = _rows(db.execute(
            "SELECT * FROM canon_field_provenance WHERE entity_type=? AND entity_key=? ORDER BY field_name, selected DESC, source_key",
            (entity_type, entity_key),
        ).fetchall())
        conflicts = _rows(db.execute(
            "SELECT * FROM canon_conflicts WHERE entity_type=? AND entity_key=? ORDER BY field_name, conflict_id",
            (entity_type, entity_key),
        ).fetchall())
        return {"entity_type": entity_type, "entity_key": entity_key, "evidence": evidence, "conflicts": conflicts}
