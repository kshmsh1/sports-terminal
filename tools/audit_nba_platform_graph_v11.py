from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EXTRA_CONTRACTS: dict[str, tuple[str, ...]] = {
    "lib/services/nba_season_comparison_engine.dart": (
        "class NbaSeasonComparisonEngine",
        "class NbaSeasonComparisonResult",
        "class NbaSeasonTeamComparison",
        "leftSeasonId",
        "rightSeasonId",
        "commonTeams",
        "onlyLeftTeams",
        "onlyRightTeams",
        "differentialDelta",
        "NbaSeasonIntelligenceEngine",
    ),
    "test/nba_season_comparison_engine_test.dart": (
        "compares only teams present in both explicitly selected seasons",
        "scheduled games stay in coverage but never change comparison performance",
        "requested season id prevents other-season leakage",
    ),
    "lib/services/nba_season_benchmark_engine.dart": (
        "class NbaSeasonBenchmarkEngine",
        "class NbaSeasonBenchmarkResult",
        "class NbaSeasonBenchmarkRow",
        "higherIsBetter",
        "pointsAgainst",
        "percentile",
        "tiedTeams",
        "deltaFromMedian",
    ),
    "test/nba_season_benchmark_engine_test.dart": (
        "ranks differential from explicit scored-game observations",
        "points against correctly treats lower values as better",
        "tied observations share rank and percentile",
        "scheduled rows cannot change sample size",
    ),
    "lib/services/nba_season_source_context_engine.dart": (
        "class NbaSeasonSourceContextEngine",
        "class NbaSeasonSourceContext",
        "class NbaSeasonAwardContext",
        "class NbaSeasonAllStarContext",
        "class NbaSeasonDraftContext",
        "class NbaSeasonTransactionContext",
        "transactionCoverageAvailable",
        "payload.containsKey('transactions')",
    ),
    "test/nba_season_source_context_engine_test.dart": (
        "projects only source-backed season context collections",
        "missing transaction collection stays explicitly unavailable",
        "compatible transaction rows remain exact",
        "malformed rows are discarded",
    ),
    "lib/widgets/nba_season_cross_season_panel.dart": (
        "class NbaSeasonCrossSeasonPanel",
        "CROSS-SEASON INTELLIGENCE",
        "LEAGUE BENCHMARK",
        "EXPLICIT SEASON COMPARISON",
        "season-comparison-id",
        "season-run-comparison",
        "season-benchmark-team-",
        "season-comparison-team-",
        "loadHistoricalSeason",
    ),
    "lib/widgets/nba_season_source_context_panel.dart": (
        "class NbaSeasonSourceContextPanel",
        "SEASON SOURCE CONTEXT",
        "AWARDS + ALL-STAR",
        "DRAFT CONTEXT",
        "COVERAGE + TRANSACTION BOUNDARY",
        "season-transactions-not-exposed",
        "TRANSACTION DATASET NOT EXPOSED",
        "seasonCommand(",
    ),
    "lib/widgets/nba_game_discovery_panel.dart": (
        "GAME DISCOVERY",
        "hub-season-discovery-result",
        "hub-discovery-season-",
        "Open Season",
        "openNbaSeasonPage(",
        "seed.supportedSeason",
    ),
    "lib/services/nba_season_workflow_service.dart": (
        "activateResearch(",
        "watchItem(",
        "isWatched(",
        "toggleWatch(",
        "kind: 'season'",
        "activateHistorical(",
        "selectCurrent(clearEntity: true)",
    ),
    "lib/screens/product_nba_terminal_screen.dart": (
        "terminal-open-season-",
        "Open Season",
        "_openHistoricalSeason(",
        "openHistoricalNbaSeasonPage(",
        "kind == 'season'",
        "'season' => 'Open season'",
    ),
    "lib/screens/product_nba_season_screen.dart": (
        "NbaSeasonCrossSeasonPanel(",
        "NbaSeasonSourceContextPanel(",
        "season-activate-research",
        "season-toggle-watch",
        "RESEARCH CONTEXT",
        "WATCH SEASON",
        "UNWATCH SEASON",
        "loadComparisonSeason",
        "loadSourceContext",
    ),
    "lib/widgets/nba_game_navigation.dart": (
        "NbaSeasonComparisonSeedLoader? loadComparisonSeason",
        "NbaSeasonSourcePayloadLoader? loadSourceContext",
        "loadComparisonSeason: loadComparisonSeason",
        "loadSourceContext: loadSourceContext",
        "loadComparisonSeason: (comparisonSeason)",
    ),
    "test/nba_season_workflow_service_test.dart": (
        "canonical Season watch identity persists exact season and filter",
        "historical Season research activates exact historical season and type",
        "current Season research never silently flips into historical mode",
    ),
    "test/nba_season_analytics_workflow_test.dart": (
        "explicit season comparison uses only the requested comparison loader",
        "season watch control persists and toggles canonical Season identity",
        "season-transactions-not-exposed",
        "season-cross-season-workbench",
        "season-source-context-panel",
    ),
    "test/nba_season_navigation_test.dart": (
        "season-cross-season-workbench",
        "season-source-context-panel",
        "season-transactions-not-exposed",
        "loadComparisonSeason",
        "loadSourceContext",
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/nba_platform_graph_v11.json")
    args = parser.parse_args()

    legacy_output = ROOT / "artifacts/nba_platform_graph_v10.json"
    legacy = subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools/audit_nba_platform_graph_v10.py"),
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
            "path": "tools/audit_nba_platform_graph_v10.py",
            "missing": "legacy-v10-contract-pass",
        })

    payload = {
        "contract": "canonical-player-team-game-event-trends-season-cross-platform-v11-all-era",
        "legacy_contract": legacy_payload.get("contract", "v10-unavailable"),
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
