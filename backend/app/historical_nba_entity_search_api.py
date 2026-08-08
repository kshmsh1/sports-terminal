from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query

from .historical_nba_api import _connect, _decode, _rows

router = APIRouter(prefix="/v2/nba/history", tags=["nba-history-entity-search"])


def _needle(value: str) -> str:
    return f"%{value.strip().lower()}%"


def _decode_game_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    for row in rows:
        row["provenance"] = _decode(row.pop("provenance_json", "{}"), {})
    return rows


@router.get("/entities/search")
def historical_entity_search_fast(
    query: str,
    league: str = "",
    kinds: str = "player,team,franchise,season,game",
    limit_per_kind: int = Query(default=20, ge=1, le=100),
) -> dict[str, Any]:
    text = query.strip()
    if not text:
        return {"query": "", "league": league.upper(), "groups": {}, "count": 0}
    requested = {
        item.strip().lower()
        for item in kinds.split(",")
        if item.strip().lower() in {"player", "team", "franchise", "season", "game"}
    }
    if not requested:
        raise HTTPException(
            status_code=400,
            detail="kinds must include player, team, franchise, season, or game",
        )

    normalized_league = league.upper().strip()
    needle = _needle(text)
    groups: dict[str, list[dict[str, Any]]] = {}
    with _connect() as db:
        if "player" in requested:
            sql = """
                SELECT p.player_key,p.canonical_name,p.primary_position,p.active_from,p.active_to,
                       p.nba_id,p.bref_id,p.source_count,p.identity_confidence,
                       COUNT(DISTINCT ps.season_id) AS seasons,
                       MIN(ps.season_id) AS first_stat_season,
                       MAX(ps.season_id) AS last_stat_season
                FROM canon_dim_player p
                LEFT JOIN canon_fact_player_season ps ON ps.player_key=p.player_key
                WHERE (lower(p.canonical_name) LIKE ? OR lower(COALESCE(p.nba_id,'')) LIKE ?
                       OR lower(COALESCE(p.bref_id,'')) LIKE ?)
            """
            params: list[Any] = [needle, needle, needle]
            if normalized_league:
                sql += " AND (ps.league_id=? OR ps.league_id IS NULL)"
                params.append(normalized_league)
            sql += " GROUP BY p.player_key ORDER BY p.canonical_name LIMIT ?"
            params.append(limit_per_kind)
            groups["players"] = _rows(db.execute(sql, params).fetchall())

        if "team" in requested:
            sql = """
                SELECT t.team_key,t.franchise_key,t.canonical_name,t.abbreviation,t.league_id,
                       t.active_from,t.active_to,t.nba_team_id,t.source_count,
                       f.canonical_name AS franchise_name,f.current_abbreviation,
                       COUNT(DISTINCT ts.season_id) AS seasons
                FROM canon_dim_team t
                LEFT JOIN canon_dim_franchise f ON f.franchise_key=t.franchise_key
                LEFT JOIN canon_fact_team_season ts ON ts.team_key=t.team_key
                WHERE (lower(t.canonical_name) LIKE ? OR lower(COALESCE(t.abbreviation,'')) LIKE ?
                       OR lower(COALESCE(f.canonical_name,'')) LIKE ?)
            """
            params = [needle, needle, needle]
            if normalized_league:
                sql += " AND (t.league_id=? OR ts.league_id=?)"
                params.extend([normalized_league, normalized_league])
            sql += " GROUP BY t.team_key ORDER BY t.canonical_name LIMIT ?"
            params.append(limit_per_kind)
            groups["teams"] = _rows(db.execute(sql, params).fetchall())

        if "franchise" in requested:
            sql = """
                SELECT f.franchise_key,f.canonical_name,f.current_abbreviation,f.source_count,
                       COUNT(DISTINCT t.team_key) AS team_identities,
                       MIN(ts.season_id) AS first_season,MAX(ts.season_id) AS last_season,
                       COUNT(DISTINCT ts.season_id) AS seasons
                FROM canon_dim_franchise f
                LEFT JOIN canon_dim_team t ON t.franchise_key=f.franchise_key
                LEFT JOIN canon_fact_team_season ts ON ts.team_key=t.team_key
                WHERE (lower(f.canonical_name) LIKE ? OR lower(COALESCE(f.current_abbreviation,'')) LIKE ?
                       OR lower(COALESCE(t.canonical_name,'')) LIKE ?)
            """
            params = [needle, needle, needle]
            if normalized_league:
                sql += " AND (ts.league_id=? OR t.league_id=?)"
                params.extend([normalized_league, normalized_league])
            sql += " GROUP BY f.franchise_key ORDER BY f.canonical_name LIMIT ?"
            params.append(limit_per_kind)
            groups["franchises"] = _rows(db.execute(sql, params).fetchall())

        if "season" in requested:
            # Deliberately avoid joining player/team/game facts together. On a real
            # season that would multiply hundreds of players by teams by games.
            # Independent correlated counts keep this query bounded by season rows.
            sql = """
                SELECT s.season_id,s.start_year,s.end_year,s.label,
                       (SELECT COUNT(DISTINCT ts.team_key)
                          FROM canon_fact_team_season ts
                         WHERE ts.season_id=s.season_id
                           AND (?='' OR ts.league_id=?)) AS teams,
                       (SELECT COUNT(DISTINCT ps.player_key)
                          FROM canon_fact_player_season ps
                         WHERE ps.season_id=s.season_id
                           AND (?='' OR ps.league_id=?)) AS players,
                       (SELECT COUNT(DISTINCT g.game_key)
                          FROM canon_dim_game g
                         WHERE g.season_id=s.season_id
                           AND (?='' OR g.league_id=?)) AS games
                FROM canon_dim_season s
                WHERE (lower(s.season_id) LIKE ? OR lower(s.label) LIKE ?
                       OR CAST(s.start_year AS TEXT) LIKE ?)
                ORDER BY s.start_year DESC LIMIT ?
            """
            params = [
                normalized_league,
                normalized_league,
                normalized_league,
                normalized_league,
                normalized_league,
                normalized_league,
                needle,
                needle,
                needle,
                limit_per_kind,
            ]
            groups["seasons"] = _rows(db.execute(sql, params).fetchall())

        if "game" in requested:
            sql = """
                SELECT g.*,home.canonical_name AS home_team_name,
                       away.canonical_name AS away_team_name
                FROM canon_dim_game g
                LEFT JOIN canon_dim_team home ON home.team_key=g.home_team_key
                LEFT JOIN canon_dim_team away ON away.team_key=g.away_team_key
                WHERE (lower(g.game_key) LIKE ? OR lower(COALESCE(g.nba_game_id,'')) LIKE ?
                       OR lower(COALESCE(g.game_date,'')) LIKE ?
                       OR lower(COALESCE(home.canonical_name,'')) LIKE ?
                       OR lower(COALESCE(away.canonical_name,'')) LIKE ?)
            """
            params = [needle, needle, needle, needle, needle]
            if normalized_league:
                sql += " AND g.league_id=?"
                params.append(normalized_league)
            sql += " ORDER BY g.game_date DESC LIMIT ?"
            params.append(limit_per_kind)
            groups["games"] = _decode_game_rows(
                _rows(db.execute(sql, params).fetchall())
            )

    return {
        "query": text,
        "league": normalized_league,
        "groups": groups,
        "count": sum(len(items) for items in groups.values()),
        "search_strategy": "bounded-canonical-entity-search-v2",
    }
