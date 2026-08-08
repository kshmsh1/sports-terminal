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
    _scaled,
    _season_type,
)

router = APIRouter(prefix="/v2/nba/history", tags=["nba-history-entities"])


def _like(value: str) -> str:
    return f"%{value.strip().lower()}%"


def _season_sort(value: Any) -> int:
    try:
        return int(str(value or "")[:4])
    except (TypeError, ValueError):
        return 0


def _winner_pct(row: dict[str, Any]) -> float | None:
    wins = _num(row, "wins") or 0.0
    losses = _num(row, "losses") or 0.0
    games = wins + losses
    return wins / games if games > 0 else None


def _decode_provenance(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    for item in items:
        if "provenance_json" in item:
            item["provenance"] = _decode(item.pop("provenance_json", "{}"), {})
        if "payload_json" in item:
            item["payload"] = _decode(item.pop("payload_json", "{}"), {})
        if "evidence_json" in item:
            item["evidence"] = _decode(item.pop("evidence_json", "{}"), {})
    return items


def _player_season_rows(
    db,
    player_key: str,
    *,
    league: str = "",
    season_type: str = "combined",
) -> list[dict[str, Any]]:
    normalized_type = _season_type(season_type)
    sql = """
        SELECT ps.*,t.canonical_name AS team_name
        FROM canon_fact_player_season ps
        LEFT JOIN canon_dim_team t ON t.team_key=ps.team_key
        WHERE ps.player_key=?
    """
    params: list[Any] = [player_key]
    if league:
        sql += " AND ps.league_id=?"
        params.append(league.upper())
    if normalized_type != "combined":
        sql += " AND ps.season_type=?"
        params.append(normalized_type)
    sql += " ORDER BY ps.season_id,ps.season_type,ps.team_abbreviation"
    raw = _rows(db.execute(sql, params).fetchall())
    by_season: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in raw:
        by_season[(str(row.get("season_id") or ""), str(row.get("league_id") or ""))].append(row)
    output: list[dict[str, Any]] = []
    for key in sorted(by_season, key=lambda item: (_season_sort(item[0]), item[1])):
        output.extend(
            _collapse_player_season_rows(
                by_season[key],
                team_filtered=False,
                combine_segments=normalized_type == "combined",
            )
        )
    return _decode_provenance(output)


def _player_search(db, query: str, league: str, limit: int) -> list[dict[str, Any]]:
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
    params: list[Any] = [_like(query), _like(query), _like(query)]
    if league:
        sql += " AND (ps.league_id=? OR ps.league_id IS NULL)"
        params.append(league.upper())
    sql += " GROUP BY p.player_key ORDER BY p.canonical_name LIMIT ?"
    params.append(limit)
    return _rows(db.execute(sql, params).fetchall())


def _team_search(db, query: str, league: str, limit: int) -> list[dict[str, Any]]:
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
    params: list[Any] = [_like(query), _like(query), _like(query)]
    if league:
        sql += " AND (t.league_id=? OR ts.league_id=?)"
        params.extend([league.upper(), league.upper()])
    sql += " GROUP BY t.team_key ORDER BY t.canonical_name LIMIT ?"
    params.append(limit)
    return _rows(db.execute(sql, params).fetchall())


def _franchise_search(db, query: str, league: str, limit: int) -> list[dict[str, Any]]:
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
    params: list[Any] = [_like(query), _like(query), _like(query)]
    if league:
        sql += " AND (ts.league_id=? OR t.league_id=?)"
        params.extend([league.upper(), league.upper()])
    sql += " GROUP BY f.franchise_key ORDER BY f.canonical_name LIMIT ?"
    params.append(limit)
    return _rows(db.execute(sql, params).fetchall())


def _season_search(db, query: str, league: str, limit: int) -> list[dict[str, Any]]:
    sql = """
        SELECT s.season_id,s.start_year,s.end_year,s.label,
               COUNT(DISTINCT ts.team_key) AS teams,
               COUNT(DISTINCT ps.player_key) AS players,
               COUNT(DISTINCT g.game_key) AS games
        FROM canon_dim_season s
        LEFT JOIN canon_fact_team_season ts ON ts.season_id=s.season_id
        LEFT JOIN canon_fact_player_season ps ON ps.season_id=s.season_id
        LEFT JOIN canon_dim_game g ON g.season_id=s.season_id
        WHERE (lower(s.season_id) LIKE ? OR lower(s.label) LIKE ? OR CAST(s.start_year AS TEXT) LIKE ?)
    """
    params: list[Any] = [_like(query), _like(query), _like(query)]
    if league:
        sql += " AND (ts.league_id=? OR ps.league_id=? OR g.league_id=?)"
        params.extend([league.upper(), league.upper(), league.upper()])
    sql += " GROUP BY s.season_id ORDER BY s.start_year DESC LIMIT ?"
    params.append(limit)
    return _rows(db.execute(sql, params).fetchall())


def _game_search(db, query: str, league: str, limit: int) -> list[dict[str, Any]]:
    sql = """
        SELECT g.*,home.canonical_name AS home_team_name,away.canonical_name AS away_team_name
        FROM canon_dim_game g
        LEFT JOIN canon_dim_team home ON home.team_key=g.home_team_key
        LEFT JOIN canon_dim_team away ON away.team_key=g.away_team_key
        WHERE (lower(g.game_key) LIKE ? OR lower(COALESCE(g.nba_game_id,'')) LIKE ?
               OR lower(COALESCE(g.game_date,'')) LIKE ? OR lower(COALESCE(home.canonical_name,'')) LIKE ?
               OR lower(COALESCE(away.canonical_name,'')) LIKE ?)
    """
    needle = _like(query)
    params: list[Any] = [needle, needle, needle, needle, needle]
    if league:
        sql += " AND g.league_id=?"
        params.append(league.upper())
    sql += " ORDER BY g.game_date DESC LIMIT ?"
    params.append(limit)
    return _decode_provenance(_rows(db.execute(sql, params).fetchall()))


@router.get("/entities/search")
def historical_entity_search(
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
        raise HTTPException(status_code=400, detail="kinds must include player, team, franchise, season, or game")
    with _connect() as db:
        groups: dict[str, list[dict[str, Any]]] = {}
        if "player" in requested:
            groups["players"] = _player_search(db, text, league, limit_per_kind)
        if "team" in requested:
            groups["teams"] = _team_search(db, text, league, limit_per_kind)
        if "franchise" in requested:
            groups["franchises"] = _franchise_search(db, text, league, limit_per_kind)
        if "season" in requested:
            groups["seasons"] = _season_search(db, text, league, limit_per_kind)
        if "game" in requested:
            groups["games"] = _game_search(db, text, league, limit_per_kind)
        return {
            "query": text,
            "league": league.upper(),
            "groups": groups,
            "count": sum(len(rows) for rows in groups.values()),
        }


@router.get("/players/{player_key}/dossier")
def historical_player_dossier(
    player_key: str,
    league: str = "",
    season_type: str = "combined",
    recent_games: int = Query(default=25, ge=0, le=250),
) -> dict[str, Any]:
    with _connect() as db:
        player = db.execute("SELECT * FROM canon_dim_player WHERE player_key=?", (player_key,)).fetchone()
        if player is None:
            raise HTTPException(status_code=404, detail="Historical player not found")
        profile = dict(player)
        profile["provenance"] = _decode(profile.pop("provenance_json", "{}"), {})
        identities = _decode_provenance(_rows(db.execute(
            """
            SELECT source_key,source_table,source_id,source_name,match_method,confidence,evidence_json
            FROM canon_player_source_xref WHERE player_key=?
            ORDER BY confidence DESC,source_key,source_table
            """,
            (player_key,),
        ).fetchall()))
        seasons = _player_season_rows(db, player_key, league=league, season_type=season_type)
        awards = _decode_provenance(_rows(db.execute(
            "SELECT * FROM canon_fact_award WHERE player_key=? ORDER BY season_id,award",
            (player_key,),
        ).fetchall()))
        all_star = _decode_provenance(_rows(db.execute(
            "SELECT * FROM canon_fact_all_star WHERE player_key=? ORDER BY season_id",
            (player_key,),
        ).fetchall()))
        draft = _decode_provenance(_rows(db.execute(
            "SELECT * FROM canon_fact_draft WHERE player_key=? ORDER BY draft_year",
            (player_key,),
        ).fetchall()))
        games: list[dict[str, Any]] = []
        if recent_games:
            games = _decode_provenance(_rows(db.execute(
                """
                SELECT pg.*,t.canonical_name AS team_name,ot.canonical_name AS opponent_name,
                       g.home_score,g.away_score,g.home_team_key,g.away_team_key
                FROM canon_fact_player_game pg
                LEFT JOIN canon_dim_team t ON t.team_key=pg.team_key
                LEFT JOIN canon_dim_team ot ON ot.team_key=pg.opponent_team_key
                LEFT JOIN canon_dim_game g ON g.game_key=pg.game_key
                WHERE pg.player_key=?
                ORDER BY pg.game_date DESC,pg.source_row DESC LIMIT ?
                """,
                (player_key, recent_games),
            ).fetchall()))
        conflicts = _rows(db.execute(
            "SELECT * FROM canon_conflicts WHERE entity_type='player' AND entity_key=? ORDER BY field_name,detected_at DESC",
            (player_key,),
        ).fetchall())
        provenance = _decode_provenance(_rows(db.execute(
            """
            SELECT entity_type,entity_key,field_name,source_key,source_table,source_row,source_value,selected,evidence_json
            FROM canon_field_provenance WHERE entity_type='player' AND entity_key=?
            ORDER BY field_name,selected DESC,source_key
            """,
            (player_key,),
        ).fetchall()))
        return {
            "kind": "player",
            "profile": profile,
            "identities": identities,
            "seasons": seasons,
            "awards": awards,
            "all_star": all_star,
            "draft": draft,
            "recent_games": games,
            "conflicts": conflicts,
            "field_provenance": provenance,
            "summary": {
                "season_rows": len(seasons),
                "first_season": min((row.get("season_id") for row in seasons if row.get("season_id")), default=None),
                "last_season": max((row.get("season_id") for row in seasons if row.get("season_id")), default=None),
                "awards": len(awards),
                "all_star_selections": len(all_star),
                "draft_rows": len(draft),
                "recent_games": len(games),
                "material_conflicts": len(conflicts),
            },
        }


@router.get("/teams/{team_key}/dossier")
def historical_team_dossier(
    team_key: str,
    league: str = "",
    season_type: str = "regular",
    recent_games: int = Query(default=25, ge=0, le=250),
) -> dict[str, Any]:
    normalized_type = _season_type(season_type)
    with _connect() as db:
        team = db.execute("SELECT * FROM canon_dim_team WHERE team_key=?", (team_key,)).fetchone()
        if team is None:
            raise HTTPException(status_code=404, detail="Historical team not found")
        profile = dict(team)
        profile["provenance"] = _decode(profile.pop("provenance_json", "{}"), {})
        franchise = None
        if profile.get("franchise_key"):
            row = db.execute(
                "SELECT * FROM canon_dim_franchise WHERE franchise_key=?",
                (profile["franchise_key"],),
            ).fetchone()
            franchise = dict(row) if row else None
        sql = "SELECT * FROM canon_fact_team_season WHERE team_key=?"
        params: list[Any] = [team_key]
        if league:
            sql += " AND league_id=?"
            params.append(league.upper())
        if normalized_type != "combined":
            sql += " AND season_type=?"
            params.append(normalized_type)
        sql += " ORDER BY season_id,season_type"
        seasons = _decode_provenance(_rows(db.execute(sql, params).fetchall()))
        for row in seasons:
            row["win_pct"] = _winner_pct(row)
        games: list[dict[str, Any]] = []
        if recent_games:
            games = _decode_provenance(_rows(db.execute(
                """
                SELECT g.*,home.canonical_name AS home_team_name,away.canonical_name AS away_team_name
                FROM canon_dim_game g
                LEFT JOIN canon_dim_team home ON home.team_key=g.home_team_key
                LEFT JOIN canon_dim_team away ON away.team_key=g.away_team_key
                WHERE g.home_team_key=? OR g.away_team_key=?
                ORDER BY g.game_date DESC LIMIT ?
                """,
                (team_key, team_key, recent_games),
            ).fetchall()))
        player_rows = _rows(db.execute(
            """
            SELECT ps.player_key,p.canonical_name AS player_name,COUNT(DISTINCT ps.season_id) AS seasons,
                   SUM(COALESCE(ps.games,0)) AS games,SUM(COALESCE(ps.pts,0)) AS pts,
                   SUM(COALESCE(ps.reb,0)) AS reb,SUM(COALESCE(ps.ast,0)) AS ast,
                   MIN(ps.season_id) AS first_season,MAX(ps.season_id) AS last_season
            FROM canon_fact_player_season ps
            JOIN canon_dim_player p ON p.player_key=ps.player_key
            WHERE ps.team_key=? AND ps.season_type='regular'
            GROUP BY ps.player_key ORDER BY games DESC,pts DESC LIMIT 50
            """,
            (team_key,),
        ).fetchall())
        conflicts = _rows(db.execute(
            "SELECT * FROM canon_conflicts WHERE entity_type='team' AND entity_key=? ORDER BY field_name,detected_at DESC",
            (team_key,),
        ).fetchall())
        return {
            "kind": "team",
            "profile": profile,
            "franchise": franchise,
            "seasons": seasons,
            "recent_games": games,
            "notable_players": player_rows,
            "conflicts": conflicts,
            "summary": {
                "seasons": len({str(row.get('season_id') or '') for row in seasons}),
                "first_season": min((row.get("season_id") for row in seasons if row.get("season_id")), default=None),
                "last_season": max((row.get("season_id") for row in seasons if row.get("season_id")), default=None),
                "recent_games": len(games),
                "material_conflicts": len(conflicts),
            },
        }


@router.get("/seasons/{season_id}/command")
def historical_season_command(
    season_id: str,
    league: str = "NBA",
    season_type: str = "regular",
    leader_limit: int = Query(default=10, ge=1, le=50),
) -> dict[str, Any]:
    normalized_type = _season_type(season_type)
    normalized_league = league.upper()
    with _connect() as db:
        season = db.execute("SELECT * FROM canon_dim_season WHERE season_id=?", (season_id,)).fetchone()
        if season is None:
            raise HTTPException(status_code=404, detail="Historical season not found")
        team_sql = """
            SELECT ts.*,t.canonical_name AS canonical_team_name,t.franchise_key,
                   f.canonical_name AS franchise_name
            FROM canon_fact_team_season ts
            LEFT JOIN canon_dim_team t ON t.team_key=ts.team_key
            LEFT JOIN canon_dim_franchise f ON f.franchise_key=t.franchise_key
            WHERE ts.season_id=? AND ts.league_id=?
        """
        team_params: list[Any] = [season_id, normalized_league]
        if normalized_type != "combined":
            team_sql += " AND ts.season_type=?"
            team_params.append(normalized_type)
        teams = _decode_provenance(_rows(db.execute(team_sql, team_params).fetchall()))
        for row in teams:
            row["win_pct"] = _winner_pct(row)
        teams.sort(
            key=lambda row: (
                float(row.get("win_pct") or -1),
                float(row.get("wins") or -1),
                float(row.get("srs") or -999),
            ),
            reverse=True,
        )
        for index, row in enumerate(teams, start=1):
            row["rank"] = index
        player_sql = """
            SELECT ps.*,p.canonical_name AS player_name,p.primary_position,t.canonical_name AS team_name
            FROM canon_fact_player_season ps
            JOIN canon_dim_player p ON p.player_key=ps.player_key
            LEFT JOIN canon_dim_team t ON t.team_key=ps.team_key
            WHERE ps.season_id=? AND ps.league_id=?
        """
        player_params: list[Any] = [season_id, normalized_league]
        if normalized_type != "combined":
            player_sql += " AND ps.season_type=?"
            player_params.append(normalized_type)
        raw_players = _rows(db.execute(player_sql, player_params).fetchall())
        players = _collapse_player_season_rows(
            raw_players,
            team_filtered=False,
            combine_segments=normalized_type == "combined",
        )
        leaders: dict[str, list[dict[str, Any]]] = {}
        for metric, basis in (
            ("pts", "per_game"),
            ("reb", "per_game"),
            ("ast", "per_game"),
            ("stl", "per_game"),
            ("blk", "per_game"),
            ("ws", "totals"),
            ("bpm", "totals"),
        ):
            ranked: list[dict[str, Any]] = []
            for row in players:
                value, estimated = _scaled(row, metric, basis)
                if value is None:
                    continue
                ranked.append({
                    "player_key": row.get("player_key"),
                    "player_name": row.get("player_name"),
                    "team_key": row.get("team_key"),
                    "team_abbreviation": row.get("team_abbreviation"),
                    "games": row.get("games"),
                    "value": value,
                    "basis": basis,
                    "estimated_possessions": estimated,
                })
            ranked.sort(key=lambda item: float(item.get("value") or -999), reverse=True)
            leaders[metric] = [
                {**item, "rank": index}
                for index, item in enumerate(ranked[:leader_limit], start=1)
            ]
        awards = _decode_provenance(_rows(db.execute(
            """
            SELECT * FROM canon_fact_award
            WHERE season_id=? AND (league_id=? OR league_id IS NULL OR league_id='')
            ORDER BY winner DESC,award,rank_text
            """,
            (season_id, normalized_league),
        ).fetchall()))
        all_star = _decode_provenance(_rows(db.execute(
            """
            SELECT * FROM canon_fact_all_star
            WHERE season_id=? AND (league_id=? OR league_id IS NULL OR league_id='')
            ORDER BY player_name
            """,
            (season_id, normalized_league),
        ).fetchall()))
        draft_year = int(str(season_id)[:4]) + 1 if str(season_id)[:4].isdigit() else None
        draft: list[dict[str, Any]] = []
        if draft_year is not None:
            draft = _decode_provenance(_rows(db.execute(
                """
                SELECT * FROM canon_fact_draft
                WHERE draft_year=? AND (league_id=? OR league_id IS NULL OR league_id='')
                ORDER BY pick_number,round_text,player_name
                """,
                (draft_year, normalized_league),
            ).fetchall()))
        coverage = _decode_provenance(_rows(db.execute(
            """
            SELECT * FROM canon_coverage WHERE season_id=? AND league_id=?
            ORDER BY domain
            """,
            (season_id, normalized_league),
        ).fetchall()))
        game_count = int(db.execute(
            "SELECT COUNT(*) FROM canon_dim_game WHERE season_id=? AND league_id=?" +
            ("" if normalized_type == "combined" else " AND season_type=?"),
            [season_id, normalized_league] + ([] if normalized_type == "combined" else [normalized_type]),
        ).fetchone()[0])
        return {
            "kind": "season",
            "season": dict(season),
            "league": normalized_league,
            "season_type": normalized_type,
            "teams": teams,
            "leaders": leaders,
            "awards": awards,
            "all_star": all_star,
            "draft": draft,
            "coverage": coverage,
            "summary": {
                "teams": len(teams),
                "players": len({str(row.get('player_key') or '') for row in players}),
                "games": game_count,
                "award_rows": len(awards),
                "all_star_rows": len(all_star),
                "draft_rows": len(draft),
                "coverage_domains": len(coverage),
            },
        }


@router.get("/franchises/{franchise_key}/dossier")
def historical_franchise_dossier(
    franchise_key: str,
    league: str = "",
) -> dict[str, Any]:
    with _connect() as db:
        franchise = db.execute(
            "SELECT * FROM canon_dim_franchise WHERE franchise_key=?",
            (franchise_key,),
        ).fetchone()
        if franchise is None:
            raise HTTPException(status_code=404, detail="Historical franchise not found")
        team_sql = "SELECT * FROM canon_dim_team WHERE franchise_key=?"
        team_params: list[Any] = [franchise_key]
        if league:
            team_sql += " AND league_id=?"
            team_params.append(league.upper())
        team_sql += " ORDER BY active_from,canonical_name"
        identities = _decode_provenance(_rows(db.execute(team_sql, team_params).fetchall()))
        keys = [row.get("team_key") for row in identities if row.get("team_key")]
        seasons: list[dict[str, Any]] = []
        if keys:
            placeholders = ",".join("?" for _ in keys)
            sql = f"""
                SELECT ts.*,t.canonical_name AS canonical_team_name,t.abbreviation
                FROM canon_fact_team_season ts
                JOIN canon_dim_team t ON t.team_key=ts.team_key
                WHERE ts.team_key IN ({placeholders})
            """
            params: list[Any] = list(keys)
            if league:
                sql += " AND ts.league_id=?"
                params.append(league.upper())
            sql += " ORDER BY ts.season_id,ts.season_type,t.canonical_name"
            seasons = _decode_provenance(_rows(db.execute(sql, params).fetchall()))
            for row in seasons:
                row["win_pct"] = _winner_pct(row)
        return {
            "kind": "franchise",
            "profile": dict(franchise),
            "team_identities": identities,
            "seasons": seasons,
            "summary": {
                "team_identities": len(identities),
                "seasons": len({str(row.get('season_id') or '') for row in seasons}),
                "first_season": min((row.get("season_id") for row in seasons if row.get("season_id")), default=None),
                "last_season": max((row.get("season_id") for row in seasons if row.get("season_id")), default=None),
            },
        }
