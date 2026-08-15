from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EXTRA_CONTRACTS: dict[str, tuple[str, ...]] = {
    "lib/services/nba_game_event_batch_route_service.dart": (
        "class NbaGameEventBatchRouteService",
        "NBA Game Event Selection",
        "filtered-canonical-game-events",
        "event-game-mismatch",
        "filterSummary: result.filterSummary",
        "matchedEvents",
        "queryTruncated",
    ),
    "lib/widgets/nba_game_event_batch_export_panel.dart": (
        "class NbaGameEventBatchExportPanel",
        "EVENT EXPLORER / BATCH EXPORT",
        "event-batch-export-search",
        "event-batch-export-category",
        "event-batch-export-team",
        "event-batch-export-period",
        "event-batch-export-scoring",
        "event-batch-export-close",
        "event-batch-export-substitutions",
        "event-batch-route-",
        "onRouteSelection",
        "Workspace",
        "Python Lab",
        "Source Audit",
    ),
    "lib/screens/product_nba_game_terminal_screen.dart": (
        "NbaGameEventBatchExportPanel(",
        "NbaGameEventBatchRouteService",
        "_routeEventSelection(",
        "NBA Game Event Explorer Batch",
        "RoutePayloadScope.maybeOf(context)",
    ),
    "lib/services/nba_player_trend_engine.dart": (
        "class NbaPlayerTrendEngine",
        "enum NbaPlayerTrendMetric",
        "class NbaPlayerTrendResult",
        "class NbaPlayerTrendObservation",
        "rollingAverage",
        "recentFiveAverage",
        "priorFiveAverage",
        "unlinkedRows",
        "linkedCanonicalGame",
    ),
    "lib/services/nba_team_trend_engine.dart": (
        "class NbaTeamTrendEngine",
        "enum NbaTeamTrendMetric",
        "class NbaTeamTrendResult",
        "class NbaTeamTrendObservation",
        "rollingAverage",
        "recentRecord",
        "currentStreak",
        "where((row) => row.hasScore)",
    ),
    "lib/widgets/nba_terminal_trend_chart.dart": (
        "class NbaTerminalTrendChart",
        "class NbaTerminalTrendPoint",
        "Missing rows remain gaps",
        "CustomPaint",
        "ROLLING AVG",
    ),
    "lib/widgets/nba_player_trend_panel.dart": (
        "class NbaPlayerTrendPanel",
        "PLAYER TREND LAB",
        "player-trend-metric",
        "player-trend-window",
        "player-trend-open-",
        "NbaTerminalTrendChart",
    ),
    "lib/widgets/nba_player_game_log_panel.dart": (
        "NbaPlayerTrendPanel(",
        "playerId: playerId",
        "seasonType: seasonType",
        "onOpenGame: onOpenGame",
    ),
    "lib/widgets/nba_team_trend_panel.dart": (
        "class NbaTeamTrendPanel",
        "TEAM TREND LAB",
        "team-trend-metric",
        "team-trend-window",
        "team-trend-open-",
        "NbaTerminalTrendChart",
    ),
    "lib/widgets/nba_team_game_log_panel.dart": (
        "NbaTeamTrendPanel(",
        "teamId: teamId",
        "seasonType: seasonType",
        "onOpenGame: onOpenGame",
    ),
    "lib/services/nba_season_intelligence_engine.dart": (
        "class NbaSeasonIntelligenceEngine",
        "class NbaSeasonIntelligenceSnapshot",
        "class NbaSeasonTeamStanding",
        "_normalize(row.seasonId) == normalizedSeason",
        "if (!game.hasScore) continue",
        "regularSeasonGames",
        "playoffGames",
        "dateRangeLabel",
    ),
    "lib/screens/product_nba_season_screen.dart": (
        "class ProductNbaSeasonScreen",
        "NBA / SEASON",
        "SEASON STANDINGS",
        "SEASON GAME INVENTORY",
        "season-type-filter",
        "season-team-",
        "season-game-",
        "season-open-schedule",
        "NbaSeasonIntelligenceEngine",
    ),
    "lib/widgets/nba_game_navigation.dart": (
        "openNbaSeasonPage(",
        "'/nba/seasons/",
        "ProductNbaSeasonScreen(",
        "open-nba-season",
        "schedule-open-nba-season",
        "_openActiveSeason(",
        "seed.supportedSeason",
    ),
    "test/nba_game_event_batch_route_service_test.dart": (
        "packages exactly the filtered canonical event selection",
        "empty filtered selections remain explicit partial packages",
        "blocks a selection containing an event from another parent game",
    ),
    "test/nba_player_trend_engine_test.dart": (
        "builds chronological raw and rolling player trend observations",
        "retains missing metric observations as visible gaps",
        "keeps regular season and playoffs separated",
    ),
    "test/nba_team_trend_engine_test.dart": (
        "builds chronological team differential and rolling trend",
        "excludes unscored future games from performance trends",
        "keeps playoffs separate from regular season",
    ),
    "test/nba_season_intelligence_engine_test.dart": (
        "isolates one canonical season and derives scored-game standings",
        "scheduled games never alter derived records",
        "season id prevents cross-season game leakage",
    ),
    "test/nba_season_navigation_test.dart": (
        "opens canonical season route with standings and game inventory",
        "season team links preserve canonical team callback",
        "season game inventory reopens canonical permanent game route",
        "season can hand off to full NBA schedule",
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/nba_platform_graph_v9.json")
    args = parser.parse_args()

    legacy_output = ROOT / "artifacts/nba_entity_link_audit_v8.json"
    legacy = subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools/audit_nba_entity_links.py"),
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
            "path": "tools/audit_nba_entity_links.py",
            "missing": "legacy-v8-contract-pass",
        })

    payload = {
        "contract": "canonical-player-team-game-event-trends-season-v9-all-era",
        "legacy_contract": legacy_payload.get("contract", "v8-unavailable"),
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
