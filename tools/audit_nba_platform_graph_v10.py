from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EXTRA_CONTRACTS: dict[str, tuple[str, ...]] = {
    "lib/services/nba_season_player_leader_engine.dart": (
        "class NbaSeasonPlayerLeaderEngine",
        "enum NbaSeasonLeaderMetric",
        "class NbaSeasonPlayerLeaderResult",
        "class NbaSeasonPlayerLeader",
        "seasonId",
        "seasonType",
        "minimumGames",
        "eligiblePlayers",
        "_rawSeasonId",
        "NbaStatsBasis.perGame",
    ),
    "lib/services/nba_season_team_distribution_engine.dart": (
        "class NbaSeasonTeamDistributionEngine",
        "enum NbaSeasonTeamDistributionMetric",
        "class NbaSeasonTeamDistributionResult",
        "class NbaSeasonTeamDistributionObservation",
        "mean",
        "median",
        "lowerQuartile",
        "upperQuartile",
        "standardDeviation",
        "standing.games > 0",
    ),
    "lib/services/nba_season_playoff_series_engine.dart": (
        "class NbaSeasonPlayoffSeriesEngine",
        "class NbaSeasonPlayoffSeriesResult",
        "class NbaObservedPlayoffSeries",
        "seasonType: 'Playoffs'",
        "if (!game.hasScore)",
        "Observed canonical playoff matchups only",
        "rounds and advancement are not inferred",
        "leaderLabel",
        "scheduledGames",
    ),
    "lib/widgets/nba_terminal_distribution_chart.dart": (
        "class NbaTerminalDistributionChart",
        "class NbaTerminalDistributionPoint",
        "nba-terminal-distribution-chart",
        "Negative observations stay below",
        "CustomPaint",
        "referenceValue",
    ),
    "lib/widgets/nba_season_analytics_panel.dart": (
        "class NbaSeasonAnalyticsPanel",
        "SEASON ANALYTICS WORKBENCH",
        "PLAYER LEADERS",
        "TEAM DISTRIBUTION",
        "OBSERVED PLAYOFF MATCHUPS",
        "season-leader-metric",
        "season-team-distribution-metric",
        "season-leader-",
        "season-distribution-team-",
        "season-playoff-game-",
        "NbaTerminalDistributionChart",
    ),
    "lib/services/nba_season_workflow_service.dart": (
        "class NbaSeasonWorkflowService",
        "sourceObjectType: 'NBA Season'",
        "SportsObjectRouter().packageRows",
        "readinessState",
        "filterSummary",
        "completedGames",
        "scheduledGames",
        "usedFallbackDataset",
    ),
    "lib/screens/product_nba_season_screen.dart": (
        "NbaSeasonAnalyticsPanel(",
        "NbaSeasonWorkflowService",
        "RoutePayloadScope.maybeOf(context)",
        "SEASON WORKFLOWS",
        "season-route-workspace",
        "season-route-python",
        "season-route-compare",
        "season-route-source-audit",
        "onOpenPlayer",
    ),
    "lib/widgets/nba_game_navigation.dart": (
        "openHistoricalNbaSeasonPage(",
        "loadHistoricalSeason(",
        "seasonId: normalizedSeason",
        "onOpenPlayer: onOpenPlayer",
        "'/nba/seasons/",
    ),
    "test/nba_season_player_leader_engine_test.dart": (
        "ranks canonical season leaders without cross-season leakage",
        "keeps regular season and playoffs isolated",
        "minimum games qualification is explicit",
        "missing metric values are not fabricated",
    ),
    "test/nba_season_team_distribution_engine_test.dart": (
        "derives ordered team differential distribution from scored games",
        "scheduled games never enter team distribution statistics",
        "playoff distributions remain separate from regular season",
    ),
    "test/nba_season_playoff_series_engine_test.dart": (
        "groups canonical playoff games by observed team matchup only",
        "scheduled playoff games remain visible but never alter observed wins",
        "no playoff rows produces an explicit unavailable result",
    ),
    "test/nba_season_workflow_service_test.dart": (
        "packages canonical season standings into shared RoutePayload state",
        "season type remains an explicit workflow filter",
        "empty season scope is partial instead of fabricating standings",
    ),
    "test/nba_season_analytics_workflow_test.dart": (
        "permanent season route exposes analytics and canonical entity drilldowns",
        "season workflows write canonical package into shared RoutePayload state",
        "observed playoff matchup links reopen canonical game routes",
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/nba_platform_graph_v10.json")
    args = parser.parse_args()

    legacy_output = ROOT / "artifacts/nba_platform_graph_v9.json"
    legacy = subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools/audit_nba_platform_graph_v9.py"),
            "--check",
            "--json",
            str(legacy_output),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    failures: list[dict[str, str]] = []
    assertions = 0
    passed = 0
    for relative, required in EXTRA_CONTRACTS.items():
        path = ROOT / relative
        if not path.exists():
            failures.append({"path": relative, "missing": "<file>"})
            continue
        text = path.read_text(encoding="utf-8")
        for token in required:
            assertions += 1
            if token not in text:
                failures.append({"path": relative, "missing": token})
            else:
                passed += 1

    legacy_payload: dict[str, object] = {}
    if legacy_output.exists():
        legacy_payload = json.loads(legacy_output.read_text(encoding="utf-8"))
    if legacy.returncode != 0:
        failures.append({
            "path": "tools/audit_nba_platform_graph_v9.py",
            "missing": "legacy-v9-contract-pass",
        })

    payload = {
        "contract": "canonical-player-team-game-event-trends-season-analytics-v10-all-era",
        "legacy_contract": legacy_payload.get("contract", "v9-unavailable"),
        "legacy_assertions": legacy_payload.get("assertions", 0),
        "legacy_passed": legacy_payload.get("passed", 0),
        "surfaces": len(EXTRA_CONTRACTS),
        "assertions": assertions,
        "passed": passed,
        "failures": failures,
    }
    output = ROOT / args.json
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps(payload, indent=2))
    return 1 if args.check and failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
