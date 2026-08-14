from __future__ import annotations

import importlib.util
import os
import sqlite3
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
TOOL_PATH = ROOT / "tools" / "collect_nba_api_modern_stats.py"
RECIPES = ROOT / "assets" / "data" / "nba" / "metadata" / "nba_api_metric_recipes.json"

spec = importlib.util.spec_from_file_location("sports_terminal_nba_api_pipeline", TOOL_PATH)
assert spec and spec.loader
pipeline = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = pipeline
spec.loader.exec_module(pipeline)


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="sports_terminal_nba_api_") as temp:
        db_path = Path(temp) / "modern.sqlite"
        with pipeline.connect(db_path) as db:
            pipeline.init_db(db)
            run_id = "fixture_run"
            db.execute(
                "INSERT INTO nba_api_collection_runs(run_id,started_at,status,package_version,plan_version) VALUES (?,?,?,?,?)",
                (run_id, pipeline.now_iso(), "running", "fixture", 1),
            )
            db.commit()

            # Deliberately do NOT pre-create nba_api_requests rows here. archive_response
            # must create its parent record before inserting result-set/raw-row children.
            hustle_plan = pipeline.EndpointPlan(
                key="hustle",
                module="fixture",
                class_name="LeagueHustleStatsPlayer",
                datasets=("HustleStatsPlayer",),
                first_season="2016-17",
                enabled=True,
                variants=({"key": "default"},),
            )
            pipeline.archive_response(
                db,
                request_id="req_hustle",
                run_id=run_id,
                plan=hustle_plan,
                season="2025-26",
                season_type="regular",
                variant_key="default",
                kwargs={},
                payload={
                    "resultSets": [
                        {
                            "name": "HustleStatsPlayer",
                            "headers": [
                                "PLAYER_ID",
                                "PLAYER_NAME",
                                "TEAM_ID",
                                "TEAM_ABBREVIATION",
                                "G",
                                "DEFLECTIONS",
                                "CHARGES_DRAWN",
                                "CONTESTED_SHOTS",
                                "LOOSE_BALLS_RECOVERED",
                            ],
                            "rowSet": [
                                [1, "Fixture Star", 10, "AAA", 10, 30, 5, 70, 12],
                                [2, "Fixture Guard", 11, "BBB", 8, 16, 2, 32, 8],
                            ],
                        }
                    ]
                },
                started_at=pipeline.now_iso(),
            )

            stats_plan = pipeline.EndpointPlan(
                key="league_player_stats",
                module="fixture",
                class_name="LeagueDashPlayerStats",
                datasets=("LeagueDashPlayerStats",),
                first_season="1996-97",
                enabled=True,
                variants=({"key": "base"},),
            )
            pipeline.archive_response(
                db,
                request_id="req_stats",
                run_id=run_id,
                plan=stats_plan,
                season="2025-26",
                season_type="regular",
                variant_key="base",
                kwargs={},
                payload={
                    "resultSets": [
                        {
                            "name": "LeagueDashPlayerStats",
                            "headers": [
                                "PLAYER_ID",
                                "PLAYER_NAME",
                                "TEAM_ID",
                                "TEAM_ABBREVIATION",
                                "FGA",
                                "FTA",
                                "PTS",
                                "FG3A",
                            ],
                            "rowSet": [
                                [1, "Fixture Star", 10, "AAA", 100, 25, 250, 40],
                                [2, "Fixture Guard", 11, "BBB", 80, 16, 160, 48],
                            ],
                        }
                    ]
                },
                started_at=pipeline.now_iso(),
            )

            parents = db.execute(
                "SELECT request_id,status,row_count FROM nba_api_requests ORDER BY request_id"
            ).fetchall()
            assert len(parents) == 2, parents
            assert all(row["status"] == "success" for row in parents), parents
            assert sum(int(row["row_count"]) for row in parents) == 4, parents

        report = pipeline.materialize(
            db_path,
            RECIPES,
            seasons=["2025-26"],
            season_types=["regular"],
        )
        assert report["materialized_rows"] >= 8, report
        with sqlite3.connect(db_path) as db:
            values = {
                (row[0], row[1]): row[2]
                for row in db.execute(
                    "SELECT player_id,metric_key,metric_value FROM nba_api_metric_values"
                ).fetchall()
            }
        assert abs(values[("1", "deflections_pg")] - 3.0) < 1e-9
        assert abs(values[("1", "charges_drawn_pg")] - 0.5) < 1e-9
        assert abs(values[("1", "contested_shots_pg")] - 7.0) < 1e-9
        assert abs(values[("1", "loose_balls_recovered_pg")] - 1.2) < 1e-9
        assert abs(values[("1", "ftr")] - 0.25) < 1e-9
        assert abs(values[("1", "three_par")] - 0.4) < 1e-9
        assert abs(values[("1", "pps")] - 2.5) < 1e-9

        os.environ["SPORTS_TERMINAL_NBA_API_DB_PATH"] = str(db_path)
        from backend.app import nba_modern_metrics_api

        status = nba_modern_metrics_api.modern_metric_status()
        assert status["ready"] is True, status
        overlay = nba_modern_metrics_api.season_metric_overlay("2025-26", "regular")
        assert overlay["players"] == 2, overlay
        fixture = next(row for row in overlay["rows"] if row["player_id"] == "1")
        assert fixture["metrics"]["deflections_pg"] == 3.0
        assert fixture["metrics"]["ftr"] == 0.25

        from backend.app.main_launch import app

        routes = {getattr(route, "path", "") for route in app.router.routes}
        assert "/v2/nba/modern-metrics/status" in routes
        assert "/v2/nba/modern-metrics/season/{season}" in routes
        assert "/v2/nba/modern-metrics/player/{player_id}" in routes

        print(
            {
                "materialized_rows": report["materialized_rows"],
                "metrics": report["distinct_metrics"],
                "players": report["distinct_players"],
                "route_count": len(
                    [path for path in routes if path.startswith("/v2/nba/modern-metrics")]
                ),
            }
        )
        print("Modern NBA API collection/materialization contract passed.")


if __name__ == "__main__":
    main()
