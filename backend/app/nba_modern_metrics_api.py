from __future__ import annotations

import json
import os
import sqlite3
from pathlib import Path
from typing import Annotated, Any

from fastapi import APIRouter, HTTPException, Query

from .historical_nba_api import _connect as historical_connect

ROOT = Path(__file__).resolve().parents[2]
DB_PATH = Path(
    os.getenv(
        "SPORTS_TERMINAL_NBA_API_DB_PATH",
        ROOT / "data" / "warehouse" / "nba_api_modern.sqlite",
    )
)

router = APIRouter(prefix="/v2/nba/modern-metrics", tags=["nba-modern-metrics"])

SEASON_TYPE_MAP = {
    "regular": "regular",
    "regular season": "regular",
    "playoffs": "playoffs",
    "postseason": "playoffs",
}


def _connect() -> sqlite3.Connection:
    if not DB_PATH.exists():
        raise HTTPException(
            status_code=503,
            detail=(
                "Modern NBA API warehouse has not been collected yet. Run "
                "scripts/collect_nba_api_modern_stats.sh first."
            ),
        )
    db = sqlite3.connect(DB_PATH)
    db.row_factory = sqlite3.Row
    return db


def _tables(db: sqlite3.Connection) -> set[str]:
    return {
        str(row["name"])
        for row in db.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        ).fetchall()
    }


def _normalize_segment(value: str) -> str:
    normalized = value.strip().lower()
    if normalized not in SEASON_TYPE_MAP:
        raise HTTPException(
            status_code=422,
            detail="season_type must be regular or playoffs",
        )
    return SEASON_TYPE_MAP[normalized]


def _canonical_crosswalk(nba_ids: list[str]) -> dict[str, str]:
    clean = sorted({value.strip() for value in nba_ids if value.strip()})
    if not clean:
        return {}
    try:
        with historical_connect() as db:
            placeholders = ",".join("?" for _ in clean)
            rows = db.execute(
                f"SELECT player_key,nba_id FROM canon_dim_player WHERE CAST(nba_id AS TEXT) IN ({placeholders})",
                clean,
            ).fetchall()
            return {
                str(row["nba_id"]): str(row["player_key"])
                for row in rows
                if row["nba_id"] is not None
            }
    except Exception:
        return {}


def _metric_rows(
    db: sqlite3.Connection,
    season: str,
    season_type: str,
    metric_keys: list[str],
    player_ids: list[str],
) -> list[sqlite3.Row]:
    clauses = ["season=?", "season_type=?"]
    params: list[Any] = [season, season_type]
    if metric_keys:
        placeholders = ",".join("?" for _ in metric_keys)
        clauses.append(f"metric_key IN ({placeholders})")
        params.extend(metric_keys)
    if player_ids:
        placeholders = ",".join("?" for _ in player_ids)
        clauses.append(f"player_id IN ({placeholders})")
        params.extend(player_ids)
    return db.execute(
        f"""
        SELECT * FROM nba_api_metric_values
        WHERE {' AND '.join(clauses)}
        ORDER BY player_id,metric_key,
                 CASE WHEN team_id IN ('','0') THEN 0 ELSE 1 END,
                 recipe_priority,source_endpoint,variant_key
        """,
        params,
    ).fetchall()


