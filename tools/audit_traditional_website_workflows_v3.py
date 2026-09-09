from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

ASSERTIONS: dict[str, tuple[str, ...]] = {
    "lib/widgets/traditional_website_shell_impl.dart": (
        "WebsiteNbaHomeDashboard",
        "Home",
        "Stats",
        "Advanced Stats",
        "Lineup Analysis",
        "Trade Machine",
        "Games",
        "Team Compare",
        "Watchlist",
        "Front Office",
        "Research",
        "Community",
        "Python Lab · detached",
        "Excel Workspace · detached",
        "maxWidth: 1840",
    ),
    "lib/widgets/website_sticky_stats_table.dart": (
        "Conventional, borderless website statistics table",
        "The page owns all vertical scrolling",
        "scrollDirection: Axis.horizontal",
        "first column stays frozen horizontally",
        "There are deliberately no per-cell divider rules",
    ),
    "lib/screens/website_nba_stats_screen.dart": (
        "values: const [0, 65, 60, 50, 40, 30]",
        "values: const [0, 20, 15, 10]",
        "WebsiteStickyStatsTable",
        "Regular Season",
        "Playoffs",
        "Copy CSV",
    ),
    "lib/screens/website_nba_advanced_stats_screen.dart": (
        "values: const [0, 65, 60, 50, 40, 30]",
        "values: const [0, 20, 15, 10]",
        "3P DFG% is the opponent",
        "never substituted with the player’s offensive 3P%",
        "WebsiteStickyStatsTable",
        "Regular Season",
        "Playoffs",
    ),
    "lib/screens/website_nba_lineup_analysis_screen.dart": (
        "Lineup Analysis",
        "Regular Season",
        "Playoffs",
        "Unit size",
        "Search players in lineups",
        "LeagueDashLineups",
        "Copy CSV",
    ),
    "lib/screens/website_nba_game_finder_screen.dart": (
        "Game Finder",
        "Regular Season",
        "Playoffs",
        "Static historical catalog",
        "Copy CSV",
        "gameDetail",
        "gamePlayByPlay",
        "Sports Terminal does not invent missing events",
        "Player box score",
        "Play-by-play",
    ),
    "lib/screens/website_nba_team_compare_screen.dart": (
        "Team Compare",
        "Maximum 4 teams selected",
        "Regular Season",
        "Playoffs",
        "Overview",
        "Shooting",
        "Possession",
        "Advanced",
        "Copy CSV",
    ),
    "lib/screens/website_nba_watchlist_screen.dart": (
        "Watchlist",
        "sports_terminal.website.watchlist.players.v1",
        "sports_terminal.website.watchlist.teams.v1",
        "openWebsiteNbaPlayerPage",
        "openWebsiteNbaTeamPage",
        "local to this browser",
    ),
    "lib/services/website_nba_api_service.dart": (
        "Future<List<Map<String, dynamic>>> games",
        "gameDetail",
        "gamePlayByPlay",
        "Filtering happens locally",
        "never requires a runtime",
    ),
}

FORBIDDEN: dict[str, tuple[str, ...]] = {
    "lib/widgets/website_sticky_stats_table.dart": (
        "scrollDirection: Axis.vertical",
        "horizontalInside:",
        "verticalInside:",
    ),
    "lib/screens/website_nba_advanced_stats_screen.dart": (
        "three_dfg_pct', '3P%'",
        "three_dfg_pct\", \"3P%\"",
    ),
    "lib/widgets/traditional_website_shell_impl.dart": (
        "builder: (_, _) => const ProductNbaHubV2Screen()",
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument(
        "--json",
        default="artifacts/traditional_website_workflows_v3.json",
    )
    args = parser.parse_args()

    failures: list[dict[str, str]] = []
    assertions = 0
    passed = 0

    for relative, tokens in ASSERTIONS.items():
        path = ROOT / relative
        if not path.is_file():
            failures.append({"path": relative, "problem": "file missing"})
            continue
        text = path.read_text(encoding="utf-8")
        for token in tokens:
            assertions += 1
            if token in text:
                passed += 1
            else:
                failures.append({"path": relative, "problem": f"missing: {token}"})

    for relative, tokens in FORBIDDEN.items():
        path = ROOT / relative
        if not path.is_file():
            failures.append({"path": relative, "problem": "file missing"})
            continue
        text = path.read_text(encoding="utf-8")
        for token in tokens:
            assertions += 1
            if token not in text:
                passed += 1
            else:
                failures.append({"path": relative, "problem": f"forbidden: {token}"})

    payload = {
        "contract": "sports-terminal-traditional-website-workflows-v3",
        "assertions": assertions,
        "passed": passed,
        "failed": len(failures),
        "failures": failures,
    }
    output = ROOT / args.json
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    print(
        f"Traditional website workflow audit: {passed}/{assertions} passed; "
        f"{len(failures)} failures"
    )
    for failure in failures:
        print(f"  {failure['path']}: {failure['problem']}")

    if args.check and failures:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
