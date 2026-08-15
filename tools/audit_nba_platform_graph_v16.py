from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EXTRA_CONTRACTS: dict[str, tuple[str, ...]] = {
    "lib/services/nba_player_career_comparison_scope_engine.dart": (
        "class NbaPlayerCareerComparisonScopeEngine",
        "SHARED-SEASON FILTER REQUIRES CALENDAR ALIGNMENT",
        "NO SHARED CALENDAR SEASONS",
        "pair.bothObserved",
    ),
    "test/nba_player_career_comparison_scope_engine_test.dart": (
        "shared calendar scope keeps only exact overlapping seasons",
        "shared-season scope never reinterprets career-year alignment",
        "no shared seasons stays explicitly empty",
    ),
    "lib/services/nba_player_career_comparison_matrix_engine.dart": (
        "class NbaPlayerCareerComparisonMatrixEngine",
        "class NbaPlayerCareerComparisonMatrixMetricSummary",
        "double? get delta => paired ? leftValue! - rightValue! : null",
        "season.trueShootingPct! * 100",
    ),
    "test/nba_player_career_comparison_matrix_engine_test.dart": (
        "matrix keeps source-backed metric cells and left-minus-right deltas",
        "missing metric evidence stays null and is excluded from summary",
        "shared scope removes one-sided rows before matrix construction",
    ),
    "lib/services/nba_player_career_peak_window_engine.dart": (
        "class NbaPlayerCareerPeakWindowEngine",
        "Missing seasons break eligibility; no interpolation",
        "does not claim equivalent",
        "values.any((value) => value == null)",
    ),
    "test/nba_player_career_peak_window_engine_test.dart": (
        "finds each player best complete contiguous peak window",
        "missing metric row invalidates only windows containing that gap",
        "insufficient complete history returns unavailable instead of shrinking window",
    ),
    "lib/services/nba_player_career_comparison_distribution_engine.dart": (
        "class NbaPlayerCareerComparisonDistributionEngine",
        "This is descriptive only",
        "missing: values.length - observed.length",
        "standardDeviation",
    ),
    "test/nba_player_career_comparison_distribution_engine_test.dart": (
        "computes descriptive observed distributions without normalization",
        "missing values remain missing and do not become zero observations",
        "shared-only scope changes distribution sample rather than imputing gaps",
    ),
    "lib/services/nba_player_career_season_type_delta_engine.dart": (
        "class NbaPlayerCareerSeasonTypeDeltaEngine",
        "it is not a postseason uplift",
        "playoffMinusRegular",
        "deltaDifference",
    ),
    "test/nba_player_career_season_type_delta_engine_test.dart": (
        "reports independent observed regular and playoff means",
        "missing playoff sample remains unavailable rather than zero",
        "season samples are not required to share calendar years",
    ),
    "lib/services/nba_player_career_comparison_preset_catalog.dart": (
        "class NbaPlayerCareerComparisonPresetCatalog",
        "they do not assign weights, composite scores, rankings or",
        "shared-prime",
        "career-year",
    ),
    "test/nba_player_career_comparison_preset_catalog_test.dart": (
        "presets never duplicate a metric inside the same view",
        "shared-season preset is calendar aligned",
        "career-year preset stays ordinal and does not claim shared seasons",
    ),
    "lib/services/nba_player_career_comparison_state_store.dart": (
        "class NbaPlayerCareerComparisonStateStore",
        "recents",
        "saved",
        ".take(20)",
        ".take(50)",
    ),
    "test/nba_player_career_comparison_state_store_test.dart": (
        "records comparison recents with exact analyst configuration",
        "saved comparisons toggle independently from recents",
        "round trip preserves alignment metric and preset identity",
    ),
    "lib/services/nba_player_career_comparison_watch_service.dart": (
        "class NbaPlayerCareerComparisonWatchService",
        "kind: 'player-career-comparison'",
        "comparison.left.playerKey",
        "comparison.right.playerKey",
        "sharedOnly ? 'shared' : 'all'",
    ),
    "test/nba_player_career_comparison_watch_service_test.dart": (
        "watch identity preserves directional players and analyst scope",
        "shared and all-season watches are distinct",
        "reversing players creates a distinct directional comparison watch",
    ),
    "lib/services/nba_player_career_comparison_research_store.dart": (
        "class NbaPlayerCareerComparisonResearchStore",
        "Both canonical Player keys are required",
        "sharedOnly",
        "presetId",
    ),
    "test/nba_player_career_comparison_research_store_test.dart": (
        "activates and reloads exact comparison research configuration",
        "activation requires both canonical Player keys",
        "clear removes active comparison research checkpoint",
    ),
    "lib/services/nba_player_career_comparison_export_service.dart": (
        "class NbaPlayerCareerComparisonExportService",
        "String get tsv",
        "String get csv",
        "String get json",
        "'normalization': 'none'",
    ),
    "test/nba_player_career_comparison_export_service_test.dart": (
        "export preserves aligned rows, metric nulls and metadata boundary",
        "JSON export is structured and machine readable",
        "shared-only export contains only already-scoped rows",
    ),
    "lib/widgets/nba_player_career_comparison_matrix_panel.dart": (
        "career-comparison-multi-metric-matrix",
        "MULTI-METRIC SEASON MATRIX",
        "no composite score",
    ),
    "lib/widgets/nba_player_career_peak_window_panel.dart": (
        "career-comparison-peak-window",
        "PEAK WINDOW LAB",
        "No missing-season interpolation, era normalization, age matching",
    ),
    "lib/widgets/nba_player_career_comparison_distribution_panel.dart": (
        "career-comparison-distribution-panel",
        "SEASON DISTRIBUTION PROFILE",
        "population σ over observed rows only",
    ),
    "lib/widgets/nba_player_career_season_type_delta_panel.dart": (
        "career-comparison-season-type-delta",
        "REGULAR SEASON ↔ PLAYOFFS",
        "not matched-year or opponent-adjusted",
    ),
    "lib/widgets/nba_player_career_comparison_state_panel.dart": (
        "career-comparison-state-panel",
        "RESEARCH PRESETS & RECENTS",
        "They do not apply weights, rankings or era adjustments",
    ),
    "lib/widgets/nba_player_career_comparison_workflow_state_panel.dart": (
        "career-comparison-workflow-state-panel",
        "SAVE COMPARISON",
        "WATCH COMPARISON",
        "ACTIVATE RESEARCH",
    ),
    "lib/widgets/nba_player_career_comparison_export_panel.dart": (
        "career-comparison-export-panel",
        "COPY TSV",
        "COPY CSV",
        "COPY JSON",
    ),
    "lib/widgets/nba_player_career_comparison_research_workbench.dart": (
        "class NbaPlayerCareerComparisonResearchWorkbench",
        "career-comparison-research-workbench",
        "career-comparison-shared-season-filter",
        "career-comparison-peak-window-size",
        "NbaPlayerCareerSeasonTypeDeltaEngine().build",
        "NbaPlayerCareerComparisonExportService().build",
    ),
    "lib/screens/product_nba_player_career_comparison_screen.dart": (
        "initialAlignment",
        "initialMetric",
        "NbaPlayerCareerComparisonResearchWorkbench(",
        "_restoreComparison",
    ),
    "lib/widgets/nba_player_career_comparison_navigation.dart": (
        "'alignment': initialAlignment.name",
        "'metric': initialMetric.name",
        "initialAlignment: initialAlignment",
        "initialMetric: initialMetric",
    ),
    "lib/widgets/nba_season_analytics_panel.dart": (
        "season-leader-career-",
        "Open canonical historical Player Career",
        "openResolvedNbaPlayerCareerPage(",
    ),
    "lib/widgets/nba_franchise_navigation.dart": (
        "Historical Player rows default to the permanent Career object",
        "final playerCallback = onOpenPlayer ?? openCareerPlayer",
        "openNbaPlayerCareerPage(",
    ),
    "lib/widgets/nba_player_career_comparison_history_dialog.dart": (
        "showNbaPlayerCareerComparisonHistory(",
        "CAREER COMPARISON HISTORY",
        "Saved and recent comparisons involving this canonical Player",
        "initialAlignment: item.alignment",
        "initialMetric: item.metric",
    ),
    "lib/widgets/nba_player_career_navigation.dart": (
        "player-career-comparison-history",
        "player-career-comparison-modes",
        "Compare by career year",
        "Compare TS% by season",
        "showNbaPlayerCareerComparisonHistory(",
    ),
    "test/nba_player_career_cross_platform_convergence_test.dart": (
        "Season leaders expose dedicated historical Career actions",
        "Player Career app bar exposes compare modes and comparison history",
        "career-year mode opens comparison route with explicit route state",
    ),
    "test/nba_player_career_comparison_research_workbench_test.dart": (
        "permanent comparison mounts the full research workbench",
        "shared-season filter narrows matrix to exact overlap",
        "save watch and research controls persist comparison identity",
    ),
    "test/nba_player_career_comparison_history_dialog_test.dart": (
        "history dialog filters saved and recent comparisons by Player",
        "unfiltered history exposes global recent comparison state",
        "empty filtered history renders explicit no-match state",
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/nba_platform_graph_v16.json")
    args = parser.parse_args()

    legacy_output = ROOT / "artifacts/nba_platform_graph_v15.json"
    legacy = subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools/audit_nba_platform_graph_v15.py"),
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
            "path": "tools/audit_nba_platform_graph_v15.py",
            "missing": "legacy-v15-contract-pass",
        })

    payload = {
        "contract": "canonical-player-career-comparison-research-convergence-v16-all-era",
        "legacy_contract": legacy_payload.get("contract", "v15-unavailable"),
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
