from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Query

from .historical_nba_api import _connect, _decode, _rows

router = APIRouter(prefix="/v2/nba/terminal", tags=["nba-terminal"])

TERMINAL_SCHEMA_VERSION = "2.0"
TERMINAL_COMMAND_VERSION = "2026.08"

COMMAND_CATALOG: tuple[dict[str, Any], ...] = (
    {"id": "home", "label": "NBA Terminal", "aliases": ["home", "terminal", "dashboard"], "group": "Core"},
    {"id": "entities", "label": "Entity & Season Intelligence", "aliases": ["entity", "player", "team", "season", "game", "franchise"], "group": "NBA"},
    {"id": "universe", "label": "NBA Universe", "aliases": ["universe", "directory", "roster"], "group": "NBA"},
    {"id": "stats", "label": "Stats Workstation", "aliases": ["stats", "leaderboard", "rank", "percentile"], "group": "Research"},
    {"id": "analytics", "label": "Analytics Suite", "aliases": ["analytics", "compare", "lineup", "shot", "rating"], "group": "Research"},
    {"id": "history", "label": "Historical Intelligence", "aliases": ["history", "historical", "all-time", "era", "records"], "group": "Research"},
    {"id": "research", "label": "Research Command Center", "aliases": ["research", "workspace", "methodology", "coverage"], "group": "Research"},
    {"id": "trade", "label": "Trade Machine", "aliases": ["trade", "salary match", "apron"], "group": "Front Office"},
    {"id": "front-office", "label": "Front Office", "aliases": ["front office", "cap", "roster", "contracts", "assets"], "group": "Front Office"},
    {"id": "workbook", "label": "Workspace", "aliases": ["workspace", "spreadsheet", "workbook", "model"], "group": "Tools"},
    {"id": "python", "label": "Python Lab", "aliases": ["python", "code", "notebook"], "group": "Tools"},
    {"id": "transactions", "label": "Transaction Command Center", "aliases": ["transactions", "cases", "approvals", "workflow"], "group": "Operations"},
)


def _table_count(db, table: str) -> int:
    exists = db.execute(
        "SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name=?",
        (table,),
    ).fetchone()
    if exists is None:
        return 0
    return int(db.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0])


@router.get("/manifest")
def nba_terminal_manifest() -> dict[str, Any]:
    """Return the canonical warehouse capabilities visible to terminal clients.

    This endpoint deliberately describes installed canonical history rather than
    pretending that every era has every stat. Coverage rows remain authoritative.
    """
    with _connect() as db:
        manifest = db.execute(
            "SELECT * FROM canon_build_manifest ORDER BY built_at DESC LIMIT 1"
        ).fetchone()
        build = dict(manifest) if manifest else {}
        if build:
            build["canonical_counts"] = _decode(
                build.pop("canonical_counts_json", "{}"), {}
            )
            build["warnings"] = _decode(build.pop("warnings_json", "[]"), [])

        season_span = db.execute(
            "SELECT MIN(season_id),MAX(season_id),COUNT(*) FROM canon_dim_season"
        ).fetchone()
        leagues = _rows(
            db.execute(
                "SELECT league_id,league_name,first_season,last_season FROM canon_dim_league ORDER BY league_id"
            ).fetchall()
        )
        coverage = _rows(
            db.execute(
                """
                SELECT domain,league_id,MIN(season_id) AS first_season,
                       MAX(season_id) AS last_season,COUNT(DISTINCT season_id) AS seasons,
                       SUM(row_count) AS rows,MAX(source_count) AS max_sources
                FROM canon_coverage
                GROUP BY domain,league_id
                ORDER BY league_id,domain
                """
            ).fetchall()
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
        counts = {
            "players": _table_count(db, "canon_dim_player"),
            "teams": _table_count(db, "canon_dim_team"),
            "franchises": _table_count(db, "canon_dim_franchise"),
            "seasons": _table_count(db, "canon_dim_season"),
            "games": _table_count(db, "canon_dim_game"),
            "player_seasons": _table_count(db, "canon_fact_player_season"),
            "team_seasons": _table_count(db, "canon_fact_team_season"),
            "player_games": _table_count(db, "canon_fact_player_game"),
            "awards": _table_count(db, "canon_fact_award"),
            "all_star_selections": _table_count(db, "canon_fact_all_star"),
            "draft_rows": _table_count(db, "canon_fact_draft"),
            "field_provenance": _table_count(db, "canon_field_provenance"),
            "material_conflicts": _table_count(db, "canon_conflicts"),
        }
        return {
            "terminal_schema_version": TERMINAL_SCHEMA_VERSION,
            "command_catalog_version": TERMINAL_COMMAND_VERSION,
            "sport": "basketball",
            "primary_league": "NBA",
            "season_span": {
                "first": season_span[0] if season_span else None,
                "last": season_span[1] if season_span else None,
                "seasons": int(season_span[2] or 0) if season_span else 0,
            },
            "counts": counts,
            "leagues": leagues,
            "coverage": coverage,
            "sources": sources,
            "build": build,
            "commands": list(COMMAND_CATALOG),
            "integrity": {
                "canonical_only": True,
                "fabricates_missing_era_fields": False,
                "provenance_available": counts["field_provenance"] > 0,
                "conflicts_preserved": True,
            },
        }


@router.get("/seasons")
def nba_terminal_seasons(
    league: str = "NBA",
    query: str = "",
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=250),
) -> dict[str, Any]:
    league_id = league.strip().upper() or "NBA"
    needle = query.strip().lower()
    with _connect() as db:
        params: list[Any] = [league_id, league_id, league_id, league_id]
        where = ""
        if needle:
            where = "WHERE lower(s.season_id) LIKE ? OR lower(s.label) LIKE ?"
            like = f"%{needle}%"
            params = [league_id, league_id, league_id, league_id, like, like]
        sql = f"""
            SELECT s.season_id,s.start_year,s.end_year,s.label,
                   (SELECT COUNT(DISTINCT ts.team_key) FROM canon_fact_team_season ts
                    WHERE ts.season_id=s.season_id AND ts.league_id=?) AS teams,
                   (SELECT COUNT(DISTINCT ps.player_key) FROM canon_fact_player_season ps
                    WHERE ps.season_id=s.season_id AND ps.league_id=?) AS players,
                   (SELECT COUNT(*) FROM canon_dim_game g
                    WHERE g.season_id=s.season_id AND g.league_id=?) AS games,
                   (SELECT COUNT(*) FROM canon_fact_award a
                    WHERE a.season_id=s.season_id AND a.league_id=?) AS awards
            FROM canon_dim_season s
            {where}
            ORDER BY s.start_year DESC
        """
        all_rows = _rows(db.execute(sql, params).fetchall())
        page = all_rows[offset : offset + limit]
        return {
            "league": league_id,
            "query": query.strip(),
            "matched_rows": len(all_rows),
            "offset": offset,
            "limit": limit,
            "next_offset": offset + limit if offset + limit < len(all_rows) else None,
            "rows": page,
        }


@router.get("/commands")
def nba_terminal_commands(query: str = "") -> dict[str, Any]:
    needle = query.strip().lower()
    rows = list(COMMAND_CATALOG)
    if needle:
        rows = [
            row
            for row in rows
            if needle in row["label"].lower()
            or needle in row["group"].lower()
            or any(needle in alias for alias in row["aliases"])
        ]
    return {
        "version": TERMINAL_COMMAND_VERSION,
        "query": query.strip(),
        "rows": rows,
        "count": len(rows),
    }
