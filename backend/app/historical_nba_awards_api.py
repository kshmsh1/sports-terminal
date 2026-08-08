from __future__ import annotations

import json
import os
import re
import sqlite3
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException, Query

router = APIRouter(prefix="/v2/nba/awards", tags=["nba-awards"])
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_HISTORY_DB = REPOSITORY_ROOT / "data" / "warehouse" / "nba_history.sqlite"

AWARD_CATALOG: list[dict[str, Any]] = [
    {"id": "mvp", "label": "Most Valuable Player", "family": "Major Awards", "source_terms": ["award shares"], "match_terms": ["mvp", "most valuable"]},
    {"id": "roy", "label": "Rookie of the Year", "family": "Major Awards", "source_terms": ["award shares"], "match_terms": ["roy", "rookie"]},
    {"id": "dpoy", "label": "Defensive Player of the Year", "family": "Major Awards", "source_terms": ["award shares"], "match_terms": ["dpoy", "defensive player"]},
    {"id": "smoy", "label": "Sixth Man of the Year", "family": "Major Awards", "source_terms": ["award shares"], "match_terms": ["smoy", "sixth man"]},
    {"id": "mip", "label": "Most Improved Player", "family": "Major Awards", "source_terms": ["award shares"], "match_terms": ["mip", "most improved"]},
    {"id": "clutch", "label": "Clutch Player of the Year", "family": "Major Awards", "source_terms": ["award shares"], "match_terms": ["clutch"]},
    {"id": "finals_mvp", "label": "Finals MVP", "family": "Postseason", "source_terms": ["award shares", "end of season teams"], "match_terms": ["finals mvp", "finals"]},
    {"id": "ecf_mvp", "label": "Eastern Conference Finals MVP", "family": "Postseason", "source_terms": ["award shares"], "match_terms": ["eastern conference finals", "larry bird"]},
    {"id": "wcf_mvp", "label": "Western Conference Finals MVP", "family": "Postseason", "source_terms": ["award shares"], "match_terms": ["western conference finals", "magic johnson"]},
    {"id": "all_star_mvp", "label": "All-Star Game MVP", "family": "All-Star", "source_terms": ["all-star selections", "award shares"], "match_terms": ["all-star mvp", "all star mvp"]},
    {"id": "all_star", "label": "All-Star Selection", "family": "All-Star", "source_terms": ["all-star selections"], "match_terms": []},
    {"id": "all_nba_1", "label": "All-NBA First Team", "family": "All-League Teams", "source_terms": ["end of season teams", "end of season teams (voting)"], "match_terms": ["all-nba first", "1st team", "first team"]},
    {"id": "all_nba_2", "label": "All-NBA Second Team", "family": "All-League Teams", "source_terms": ["end of season teams", "end of season teams (voting)"], "match_terms": ["all-nba second", "2nd team", "second team"]},
    {"id": "all_nba_3", "label": "All-NBA Third Team", "family": "All-League Teams", "source_terms": ["end of season teams", "end of season teams (voting)"], "match_terms": ["all-nba third", "3rd team", "third team"]},
    {"id": "all_defense_1", "label": "All-Defensive First Team", "family": "All-League Teams", "source_terms": ["end of season teams", "end of season teams (voting)"], "match_terms": ["all-defensive first", "all-defense first", "defensive 1st"]},
    {"id": "all_defense_2", "label": "All-Defensive Second Team", "family": "All-League Teams", "source_terms": ["end of season teams", "end of season teams (voting)"], "match_terms": ["all-defensive second", "all-defense second", "defensive 2nd"]},
    {"id": "all_rookie_1", "label": "All-Rookie First Team", "family": "All-League Teams", "source_terms": ["end of season teams", "end of season teams (voting)"], "match_terms": ["all-rookie first", "rookie 1st"]},
    {"id": "all_rookie_2", "label": "All-Rookie Second Team", "family": "All-League Teams", "source_terms": ["end of season teams", "end of season teams (voting)"], "match_terms": ["all-rookie second", "rookie 2nd"]},
    {"id": "all_tournament", "label": "NBA Cup / In-Season Tournament Team", "family": "Tournament", "source_terms": ["end of season teams"], "match_terms": ["all-tournament", "in-season tournament", "nba cup"]},
    {"id": "ist_mvp", "label": "NBA Cup / In-Season Tournament MVP", "family": "Tournament", "source_terms": ["award shares"], "match_terms": ["in-season tournament mvp", "nba cup mvp"]},
    {"id": "sportsmanship", "label": "Sportsmanship Award", "family": "Special Awards", "source_terms": ["award shares"], "match_terms": ["sportsmanship"]},
    {"id": "social_justice", "label": "Kareem Abdul-Jabbar Social Justice Champion", "family": "Special Awards", "source_terms": ["award shares"], "match_terms": ["social justice", "kareem abdul-jabbar"]},
    {"id": "citizenship", "label": "J. Walter Kennedy Citizenship Award", "family": "Special Awards", "source_terms": ["award shares"], "match_terms": ["citizenship", "kennedy"]},
    {"id": "teammate", "label": "Twyman-Stokes Teammate of the Year", "family": "Special Awards", "source_terms": ["award shares"], "match_terms": ["teammate", "twyman-stokes"]},
    {"id": "hustle", "label": "Hustle Award", "family": "Special Awards", "source_terms": ["award shares"], "match_terms": ["hustle"]},
    {"id": "comeback", "label": "Comeback Player of the Year", "family": "Historical / Discontinued", "source_terms": ["award shares"], "match_terms": ["comeback"]},
    {"id": "coach", "label": "Coach of the Year", "family": "Team / Executive", "source_terms": ["award shares"], "match_terms": ["coach"]},
    {"id": "executive", "label": "Executive of the Year", "family": "Team / Executive", "source_terms": ["award shares"], "match_terms": ["executive"]},
]


