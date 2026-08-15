from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EXTRA_CONTRACTS: dict[str, tuple[str, ...]] = {
    "lib/services/nba_season_awards_voting_engine.dart": (
        "class NbaSeasonAwardsVotingEngine",
        "class NbaSeasonAwardsVotingResult",
        "class NbaSeasonAwardVotingGroup",
        "explicitWinner",
        "hasVoteDetail",
        "winner: _awardBool",
    ),
    "test/nba_season_awards_voting_engine_test.dart": (
        "groups source-backed award rows without inferring winners",
        "preserves only explicit voting detail and source metadata",
        "winner ordering does not manufacture rank or voting fields",
        "malformed award rows remain absent",
    ),
    "lib/services/nba_season_draft_class_engine.dart": (
        "class NbaSeasonDraftClassEngine",
        "class NbaSeasonDraftClassResult",
        "class NbaSeasonDraftClassRow",
        "draftYears",
        "rowsWithoutPickNumber",
        "pickLabel",
        "roundLabel",
    ),
    "test/nba_season_draft_class_engine_test.dart": (
        "orders exact source-backed draft rows by explicit year and pick",
        "season id never implies or filters a draft year",
        "missing round and pick remain unknown rather than inferred",
        "malformed rows do not become synthetic draft selections",
    ),
    "lib/services/nba_season_all_star_engine.dart": (
        "class NbaSeasonAllStarEngine",
        "class NbaSeasonAllStarResult",
        "class NbaSeasonAllStarRow",
        "explicitStarters",
        "selectionType",
        "statusLabel => starter ? 'STARTER' : 'SELECTED'",
    ),
    "test/nba_season_all_star_engine_test.dart": (
        "keeps explicit starters separate from generic selections",
        "preserves optional conference roster and selection labels exactly",
        "non-starter rows are not relabeled as reserves",
        "malformed All-Star rows remain absent",
    ),
    "lib/services/nba_season_leader_matrix_engine.dart": (
        "class NbaSeasonLeaderMatrixEngine",
        "class NbaSeasonLeaderMatrixResult",
        "class NbaSeasonLeaderMatrixPlayer",
        "NbaSeasonPlayerLeaderEngine",
        "minimumGames",
        "bestRank",
        "uniqueMetrics",
    ),
    "test/nba_season_leader_matrix_engine_test.dart": (
        "builds union of explicit top-N leaders across selected metrics",
        "keeps Regular Season and Playoffs as separate matrix scopes",
        "minimum-games qualification applies independently to every column",
        "missing metric evidence leaves cells absent rather than synthesized",
        "duplicate requested metrics create one matrix column",
    ),
    "lib/services/nba_season_rest_density_engine.dart": (
        "class NbaSeasonRestDensityEngine",
        "class NbaSeasonRestDensityResult",
        "class NbaSeasonRestDensityTeamProfile",
        "backToBacks",
        "oneDayRestOccurrences",
        "maxGamesInSevenDays",
        "fourPlusInSixDayWindows",
        "game.parsedDate",
    ),
    "test/nba_season_rest_density_engine_test.dart": (
        "derives back-to-back and rest intervals from explicit calendar dates",
        "scheduled dated games count toward density without becoming results",
        "undated games remain coverage gaps and never create rest intervals",
        "season and postseason scopes stay isolated",
        "date-only model does not invent rest when fewer than two dates exist",
    ),
    "lib/widgets/nba_season_operations_panel.dart": (
        "class NbaSeasonOperationsPanel",
        "season-operations-workbench",
        "SEASON OPERATIONS INTELLIGENCE",
        "MULTI-METRIC LEADER MATRIX",
        "DATE-ONLY REST + SCHEDULE DENSITY",
        "AWARDS + VOTING",
        "ALL-STAR SELECTIONS",
        "DRAFT CLASS CONTEXT",
        "season-leader-top-n",
        "season-leader-min-games",
        "season-rest-team-",
        "loadContext",
    ),
    "lib/services/nba_season_workflow_service.dart": (
        "'row_type': 'standing'",
        "'row_type': 'game'",
        "'row_type': 'leader'",
        "'row_type': 'rest_density'",
        "'standingRows'",
        "'gameRows'",
        "'leaderRows'",
        "'restDensityRows'",
        "NbaSeasonLeaderMatrixEngine",
        "NbaSeasonRestDensityEngine",
    ),
    "test/nba_season_workflow_service_test.dart": (
        "packages canonical season operating rows into shared RoutePayload state",
        "season export preserves scheduled games without inventing scores",
        "restDensityRows",
        "empty season scope is partial instead of fabricating operating rows",
    ),
    "lib/widgets/nba_player_game_log_panel.dart": (
        "player-open-season-",
        "openNbaSeasonPage(",
        "seasonId: seed.supportedSeason",
        "loadSeed: () async => seed",
    ),
    "lib/widgets/nba_team_game_log_panel.dart": (
        "team-open-season-",
        "openNbaSeasonPage(",
        "seasonId: seed.supportedSeason",
        "loadSeed: () async => seed",
    ),
    "lib/screens/product_nba_season_screen.dart": (
        "NbaSeasonOperationsPanel(",
        "loadContext: widget.loadSourceContext",
        "onOpenPlayer: widget.onOpenPlayer",
        "onOpenTeam: widget.onOpenTeam",
        "awards/voting",
        "date-only schedule density",
    ),
    "test/nba_season_operations_convergence_test.dart": (
        "permanent Season route mounts source-backed operations intelligence",
        "season-operations-workbench",
        "Player game-log surface exposes exact active Season backlink",
        "player-open-season-p1",
        "Team game-log surface exposes exact active Season backlink",
        "team-open-season-AAA",
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/nba_platform_graph_v12.json")
    args = parser.parse_args()

    legacy_output = ROOT / "artifacts/nba_platform_graph_v11.json"
    legacy = subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools/audit_nba_platform_graph_v11.py"),
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
            "path": "tools/audit_nba_platform_graph_v11.py",
            "missing": "legacy-v11-contract-pass",
        })

    payload = {
        "contract": "canonical-player-team-game-event-trends-season-operations-v12-all-era",
        "legacy_contract": legacy_payload.get("contract", "v11-unavailable"),
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
