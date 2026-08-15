from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EXTRA_CONTRACTS: dict[str, tuple[str, ...]] = {
    "lib/services/nba_franchise_intelligence_engine.dart": (
        "class NbaFranchiseIntelligenceEngine",
        "class NbaFranchiseIntelligenceSnapshot",
        "class NbaFranchiseTeamIdentity",
        "class NbaFranchiseSeasonObservation",
        "seasonRangeLabel",
        "ERA NOT EXPOSED",
        "does not infer relocations",
    ),
    "test/nba_franchise_intelligence_engine_test.dart": (
        "projects canonical franchise identity, lineage and season history",
        "computes win percentage only from explicit wins and losses",
        "malformed identity and season rows never become fake franchise history",
        "missing lineage and season summaries stay explicitly unavailable",
    ),
    "lib/services/nba_franchise_performance_engine.dart": (
        "class NbaFranchisePerformanceEngine",
        "class NbaFranchisePerformanceResult",
        "class NbaFranchisePerformanceSeason",
        "weightedWinPct",
        "bestSeason",
        "worstSeason",
        "playoffRowsExcluded",
        "championships and advancement are not inferred",
    ),
    "test/nba_franchise_performance_engine_test.dart": (
        "aggregates regular-season performance across canonical franchise identities",
        "same-season identity rows are combined without inventing extra seasons",
        "rows without decisions remain visible but do not create fake win percentage",
    ),
    "lib/services/nba_franchise_player_history_engine.dart": (
        "class NbaFranchisePlayerHistoryEngine",
        "class NbaFranchisePlayerHistoryResult",
        "class NbaFranchisePlayerHistoryRow",
        "bounded notable-player rows",
        "missingTeamDossiers",
        "completeAcrossRequestedIdentities",
        "not an exhaustive all-player ledger",
    ),
    "test/nba_franchise_player_history_engine_test.dart": (
        "aggregates bounded notable-player rows across franchise team identities",
        "missing team dossiers remain explicit coverage gaps",
        "malformed player rows are discarded rather than fabricated",
    ),
    "lib/services/nba_franchise_workflow_service.dart": (
        "class NbaFranchiseWorkflowService",
        "sourceObjectType: 'NBA Franchise'",
        "'row_type': 'team_identity'",
        "'row_type': 'season'",
        "'row_type': 'player_history'",
        "kind: 'franchise'",
        "not-exposed-at-franchise-scope",
        "activateHistorical(",
    ),
    "test/nba_franchise_workflow_service_test.dart": (
        "packages canonical franchise lineage, seasons and bounded player history",
        "missing usable franchise rows packages partial state",
        "canonical Franchise watch identity persists independently",
        "research activation is pinned to the last explicitly exposed franchise season",
    ),
    "lib/screens/product_nba_franchise_screen.dart": (
        "class ProductNbaFranchiseScreen",
        "FRANCHISE WORKFLOWS",
        "FRANCHISE WIN% HISTORY",
        "CANONICAL TEAM IDENTITY LINEAGE",
        "REGULAR-SEASON HISTORY",
        "BOUNDED FRANCHISE PLAYER HISTORY",
        "franchise-source-boundary",
        "franchise-route-workspace",
        "franchise-route-python",
        "franchise-route-compare",
        "franchise-route-source-audit",
        "NbaTerminalTrendChart",
    ),
    "lib/widgets/nba_franchise_navigation.dart": (
        "openNbaFranchisePage(",
        "'/nba/franchises/",
        "ProductNbaFranchiseScreen(",
        "openHistoricalNbaSeasonPage(",
        "franchiseKey",
    ),
    "lib/widgets/nba_team_game_log_panel.dart": (
        "team-open-franchise-",
        "NbaEntityIntelligenceRepository().teamDossier",
        "openNbaFranchisePage(",
        "franchise_key",
    ),
    "test/nba_franchise_navigation_test.dart": (
        "permanent Franchise route mounts lineage, performance and player history",
        "partial Team dossier coverage remains visible on the Franchise route",
        "nba-franchise-fr_alpha",
        "franchise-team-alpha",
        "franchise-player-p1",
        "franchise-source-boundary",
    ),
    "lib/services/nba_entity_intelligence_repository.dart": (
        "'player', 'team', 'franchise', 'season', 'game'",
        "franchiseDossier(",
        "'/v2/nba/history/franchises/",
    ),
    "backend/app/historical_nba_entity_api.py": (
        "@router.get(\"/franchises/{franchise_key}/dossier\")",
        "def historical_franchise_dossier(",
        '"team_identities": identities',
        '"seasons": seasons',
    ),
    "lib/screens/product_nba_terminal_screen.dart": (
        "'franchise' => row['franchise_key']",
        "future = _entities.franchiseDossier(key)",
        "kind == 'franchise'",
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/nba_platform_graph_v13.json")
    args = parser.parse_args()

    legacy_output = ROOT / "artifacts/nba_platform_graph_v12.json"
    legacy = subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools/audit_nba_platform_graph_v12.py"),
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
            "path": "tools/audit_nba_platform_graph_v12.py",
            "missing": "legacy-v12-contract-pass",
        })

    payload = {
        "contract": "canonical-player-team-game-event-trends-season-franchise-v13-all-era",
        "legacy_contract": legacy_payload.get("contract", "v12-unavailable"),
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
