from __future__ import annotations

import json
import re
from collections import defaultdict
from typing import Any

from fastapi import APIRouter, HTTPException, Query

from .historical_nba_api import _connect

router = APIRouter(prefix="/v2/nba/awards", tags=["nba-awards"])

# Product taxonomy. Historical source labels are intentionally normalized here rather
# than exposed as the navigation model so upstream naming changes do not break URLs.
AWARDS: tuple[dict[str, Any], ...] = (
    {"key": "mvp", "label": "Most Valuable Player", "group": "Season Awards", "aliases": ("mvp", "most valuable player")},
    {"key": "roy", "label": "Rookie of the Year", "group": "Season Awards", "aliases": ("rookie of the year", "roy")},
    {"key": "dpoy", "label": "Defensive Player of the Year", "group": "Season Awards", "aliases": ("defensive player of the year", "dpoy")},
    {"key": "sixth_man", "label": "Sixth Man of the Year", "group": "Season Awards", "aliases": ("sixth man", "6moy")},
    {"key": "mip", "label": "Most Improved Player", "group": "Season Awards", "aliases": ("most improved", "mip")},
    {"key": "clutch_poy", "label": "Clutch Player of the Year", "group": "Season Awards", "aliases": ("clutch player",)},
    {"key": "sportsmanship", "label": "Sportsmanship Award", "group": "Season Awards", "aliases": ("sportsmanship",)},
    {"key": "teammate", "label": "Teammate of the Year", "group": "Season Awards", "aliases": ("teammate", "twyman-stokes")},
    {"key": "hustle", "label": "Hustle Award", "group": "Season Awards", "aliases": ("hustle",)},
    {"key": "social_justice", "label": "Social Justice Champion", "group": "Season Awards", "aliases": ("social justice", "kareem abdul-jabbar")},
    {"key": "citizenship", "label": "J. Walter Kennedy Citizenship Award", "group": "Season Awards", "aliases": ("citizenship", "j. walter kennedy")},
    {"key": "coach", "label": "Coach of the Year", "group": "Season Awards", "aliases": ("coach of the year",)},
    {"key": "executive", "label": "Executive of the Year", "group": "Season Awards", "aliases": ("executive of the year",)},
    {"key": "best_record", "label": "Best Regular Season Record", "group": "Season Awards", "aliases": ("best regular season", "podoloff")},
    {"key": "finals_mvp", "label": "Finals MVP", "group": "Postseason", "aliases": ("finals mvp",)},
    {"key": "east_finals_mvp", "label": "Eastern Conference Finals MVP", "group": "Postseason", "aliases": ("eastern conference finals mvp", "east finals mvp")},
    {"key": "west_finals_mvp", "label": "Western Conference Finals MVP", "group": "Postseason", "aliases": ("western conference finals mvp", "west finals mvp")},
    {"key": "nba_cup_mvp", "label": "NBA Cup MVP", "group": "Postseason", "aliases": ("nba cup mvp", "in-season tournament mvp")},
    {"key": "all_star_mvp", "label": "All-Star Game MVP", "group": "All-Star", "aliases": ("all-star mvp", "all star mvp")},
    {"key": "all_star", "label": "All-Star Selection", "group": "All-Star", "aliases": ()},
    {"key": "all_nba_1", "label": "All-NBA First Team", "group": "Honors", "aliases": ("all-nba first", "all nba first", "all-nba 1", "all nba 1", "1st team all-nba", "first team")},
    {"key": "all_nba_2", "label": "All-NBA Second Team", "group": "Honors", "aliases": ("all-nba second", "all nba second", "all-nba 2", "all nba 2", "2nd team all-nba", "second team")},
    {"key": "all_nba_3", "label": "All-NBA Third Team", "group": "Honors", "aliases": ("all-nba third", "all nba third", "all-nba 3", "all nba 3", "3rd team all-nba", "third team")},
    {"key": "all_defense_1", "label": "All-Defensive First Team", "group": "Honors", "aliases": ("all-defense first", "all defensive first", "all-defense 1", "all defensive 1")},
    {"key": "all_defense_2", "label": "All-Defensive Second Team", "group": "Honors", "aliases": ("all-defense second", "all defensive second", "all-defense 2", "all defensive 2")},
    {"key": "all_rookie_1", "label": "All-Rookie First Team", "group": "Honors", "aliases": ("all-rookie first", "all rookie first", "all-rookie 1", "all rookie 1")},
    {"key": "all_rookie_2", "label": "All-Rookie Second Team", "group": "Honors", "aliases": ("all-rookie second", "all rookie second", "all-rookie 2", "all rookie 2")},
    {"key": "all_tournament", "label": "NBA Cup All-Tournament Team", "group": "Honors", "aliases": ("all-tournament", "all tournament")},
    {"key": "player_month", "label": "Player of the Month", "group": "Periodic", "aliases": ("player of the month",)},
    {"key": "rookie_month", "label": "Rookie of the Month", "group": "Periodic", "aliases": ("rookie of the month",)},
    {"key": "defensive_month", "label": "Defensive Player of the Month", "group": "Periodic", "aliases": ("defensive player of the month",)},
    {"key": "player_week", "label": "Player of the Week", "group": "Periodic", "aliases": ("player of the week",)},
)