def _group_player_metrics(rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
    crosswalk = _canonical_crosswalk([str(row["player_id"]) for row in rows])
    players: dict[str, dict[str, Any]] = {}
    seen_metrics: set[tuple[str, str]] = set()
    for row in rows:
        player_id = str(row["player_id"])
        item = players.setdefault(
            player_id,
            {
                "player_id": player_id,
                "canonical_player_key": crosswalk.get(player_id, ""),
                "player_name": str(row["player_name"] or ""),
                "team_id": str(row["team_id"] or ""),
                "team_abbreviation": str(row["team_abbreviation"] or ""),
                "metrics": {},
                "provenance": {},
            },
        )
        metric_key = str(row["metric_key"])
        identity = (player_id, metric_key)
        if identity in seen_metrics:
            continue
        seen_metrics.add(identity)
        item["metrics"][metric_key] = float(row["metric_value"])
        item["provenance"][metric_key] = {
            "endpoint": row["source_endpoint"],
            "dataset": row["source_dataset"],
            "variant": row["variant_key"],
            "recipe_status": row["recipe_status"],
            "operation": row["operation"],
            "request_id": row["request_id"],
        }
    return list(players.values())


@router.get("/status")
def modern_metric_status() -> dict[str, Any]:
    if not DB_PATH.exists():
        return {
            "ready": False,
            "database": str(DB_PATH),
            "reason": "not_collected",
            "collection_command": "bash scripts/collect_nba_api_modern_stats.sh --season 2025-26 --season-type both --replace-scope",
        }
    with _connect() as db:
        tables = _tables(db)
        required = {
            "nba_api_collection_runs",
            "nba_api_requests",
            "nba_api_raw_rows",
            "nba_api_metric_values",
        }
        if not required.issubset(tables):
            return {
                "ready": False,
                "database": str(DB_PATH),
                "reason": "schema_incomplete",
                "missing_tables": sorted(required - tables),
            }
        latest = db.execute(
            "SELECT * FROM nba_api_collection_runs ORDER BY started_at DESC LIMIT 1"
        ).fetchone()
        counts = {
            "runs": int(db.execute("SELECT COUNT(*) FROM nba_api_collection_runs").fetchone()[0]),
            "requests": int(db.execute("SELECT COUNT(*) FROM nba_api_requests").fetchone()[0]),
            "successful_requests": int(db.execute("SELECT COUNT(*) FROM nba_api_requests WHERE status='success'").fetchone()[0]),
            "failed_requests": int(db.execute("SELECT COUNT(*) FROM nba_api_requests WHERE status='failure'").fetchone()[0]),
            "raw_rows": int(db.execute("SELECT COUNT(*) FROM nba_api_raw_rows").fetchone()[0]),
            "metric_rows": int(db.execute("SELECT COUNT(*) FROM nba_api_metric_values").fetchone()[0]),
            "metrics": int(db.execute("SELECT COUNT(DISTINCT metric_key) FROM nba_api_metric_values").fetchone()[0]),
            "players": int(db.execute("SELECT COUNT(DISTINCT player_id) FROM nba_api_metric_values").fetchone()[0]),
            "seasons": int(db.execute("SELECT COUNT(DISTINCT season) FROM nba_api_metric_values").fetchone()[0]),
        }
        scopes = [
            dict(row)
            for row in db.execute(
                """
                SELECT season,season_type,
                       COUNT(DISTINCT endpoint_key) AS endpoints,
                       COUNT(DISTINCT player_id) AS players,
                       COUNT(*) AS raw_rows
                FROM nba_api_raw_rows
                GROUP BY season,season_type
                ORDER BY season DESC,season_type
                """
            ).fetchall()
        ]
    return {
        "ready": counts["metric_rows"] > 0,
        "database": str(DB_PATH),
        "latest_run": dict(latest) if latest else None,
        "counts": counts,
        "scopes": scopes,
    }


@router.get("/coverage")
def modern_metric_coverage() -> dict[str, Any]:
    with _connect() as db:
        rows = [
            dict(row)
            for row in db.execute(
                """
                SELECT season,season_type,metric_key,
                       COUNT(DISTINCT player_id) AS players,
                       COUNT(DISTINCT source_endpoint) AS sources,
                       MIN(materialized_at) AS first_materialized_at,
                       MAX(materialized_at) AS last_materialized_at
                FROM nba_api_metric_values
                GROUP BY season,season_type,metric_key
                ORDER BY season DESC,season_type,metric_key
                """
            ).fetchall()
        ]
    return {
        "database": str(DB_PATH),
        "records": len(rows),
        "rows": rows,
    }


@router.get("/season/{season}")
def season_metric_overlay(
    season: str,
    season_type: str = "regular",
    metric_keys: str = "",
    player_ids: str = "",
    limit: Annotated[int, Query(ge=1, le=2000)] = 1000,
) -> dict[str, Any]:
    segment = _normalize_segment(season_type)
    metrics = [value.strip() for value in metric_keys.split(",") if value.strip()]
    players = [value.strip() for value in player_ids.split(",") if value.strip()]
    with _connect() as db:
        rows = _metric_rows(db, season.strip(), segment, metrics, players)
    grouped = _group_player_metrics(rows)[:limit]
    return {
        "season": season.strip(),
        "season_type": segment,
        "players": len(grouped),
        "metric_keys": sorted(
            {key for item in grouped for key in item["metrics"]}
        ),
        "rows": grouped,
    }


@router.get("/player/{player_id}")
def player_modern_metrics(
    player_id: str,
    season: str = "",
    season_type: str = "regular",
) -> dict[str, Any]:
    segment = _normalize_segment(season_type)
    with _connect() as db:
        clauses = ["player_id=?", "season_type=?"]
        params: list[Any] = [player_id, segment]
        if season:
            clauses.append("season=?")
            params.append(season)
        rows = db.execute(
            f"""
            SELECT * FROM nba_api_metric_values
            WHERE {' AND '.join(clauses)}
            ORDER BY season DESC,metric_key,recipe_priority
            """,
            params,
        ).fetchall()
    grouped_by_season: dict[str, list[sqlite3.Row]] = {}
    for row in rows:
        grouped_by_season.setdefault(str(row["season"]), []).append(row)
    return {
        "player_id": player_id,
        "canonical_player_key": _canonical_crosswalk([player_id]).get(player_id, ""),
        "season_type": segment,
        "seasons": [
            {
                "season": season_key,
                "rows": _group_player_metrics(season_rows),
            }
            for season_key, season_rows in grouped_by_season.items()
        ],
    }
