from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EXTRA_CONTRACTS: dict[str, tuple[str, ...]] = {
    "lib/services/nba_player_career_comparison_engine.dart": (
        "enum NbaPlayerCareerComparisonAlignment",
        "class NbaPlayerCareerComparisonEngine",
        "class NbaPlayerCareerComparisonSnapshot",
        "class NbaPlayerCareerComparisonPair",
        "NON-OVERLAPPING CALENDAR ERAS",
        "SAME CANONICAL PLAYER",
        "does not claim equivalent",
        "never sum traded-team rows here",
    ),
    "test/nba_player_career_comparison_engine_test.dart": (
        "calendar alignment uses exact source season ids and preserves gaps",
        "career year alignment pairs observed ordinal rows without era claims",
        "non-overlapping eras stay explicit under calendar alignment",
        "aggregate season is preferred over team stint without summing stints",
        "same canonical player is visible rather than silently accepted",
    ),
    "lib/services/nba_player_career_comparison_metric_engine.dart": (
        "class NbaPlayerCareerComparisonMetricEngine",
        "class NbaPlayerCareerComparisonMetricResult",
        "delta = left - right",
        "does not pace-, era-,",
        "NbaPlayerCareerMetric.trueShootingPct",
    ),
    "test/nba_player_career_comparison_metric_engine_test.dart": (
        "compares only paired observed metric values",
        "true shooting stays in percentage-point units",
        "no paired evidence produces no mean delta",
        "ties are explicit rather than arbitrarily assigned",
    ),
    "lib/services/nba_player_career_comparison_context_engine.dart": (
        "class NbaPlayerCareerComparisonContextEngine",
        "EVIDENCE ROW COUNTS ONLY",
        "sharedAwardLabels",
        "sharedAllStarSeasons",
        "winner status, voting meaning, starter status",
    ),
    "test/nba_player_career_comparison_context_engine_test.dart": (
        "intersects exact award labels without inferring wins",
        "All-Star overlap uses only explicit season ids",
        "missing context remains zero evidence rather than inferred absence",
    ),
    "lib/services/nba_player_career_comparison_discovery_service.dart": (
        "class NbaPlayerCareerComparisonDiscoveryService",
        "class NbaPlayerCareerComparisonCandidate",
        "kinds: const {'player'}",
        "exactMatch(",
        "candidate.playerName.toLowerCase() == name",
    ),
    "test/nba_player_career_comparison_discovery_service_test.dart": (
        "search projects only usable canonical Player candidates",
        "queries shorter than two characters do not call source",
        "exact match prioritizes canonical key then NBA id then exact name",
        "no exact identity evidence stays unresolved",
    ),
    "lib/services/nba_player_career_comparison_loader.dart": (
        "class NbaPlayerCareerComparisonLoader",
        "class NbaPlayerCareerComparisonBundle",
        "Both canonical historical Player keys are required",
        "Missing Team dossier remains an explicit career coverage gap",
        "NbaPlayerCareerContextEngine().build(payload)",
    ),
    "test/nba_player_career_comparison_loader_test.dart": (
        "loads two canonical careers and contexts through one boundary",
        "failed Team enrichment remains a visible career coverage gap",
        "season type is normalized and passed explicitly to both Player loads",
        "missing canonical Player key is rejected before source access",
    ),
    "lib/services/nba_player_career_comparison_workflow_service.dart": (
        "class NbaPlayerCareerComparisonWorkflowService",
        "sourceObjectType: 'NBA Player Career Comparison'",
        "'row_type': 'aligned_metric'",
        "'row_type': 'comparison_context'",
        "'normalization': 'none'",
        "comparison.samePlayer",
    ),
    "test/nba_player_career_comparison_workflow_service_test.dart": (
        "packages aligned comparison rows into shared RoutePayload state",
        "same canonical Player comparison is explicitly blocked",
        "career-year alignment remains explicit in route metadata",
    ),
    "lib/widgets/nba_player_career_comparison_chart.dart": (
        "class NbaPlayerCareerComparisonChart",
        "CustomPaint(",
        "point.leftValue",
        "point.rightValue",
        "previous = null",
    ),
    "lib/widgets/nba_player_career_comparison_summary_panel.dart": (
        "class NbaPlayerCareerComparisonSummaryPanel",
        "CAREER COMPARISON SNAPSHOT",
        "SHARED CALENDAR SEASONS",
        "MEAN Δ L−R",
        "does not claim equal age, role, rules, pace",
    ),
    "lib/widgets/nba_player_career_comparison_table.dart": (
        "class NbaPlayerCareerComparisonTable",
        "ALIGNED SEASON EVIDENCE",
        "Δ L−R",
        "A blank side means that Player has no source-backed row",
    ),
    "lib/widgets/nba_player_career_comparison_context_panel.dart": (
        "class NbaPlayerCareerComparisonContextPanel",
        "CAREER CONTEXT EVIDENCE",
        "AWARD ROWS",
        "ALL-STAR ROWS",
        "DRAFT ROWS",
    ),
    "lib/screens/product_nba_player_career_comparison_screen.dart": (
        "class ProductNbaPlayerCareerComparisonScreen",
        "NBA / HISTORICAL PLAYER CAREER COMPARISON",
        "career-comparison-player-query",
        "career-comparison-alignment",
        "career-comparison-metric",
        "career-comparison-swap",
        "NbaPlayerCareerComparisonSummaryPanel(",
        "NbaPlayerCareerComparisonChart(",
        "NbaPlayerCareerComparisonTable(",
        "NbaPlayerCareerComparisonContextPanel(",
        "RoutePayloadScope.maybeOf(context)",
        "'normalization: none'" if False else "no era, pace, age, role, possession, ruleset or award-equivalence normalization",
    ),
    "lib/widgets/nba_player_career_comparison_navigation.dart": (
        "openNbaPlayerCareerComparisonPage(",
        "'/nba/history/player-comparisons/",
        "ProductNbaPlayerCareerComparisonScreen(",
        "openHistoricalNbaSeasonPage(",
    ),
    "lib/widgets/nba_player_career_navigation.dart": (
        "player-career-open-comparison",
        "Compare historical careers",
        "openNbaPlayerCareerComparisonPage(",
        "openCareerPlayer",
    ),
    "test/nba_player_career_comparison_navigation_test.dart": (
        "permanent comparison route mounts aligned career research",
        "comparison workspace resolves a second Player from canonical search",
        "permanent Player Career app bar hands off to comparison route",
        "'/nba/history/player-comparisons/p1/p2'",
        "'/nba/history/player-comparisons/p1'",
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/nba_platform_graph_v15.json")
    args = parser.parse_args()

    legacy_output = ROOT / "artifacts/nba_platform_graph_v14.json"
    legacy = subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools/audit_nba_platform_graph_v14.py"),
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
            "path": "tools/audit_nba_platform_graph_v14.py",
            "missing": "legacy-v14-contract-pass",
        })

    payload = {
        "contract": "canonical-player-career-comparison-team-franchise-game-season-v15-all-era",
        "legacy_contract": legacy_payload.get("contract", "v14-unavailable"),
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