_BY_KEY = {item["key"]: item for item in AWARDS}


def _norm(value: Any) -> str:
    return re.sub(r"[^a-z0-9]+", " ", str(value or "").lower()).strip()


def _decode(value: Any) -> dict[str, Any]:
    if not value:
        return {}
    try:
        decoded = json.loads(str(value))
        return decoded if isinstance(decoded, dict) else {}
    except (TypeError, ValueError, json.JSONDecodeError):
        return {}


def _award_key(source_label: str, payload: dict[str, Any]) -> str:
    text = _norm(" ".join([source_label, *(str(value) for value in payload.values() if value is not None)]))
    # More specific team honors must win before generic first/second/third-team aliases.
    specific: tuple[tuple[str, tuple[str, ...]], ...] = (
        ("all_defense_1", ("all defensive first", "all defense first", "all defensive 1", "all defense 1")),
        ("all_defense_2", ("all defensive second", "all defense second", "all defensive 2", "all defense 2")),
        ("all_rookie_1", ("all rookie first", "all rookie 1")),
        ("all_rookie_2", ("all rookie second", "all rookie 2")),
        ("all_nba_1", ("all nba first", "all nba 1", "first team all nba")),
        ("all_nba_2", ("all nba second", "all nba 2", "second team all nba")),
        ("all_nba_3", ("all nba third", "all nba 3", "third team all nba")),
    )
    for key, aliases in specific:
        if any(alias in text for alias in aliases):
            return key
    for item in AWARDS:
        if item["key"] in {"all_star", *[key for key, _ in specific]}:
            continue
        if any(_norm(alias) in text for alias in item["aliases"] if alias):
            return str(item["key"])
    return "other"


def _row_payload(row: Any) -> dict[str, Any]:
    item = dict(row)
    payload = _decode(item.pop("payload_json", "{}"))
    item["payload"] = payload
    item["award_key"] = _award_key(str(item.get("award") or ""), payload)
    return item


def _all_award_rows(db, league: str = "NBA") -> list[dict[str, Any]]:
    params: list[Any] = []
    sql = "SELECT * FROM canon_fact_award"
    if league:
        sql += " WHERE league_id=?"
        params.append(league.upper())
    sql += " ORDER BY season_id DESC,award,player_name"
    rows = [_row_payload(row) for row in db.execute(sql, params).fetchall()]
    all_star_sql = "SELECT * FROM canon_fact_all_star"
    all_star_params: list[Any] = []
    if league:
        all_star_sql += " WHERE league_id=?"
        all_star_params.append(league.upper())
    all_star_sql += " ORDER BY season_id DESC,player_name"
    for raw in db.execute(all_star_sql, all_star_params).fetchall():
        row = dict(raw)
        payload = _decode(row.pop("payload_json", "{}"))
        rows.append(
            {
                "award_key": "all_star",
                "award_key_source": row.get("selection_key"),
                "player_key": row.get("player_key"),
                "player_name": row.get("player_name"),
                "season_id": row.get("season_id"),
                "league_id": row.get("league_id"),
                "award": "All-Star Selection",
                "rank_text": None,
                "winner": 1,
                "share": None,
                "source_key": row.get("source_key"),
                "team_text": row.get("team_text"),
                "payload": payload,
            }
        )
    return rows


