from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EXTRA_CONTRACTS: dict[str, tuple[str, ...]] = {
    "lib/services/nba_player_career_engine.dart": (
        "class NbaPlayerCareerEngine",
        "class NbaPlayerCareerSnapshot",
        "class NbaPlayerCareerSeason",
        "class NbaPlayerCareerTenure",
        "completeTeamFranchiseCoverage",
        "multiTeamAggregateSeasons",
        "never reconstructs traded-team stints",
    ),
    "test/nba_player_career_engine_test.dart": (
        "projects canonical Player identity, career rows and source-backed tenure",
        "multi-team aggregate stays visible without inventing Team or Franchise",
        "missing Team dossiers remain explicit tenure coverage gaps",
        "missing totals remain null instead of becoming zero career production",
        "malformed season rows never become synthetic career history",
    ),
    "lib/services/nba_player_career_analytics_engine.dart": (
        "enum NbaPlayerCareerMetric",
        "class NbaPlayerCareerAnalyticsEngine",
        "class NbaPlayerCareerDistribution",
        "rollingValue",
        "no interpolation, smoothing, or replacement values",
    ),
    "test/nba_player_career_analytics_engine_test.dart": (
        "builds observed career PPG trend and complete rolling windows",
        "missing values remain gaps and distribution counts them explicitly",
        "percentage metrics stay source-backed and render in percentage points",
        "advanced metrics are not backfilled when the season omits them",
    ),
    "lib/services/nba_player_career_context_engine.dart": (
        "class NbaPlayerCareerContextEngine",
        "class NbaPlayerCareerAward",
        "class NbaPlayerCareerAllStarSelection",
        "class NbaPlayerCareerDraftRecord",
        "class NbaPlayerCareerGameRecord",
        "AWARDS NOT EXPOSED",
        "draft position, and Game",
    ),
    "test/nba_player_career_context_engine_test.dart": (
        "projects only explicit awards All-Star draft and Game rows",
        "missing award context stays unavailable instead of inferring accolades",
        "starter status remains null when source row does not expose it",
        "draft fields remain unknown rather than being reconstructed",
    ),
    "lib/services/nba_player_career_workflow_service.dart": (
        "class NbaPlayerCareerWorkflowService",
        "sourceObjectType: 'NBA Player Career'",
        "'row_type': 'career_season'",
        "'row_type': 'team_tenure'",
        "'row_type': 'award'",
        "'row_type': 'draft'",
        "'row_type': 'recent_game'",
        "kind: 'player-career'",
        "activateHistorical(",
    ),
    "test/nba_player_career_workflow_service_test.dart": (
        "packages canonical career seasons, tenure and source-backed context",
        "empty career packages Partial without synthesizing rows",
        "canonical Player career watch identity persists independently",
        "research activation pins exact Player and last exposed season",
    ),
    "lib/screens/product_nba_player_career_screen.dart": (
        "class ProductNbaPlayerCareerScreen",
        "NBA / HISTORICAL PLAYER CAREER",
        "CAREER TREND & DISTRIBUTION",
        "TEAM / FRANCHISE TENURE",
        "SEASON-BY-SEASON CAREER",
        "AWARDS & ALL-STAR EVIDENCE",
        "DRAFT PROVENANCE",
        "RECENT SOURCE-BACKED GAMES",
        "player-career-source-boundary",
        "player-career-route-workspace",
        "player-career-route-python",
        "player-career-route-compare",
        "player-career-route-source-audit",
        "NbaTerminalTrendChart",
    ),
    "lib/widgets/nba_player_career_navigation.dart": (
        "openNbaPlayerCareerPage(",
        "openResolvedNbaPlayerCareerPage(",
        "'/nba/history/players/",
        "ProductNbaPlayerCareerScreen(",
        "openHistoricalNbaSeasonPage(",
        "loadHistoricalSeason(",
        "openNbaFranchisePage(",
        "No canonical historical Player identity was resolved",
    ),
    "lib/widgets/nba_player_game_log_panel.dart": (
        "player-open-career-",
        "OPEN HISTORICAL CAREER",
        "openResolvedNbaPlayerCareerPage(",
        "NbaPlayerTrendPanel(",
    ),
    "test/nba_player_career_navigation_test.dart": (
        "permanent historical Player route mounts career analytics and linked context",
        "missing Team dossier remains visible as tenure coverage gap",
        "permanent historical Player route has stable canonical path",
        "nba-player-career-p1",
        "career-team-alpha",
        "career-franchise-fr_alpha",
        "career-season-2020-21",
        "career-game-g1",
        "'/nba/history/players/p1'",
    ),
    "lib/services/nba_entity_intelligence_repository.dart": (
        "playerDossier(",
        "'/v2/nba/history/players/",
        "season_type",
        "recent_games",
    ),
    "backend/app/historical_nba_entity_api.py": (
        "@router.get(\"/players/{player_key}/dossier\")",
        "def historical_player_dossier(",
        '"awards": awards',
        '"all_star": all_star',
        '"draft": draft',
        '"recent_games": games',
    ),
    "lib/screens/product_nba_terminal_screen.dart": (
        "'player' => row['player_key']",
        "future = _entities.playerDossier(key)",
        "playerKey: kind == 'player'",
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/nba_platform_graph_v14.json")
    args = parser.parse_args()

    legacy_output = ROOT / "artifacts/nba_platform_graph_v13.json"
    legacy = subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools/audit_nba_platform_graph_v13.py"),
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
            "path": "tools/audit_nba_platform_graph_v13.py",
            "missing": "legacy-v13-contract-pass",
        })

    payload = {
        "contract": "canonical-player-career-team-franchise-game-season-v14-all-era",
        "legacy_contract": legacy_payload.get("contract", "v13-unavailable"),
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
