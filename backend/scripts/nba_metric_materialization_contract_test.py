from __future__ import annotations

import importlib.util
import json
import os
import sqlite3
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TOOLS = REPO_ROOT / "tools"
BACKEND = REPO_ROOT / "backend"
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(BACKEND))


def load_tool(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


collector = load_tool("collect_nba_api_metrics_contract", TOOLS / "collect_nba_api_metrics.py")
materializer = load_tool("materialize_nba_api_metrics_contract", TOOLS / "materialize_nba_api_metrics.py")

# The production manifest must remain parseable even though this contract uses a
# small fixture for deterministic value assertions.
production_recipes = materializer.load_recipes(materializer.DEFAULT_RECIPES)
assert len(production_recipes) >= 50, len(production_recipes)
assert any(recipe.endpoint == "LeagueHustleStatsPlayer" for recipe in production_recipes)


class FakeLeagueEndpoint:
    def __init__(
        self,
        league_id,
        season,
        season_type_all_star,
        per_mode_simple="Totals",
        timeout=30,
        get_request=True,
    ):
        pass


kwargs, unresolved = collector.build_constructor_kwargs(
    FakeLeagueEndpoint,
    season="2025-26",
    season_type="Regular Season",
    overrides={},
    timeout=55,
)
assert unresolved == [], unresolved
assert kwargs["league_id"] == "00"
assert kwargs["season"] == "2025-26"
assert kwargs["season_type_all_star"] == "Regular Season"
assert kwargs["timeout"] == 55

with tempfile.TemporaryDirectory(prefix="sports-terminal-nba-api-materialized-") as temp_dir:
    root = Path(temp_dir)
    cache = root / "cache"
    db_path = root / "nba_api_metrics.sqlite"
    report = root / "report.json"
    recipes = root / "recipes.json"
    catalog = root / "catalog.dart"

    catalog.write_text(
        """
        const fixture = [
          NbaTerminalMetricDefinition(key: 'deflections_pg'),
          NbaTerminalMetricDefinition(key: 'charges_drawn_pg'),
          NbaTerminalMetricDefinition(key: 'usage'),
        ];
        """,
        encoding="utf-8",
    )
    recipes.write_text(
        json.dumps(
            {
                "version": 99,
                "recipes": [
                    {
                        "metric": "deflections_pg",
                        "endpoint": "LeagueHustleStatsPlayer",
                        "dataset": "HustleStatsPlayer",
                        "status": "direct_aggregate",
                        "fields": ["DEFLECTIONS", "G"],
                        "formula": "DEFLECTIONS / G",
                    },
                    {
                        "metric": "charges_drawn_pg",
                        "endpoint": "LeagueHustleStatsPlayer",
                        "dataset": "HustleStatsPlayer",
                        "status": "direct_aggregate",
                        "fields": ["CHARGES_DRAWN", "G"],
                        "formula": "CHARGES_DRAWN / G",
                    },
                    {
                        "metric": "usage",
                        "endpoint": "PlayerEstimatedMetrics",
                        "dataset": "PlayerEstimatedMetrics",
                        "status": "direct_estimate",
                        "field": "E_USG_PCT",
                        "formula": "direct",
                    },
                    # Lower-priority conflicting evidence proves precedence + audit.
                    {
                        "metric": "usage",
                        "endpoint": "LeagueDashPlayerStats",
                        "dataset": "LeagueDashPlayerStats",
                        "status": "transparent_derived",
                        "field": "USG_PCT",
                        "formula": "direct",
                    },
                ],
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    def write_cache(
        endpoint: str,
        season_type: str,
        dataset: str,
        rows: list[dict[str, object]],
        suffix: str = "default",
    ) -> None:
        path = cache / "2025-26" / season_type / f"{endpoint}-{suffix}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "endpoint": endpoint,
                    "module": endpoint.lower(),
                    "season": "2025-26",
                    "season_type": season_type,
                    "season_type_label": "Regular Season" if season_type == "regular" else "Playoffs",
                    "variant": {},
                    "parameters": {"season": "2025-26"},
                    "collected_at": "2026-08-08T20:00:00+00:00",
                    "result_sets": {dataset: rows},
                },
                indent=2,
            ),
            encoding="utf-8",
        )

    players = [
        {
            "PLAYER_ID": 1001,
            "PLAYER_NAME": "Example Star",
            "TEAM_ID": 1,
            "TEAM_ABBREVIATION": "AAA",
            "G": 80,
            "DEFLECTIONS": 240,
            "CHARGES_DRAWN": 16,
        },
        {
            "PLAYER_ID": 1002,
            "PLAYER_NAME": "Example Guard",
            "TEAM_ID": 2,
            "TEAM_ABBREVIATION": "BBB",
            "G": 70,
            "DEFLECTIONS": 140,
            "CHARGES_DRAWN": 7,
        },
    ]
    playoff_players = [
        {
            "PLAYER_ID": 1001,
            "PLAYER_NAME": "Example Star",
            "TEAM_ID": 1,
            "TEAM_ABBREVIATION": "AAA",
            "G": 10,
            "DEFLECTIONS": 40,
            "CHARGES_DRAWN": 3,
        }
    ]
    write_cache("LeagueHustleStatsPlayer", "regular", "HustleStatsPlayer", players)
    write_cache("LeagueHustleStatsPlayer", "playoffs", "HustleStatsPlayer", playoff_players)
    write_cache(
        "PlayerEstimatedMetrics",
        "regular",
        "PlayerEstimatedMetrics",
        [
            {"PLAYER_ID": 1001, "PLAYER_NAME": "Example Star", "E_USG_PCT": 0.305},
            {"PLAYER_ID": 1002, "PLAYER_NAME": "Example Guard", "E_USG_PCT": 0.211},
        ],
    )
    write_cache(
        "LeagueDashPlayerStats",
        "regular",
        "LeagueDashPlayerStats",
        [
            {"PLAYER_ID": 1001, "PLAYER_NAME": "Example Star", "USG_PCT": 0.285},
            {"PLAYER_ID": 1002, "PLAYER_NAME": "Example Guard", "USG_PCT": 0.209},
        ],
    )

    summary = materializer.materialize(
        cache_root=cache,
        recipes_path=recipes,
        catalog_path=catalog,
        database_path=db_path,
        report_path=report,
        replace=True,
    )
    assert summary["cache_documents"] == 4
    assert summary["materialized_metrics"] == 3, summary
    assert summary["materialized_players"] == 2
    assert summary["materialized_season_partitions"] == 2
    assert summary["actual_metric_coverage_pct"] == 100.0
    assert summary["conflicts"] >= 1

    with sqlite3.connect(db_path) as db:
        db.row_factory = sqlite3.Row
        star = db.execute(
            """
            SELECT metric_key,value,source_endpoint
            FROM nba_api_materialized_metrics
            WHERE season_id='2025-26' AND season_type='regular' AND player_id='1001'
            ORDER BY metric_key
            """
        ).fetchall()
        by_metric = {row["metric_key"]: row for row in star}
        assert abs(by_metric["deflections_pg"]["value"] - 3.0) < 1e-9
        assert abs(by_metric["charges_drawn_pg"]["value"] - 0.2) < 1e-9
        assert abs(by_metric["usage"]["value"] - 0.305) < 1e-9
        assert by_metric["usage"]["source_endpoint"] == "PlayerEstimatedMetrics"
        playoff = db.execute(
            """
            SELECT value FROM nba_api_materialized_metrics
            WHERE season_id='2025-26' AND season_type='playoffs'
              AND player_id='1001' AND metric_key='deflections_pg'
            """
        ).fetchone()
        assert playoff is not None and abs(playoff["value"] - 4.0) < 1e-9

    os.environ["SPORTS_TERMINAL_NBA_METRIC_DB"] = str(db_path)
    from app import nba_metric_materialization_api as api

    status = api.materialized_metric_status()
    assert status["ready"] is True
    assert status["metrics"] == 3
    coverage = api.materialized_metric_coverage("2025-26", "regular")
    assert coverage["ready"] is True
    assert coverage["metrics"] == 3
    overlay = api.materialized_player_season_metrics(
        season="2025-26",
        season_type="regular",
        league_id="00",
        include_provenance=True,
        limit=1000,
    )
    assert overlay["players"] == 2
    star_overlay = next(row for row in overlay["rows"] if row["player_id"] == "1001")
    assert star_overlay["fields"]["deflections_pg"] == 3.0
    assert star_overlay["fields"]["usage"] == 0.305
    assert star_overlay["provenance"]["usage"]["endpoint"] == "PlayerEstimatedMetrics"

print("NBA API metric materialization contract passed.")