@router.get("/catalog")
def awards_catalog(league: str = "NBA") -> dict[str, Any]:
    with _connect() as db:
        rows = _all_award_rows(db, league)
    by_key: dict[str, list[dict[str, Any]]] = defaultdict(list)
    source_labels: dict[str, int] = defaultdict(int)
    for row in rows:
        by_key[str(row["award_key"])].append(row)
        if row["award_key"] == "other":
            source_labels[str(row.get("award") or "Unknown")] += 1
    catalog = []
    for definition in AWARDS:
        matched = by_key.get(str(definition["key"]), [])
        seasons = sorted({str(row.get("season_id") or "") for row in matched if row.get("season_id")})
        winners = sum(1 for row in matched if int(row.get("winner") or 0) == 1)
        catalog.append(
            {
                "key": definition["key"],
                "label": definition["label"],
                "group": definition["group"],
                "records": len(matched),
                "winners": winners,
                "first_season": seasons[0] if seasons else None,
                "last_season": seasons[-1] if seasons else None,
                "has_voting": any(row.get("share") is not None or row.get("rank_text") for row in matched),
            }
        )
    return {
        "league": league.upper(),
        "catalog": catalog,
        "unclassified_records": len(by_key.get("other", [])),
        "unclassified_source_labels": [
            {"label": label, "records": count}
            for label, count in sorted(source_labels.items(), key=lambda item: (-item[1], item[0]))[:100]
        ],
    }


@router.get("/history/{award_key}")
def award_history(
    award_key: str,
    league: str = "NBA",
    season: str = "",
    winner_only: bool = False,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=250, ge=1, le=2000),
) -> dict[str, Any]:
    if award_key not in _BY_KEY:
        raise HTTPException(status_code=404, detail="Unknown Sports Terminal award key")
    with _connect() as db:
        rows = [
            row
            for row in _all_award_rows(db, league)
            if row["award_key"] == award_key
            and (not season or str(row.get("season_id") or "") == season)
            and (not winner_only or int(row.get("winner") or 0) == 1)
        ]
    rows.sort(
        key=lambda row: (
            str(row.get("season_id") or ""),
            int(row.get("winner") or 0),
            float(row.get("share") or 0),
        ),
        reverse=True,
    )
    page = rows[offset : offset + limit]
    definition = _BY_KEY[award_key]
    return {
        "award": {key: definition[key] for key in ("key", "label", "group")},
        "league": league.upper(),
        "season": season or None,
        "matched_rows": len(rows),
        "offset": offset,
        "limit": limit,
        "next_offset": offset + limit if offset + limit < len(rows) else None,
        "rows": page,
    }


@router.get("/season/{season_id}")
def season_awards(season_id: str, league: str = "NBA") -> dict[str, Any]:
    with _connect() as db:
        rows = [
            row
            for row in _all_award_rows(db, league)
            if str(row.get("season_id") or "") == season_id
        ]
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        grouped[str(row["award_key"])].append(row)
    return {
        "season": season_id,
        "league": league.upper(),
        "records": len(rows),
        "awards": [
            {
                "award": {
                    "key": key,
                    "label": _BY_KEY.get(key, {}).get("label", row_group[0].get("award") or "Other"),
                    "group": _BY_KEY.get(key, {}).get("group", "Other"),
                },
                "rows": sorted(
                    row_group,
                    key=lambda row: (
                        int(row.get("winner") or 0),
                        float(row.get("share") or 0),
                    ),
                    reverse=True,
                ),
            }
            for key, row_group in sorted(grouped.items())
        ],
    }


@router.get("/player/{player_key}")
def player_awards(player_key: str, league: str = "") -> dict[str, Any]:
    with _connect() as db:
        identity = db.execute(
            "SELECT player_key,canonical_name,nba_id,bref_id FROM canon_dim_player WHERE player_key=?",
            (player_key,),
        ).fetchone()
        if identity is None:
            raise HTTPException(status_code=404, detail="Historical player not found")
        rows = [
            row
            for row in _all_award_rows(db, league)
            if str(row.get("player_key") or "") == player_key
        ]
    rows.sort(key=lambda row: str(row.get("season_id") or ""), reverse=True)
    return {
        "player": dict(identity),
        "league": league.upper() if league else None,
        "records": len(rows),
        "rows": rows,
    }
