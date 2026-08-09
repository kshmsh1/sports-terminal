#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATABASE = ROOT / "data" / "warehouse" / "nba_api_metrics.sqlite"


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize materialized NBA API metric coverage.")
    parser.add_argument("--database", type=Path, default=DEFAULT_DATABASE)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    if not args.database.exists():
        print(f"Materialized NBA API metric database not found: {args.database}")
        return 1

    db = sqlite3.connect(args.database)
    db.row_factory = sqlite3.Row
    totals = dict(
        db.execute(
            """
            SELECT COUNT(*) AS values_count,
                   COUNT(DISTINCT metric_key) AS metrics,
                   COUNT(DISTINCT player_id) AS players,
                   COUNT(DISTINCT season_id || '|' || season_type) AS season_partitions,
                   COUNT(DISTINCT source_endpoint) AS endpoints
            FROM nba_api_materialized_metrics
            """
        ).fetchone()
    )
    partitions = [
        dict(row)
        for row in db.execute(
            """
            SELECT season_id,season_type,COUNT(*) AS values_count,
                   COUNT(DISTINCT metric_key) AS metrics,
                   COUNT(DISTINCT player_id) AS players
            FROM nba_api_materialized_metrics
            GROUP BY season_id,season_type
            ORDER BY season_id DESC,season_type
            """
        ).fetchall()
    ]
    coverage = [
        dict(row)
        for row in db.execute(
            """
            SELECT season_id,season_type,metric_key,players,values_count,endpoints
            FROM nba_api_metric_coverage
            ORDER BY season_id DESC,season_type,players DESC,metric_key
            """
        ).fetchall()
    ]
    conflicts = int(db.execute("SELECT COUNT(*) FROM nba_api_metric_conflicts").fetchone()[0])
    db.close()
    payload = {
        "database": str(args.database),
        **totals,
        "conflicts": conflicts,
        "partitions": partitions,
        "coverage": coverage,
    }
    if args.json:
        print(json.dumps(payload, indent=2))
        return 0

    print(f"Database: {args.database}")
    print(
        f"Values: {totals['values_count']:,} | Metrics: {totals['metrics']} | "
        f"Players: {totals['players']:,} | Partitions: {totals['season_partitions']} | "
        f"Endpoints: {totals['endpoints']} | Conflicts: {conflicts:,}"
    )
    for partition in partitions:
        print(
            f"  {partition['season_id']} {partition['season_type']}: "
            f"{partition['values_count']:,} values | {partition['metrics']} metrics | "
            f"{partition['players']:,} players"
        )
    print("\nMetric coverage:")
    for row in coverage:
        print(
            f"  {row['season_id']} {row['season_type']:<8} "
            f"{row['metric_key']:<28} {row['players']:>4} players | {row['endpoints']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