def _path() -> Path:
    configured = os.getenv("SPORTS_TERMINAL_NBA_HISTORY_DB")
    return Path(configured).expanduser().resolve() if configured else DEFAULT_HISTORY_DB


def _connect() -> sqlite3.Connection:
    path = _path()
    if not path.exists():
        raise HTTPException(status_code=503, detail="Historical NBA warehouse is not installed")
    db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    db.row_factory = sqlite3.Row
    return db


def _safe_identifier(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def _source_tables(db: sqlite3.Connection) -> list[dict[str, Any]]:
    exists = db.execute("SELECT 1 FROM sqlite_master WHERE name='historical_table_inventory'").fetchone()
    if not exists:
        return []
    return [dict(row) for row in db.execute(
        """
        SELECT source_key, source_table, warehouse_table, row_count, columns_json
        FROM historical_table_inventory
        WHERE source_key = 'sumitro_bref_history'
          AND (
            lower(source_table) LIKE '%award%'
            OR lower(source_table) LIKE '%all-star%'
            OR lower(source_table) LIKE '%end of season%'
          )
        ORDER BY source_table
        """
    ).fetchall()]


def _normalize(value: Any) -> str:
    return re.sub(r"[^a-z0-9]+", " ", str(value or "").lower()).strip()


def _season_value(row: dict[str, Any]) -> str:
    for key, value in row.items():
        normalized = _normalize(key)
        if normalized in {"season", "year", "season id", "seasonid"}:
            text = str(value or "").strip()
            if text:
                return text
    return ""


def _row_text(row: dict[str, Any]) -> str:
    return " ".join(_normalize(value) for value in row.values() if value not in (None, ""))


def _catalog_item(award_id: str) -> dict[str, Any]:
    for item in AWARD_CATALOG:
        if item["id"] == award_id:
            return item
    raise HTTPException(status_code=404, detail=f"Unknown award: {award_id}")


@router.get("/catalog")
def awards_catalog() -> dict[str, Any]:
    return {"awards": AWARD_CATALOG, "count": len(AWARD_CATALOG)}


@router.get("/sources")
def awards_sources() -> dict[str, Any]:
    with _connect() as db:
        tables = _source_tables(db)
    for table in tables:
        try:
            table["columns"] = json.loads(table.pop("columns_json", "[]"))
        except json.JSONDecodeError:
            table["columns"] = []
    return {"tables": tables, "count": len(tables)}


@router.get("/{award_id}")
def award_history(
    award_id: str,
    season: str = "",
    query: str = "",
    limit: int = Query(default=500, ge=1, le=5000),
) -> dict[str, Any]:
    item = _catalog_item(award_id)
    query_norm = _normalize(query)
    season_norm = _normalize(season)
    rows: list[dict[str, Any]] = []
    used_tables: list[str] = []
    with _connect() as db:
        tables = _source_tables(db)
        for source in tables:
            source_name = _normalize(source["source_table"])
            if item["source_terms"] and not any(_normalize(term) in source_name for term in item["source_terms"]):
                continue
            warehouse_table = str(source["warehouse_table"])
            used_tables.append(str(source["source_table"]))
            try:
                raw_rows = db.execute(f"SELECT * FROM {_safe_identifier(warehouse_table)} LIMIT 15000").fetchall()
            except sqlite3.Error:
                continue
            for raw in raw_rows:
                row = dict(raw)
                text = _row_text(row)
                match_terms = [_normalize(term) for term in item["match_terms"] if term]
                if match_terms and not any(term in text for term in match_terms):
                    continue
                if season_norm and season_norm not in _normalize(_season_value(row)):
                    continue
                if query_norm and query_norm not in text:
                    continue
                row["_source_table"] = source["source_table"]
                row["_season"] = _season_value(row)
                rows.append(row)
                if len(rows) >= limit:
                    break
            if len(rows) >= limit:
                break
    rows.sort(key=lambda row: (_normalize(row.get("_season")), _row_text(row)), reverse=True)
    return {
        "award": item,
        "rows": rows,
        "count": len(rows),
        "source_tables": used_tables,
        "warehouse": str(_path()),
    }
