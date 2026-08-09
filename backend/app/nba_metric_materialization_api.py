from __future__ import annotations

import json
import os
import sqlite3
from pathlib import Path
from typing import Any

from fastapi import APIRouter, Query

BACKEND_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_ROOT.parent
DEFAULT_DB_PATH = REPO_ROOT / "data" / "warehouse" / "nba_api_metrics.sqlite"

router = APIRouter(prefix="/v2/nba/metrics", tags=["nba-materialized-metrics"])


def _database_path() -> Path:
    return Path(os.getenv("SPORTS_TERMINAL_NBA_METRIC_DB", DEFAULT_DB_PATH))


def _connect() -> sqlite3.Connection | None:
    path = _database_path()
    if not path.exists():
        return None
    db = sqlite3.connect(path)
    db.row_factory = sqlite3.Row
    return db


def _table_exists(db: sqlite3.Connection, name: str) -> bool:
    return (
        db.execute(
            "SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name=?",
            (name,),
        ).fetchone()
        is not None
    )


def _decode(value: Any, fallback: Any) -> Any:
    if value in (None, ""):
        return fallback
    try:
        return json.loads(str(value))
    except (TypeError, ValueError):
        return fallback


@router.get("/status")
def materialized_metric_status() -> dict[str, Any]:
    path = _database_path()
    db = _connect()
    if db is None:
        return {
            "ready": False,
            "database": str(path),
            "reason": "materialized metric database not found",
            "values": 0,
            "metrics": 0,
            "players": 0,
            "season_partitions": 0,
        }
    try:
        if not _table_exists(db, "nba_api_materialized_metrics"):
            return {
                "ready": False,
                "database": str(path),
                "reason": "materialized metric table not found",
                "values": 0,
                "metrics": 0,
                "players": 0,
                "season_partitions": 0,
            }
        row = db.execute(
            """
            SELECT COUNT(*) AS values_count,
                   COUNT(DISTINCT metric_key) AS metrics,
                   COUNT(DISTINCT player_id) AS players,
                   COUNT(DISTINCT season_id || '|' || season_type) AS season_partitions,
                   MAX(collected_at) AS latest_collection
            FROM nba_api_materialized_metrics
            """
        ).fetchone()
        run = None
        if _table_exists(db, "nba_api_metric_runs"):
            run_row = db.execute(
                "SELECT * FROM nba_api_metric_runs ORDER BY generated_at DESC LIMIT 1"
            ).fetchone()
            run = dict(run_row) if run_row else None
            if run and "summary_json" in run:
                run["summary"] = _decode(run.pop("summary_json"), {})
        return {
            "ready": True,
            "database": str(path),
            "values": int(row["values_count"] or 0),
            "metrics": int(row["metrics"] or 0),
            "players": int(row["players"] or 0),
            "season_partitions": int(row["season_partitions"] or 0),
            "latest_collection": row["latest_collection"],
            "latest_run": run,
        }
    finally:
        db.close()


@router.get("/coverage")
def materialized_metric_coverage(
    season: str = "",
    season_type: str = "",
) -> dict[str, Any]:
    db = _connect()
    if db is None:
        return {"ready": False, "rows": []}
    try:
        if not _table_exists(db, "nba_api_metric_coverage"):
            return {"ready": False, "rows": []}
        clauses: list[str] = []
        params: list[Any] = []
        if season:
            clauses.append("season_id=?")
            params.append(season)
        if season_type:
            clauses.append("season_type=?")
            params.append(season_type.lower())
        sql = "SELECT * FROM nba_api_metric_coverage"
        if clauses:
            sql += " WHERE " + " AND ".join(clauses)
        sql += " ORDER BY season_id DESC,season_type,players DESC,metric_key"
        rows = [dict(row) for row in db.execute(sql, params).fetchall()]
        return {
            "ready": True,
            "season": season or None,
            "season_type": season_type.lower() or None,
            "metrics": len({row["metric_key"] for row in rows}),
            "rows": rows,
        }
    finally:
        db.close()


@router.get("/player-season")
def materialized_player_season_metrics(
    season: str,
    season_type: str = "regular",
    league_id: str = "00",
    player_id: str = "",
    include_provenance: bool = False,
    limit: int = Query(default=1000, ge=1, le=5000),
) -> dict[str, Any]:
    """Return one map-shaped metric overlay per player.

    Metric keys intentionally match the Flutter metric catalog keys, so callers can
    merge ``fields`` directly into a player-season raw row before passing it to the
    existing Stats engine/resolver.
    """
    db = _connect()
    if db is None:
        return {
            "ready": False,
            "season": season,
            "season_type": season_type.lower(),
            "players": 0,
            "rows": [],
        }
    try:
        if not _table_exists(db, "nba_api_materialized_metrics"):
            return {
                "ready": False,
                "season": season,
                "season_type": season_type.lower(),
                "players": 0,
                "rows": [],
            }
        clauses = ["season_id=?", "season_type=?", "league_id=?"]
        params: list[Any] = [season, season_type.lower(), league_id]
        if player_id:
            clauses.append("player_id=?")
            params.append(player_id)
        sql = f"""
            SELECT * FROM nba_api_materialized_metrics
            WHERE {' AND '.join(clauses)}
            ORDER BY player_id,metric_key
            LIMIT ?
        """
        # Limit applies to metric evidence rows; callers typically receive ~100-200
        # players × the subset of actually populated metrics.
        params.append(limit)
        raw = db.execute(sql, params).fetchall()
        players: dict[str, dict[str, Any]] = {}
        for row in raw:
            key = str(row["player_id"])
            player = players.setdefault(
                key,
                {
                    "player_id": key,
                    "player_name": row["player_name"] or "",
                    "team_id": row["team_id"] or "",
                    "team_abbreviation": row["team_abbreviation"] or "",
                    "fields": {},
                    "provenance": {},
                },
            )
            metric_key = str(row["metric_key"])
            player["fields"][metric_key] = row["value"]
            if include_provenance:
                player["provenance"][metric_key] = _decode(row["provenance_json"], {})
        return {
            "ready": True,
            "season": season,
            "season_type": season_type.lower(),
            "league_id": league_id,
            "players": len(players),
            "metric_rows": len(raw),
            "rows": list(players.values()),
        }
    finally:
        db.close()


@router.get("/player/{player_id}")
def materialized_player_metrics(
    player_id: str,
    season: str = "",
    season_type: str = "",
) -> dict[str, Any]:
    db = _connect()
    if db is None:
        return {"ready": False, "player_id": player_id, "rows": []}
    try:
        if not _table_exists(db, "nba_api_materialized_metrics"):
            return {"ready": False, "player_id": player_id, "rows": []}
        clauses = ["player_id=?"]
        params: list[Any] = [player_id]
        if season:
            clauses.append("season_id=?")
            params.append(season)
        if season_type:
            clauses.append("season_type=?")
            params.append(season_type.lower())
        rows = [dict(row) for row in db.execute(
            f"""
            SELECT season_id,season_type,league_id,player_id,player_name,team_id,
                   team_abbreviation,metric_key,value,mapping_status,source_endpoint,
                   source_dataset,source_formula,provenance_json
            FROM nba_api_materialized_metrics
            WHERE {' AND '.join(clauses)}
            ORDER BY season_id DESC,season_type,metric_key
            """,
            params,
        ).fetchall()]
        for row in rows:
            row["provenance"] = _decode(row.pop("provenance_json"), {})
        return {"ready": True, "player_id": player_id, "rows": rows}
    finally:
        db.close()
