from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CONVERGENCE_ASSERTIONS: dict[str, tuple[str, ...]] = {
    "lib/widgets/app_entry_gate.dart": (
        "TraditionalWebsiteShellV2",
    ),
    "lib/widgets/traditional_website_shell_v2.dart": (
        "Home",
        "Stats",
        "Advanced Stats",
        "Trade Machine",
        "Search players & teams",
        "WebsiteNbaHomeDashboard",
        "WebsiteNbaStatsScreen",
        "WebsiteNbaAdvancedStatsScreen",
        "WebsiteTradeMachineScreen",
    ),
    "lib/services/website_nba_api_service.dart": (
        "WebsiteNbaStaticRepository",
        "Historical basketball data is now a static website concern",
        "FastAPI request",
        "runtime SQLite query",
        "current-season overlays",
    ),
    "lib/services/website_nba_static_repository.dart": (
        "data/nba_static",
        "seasonSnapshot",
        "playerDossier",
        "teamDossier",
        "gameDetail",
        "gamePlayByPlay",
        "searchEntities",
        "history/awards.json",
        "history/all_star.json",
        "history/draft.json",
        "history/coverage.json",
    ),
    "tools/build_static_nba_website_data_v2.py": (
        "sports-terminal-static-nba-website-v2",
        "players/index.json",
        "teams/index.json",
        "games/index.json",
        "history/awards.json",
        "history/all_star.json",
        "history/draft.json",
        "historical_http_api_required",
        "sqlite_required_by_browser",
        "live_overlay_supported",
        "correlated aggregates",
    ),
    "tools/build_static_nba_game_data.py": (
        "sports-terminal-static-game-v1",
        "sports-terminal-static-pbp-v1",
        "canon_fact_play_by_play",
        "coverage_is_source_bounded",
    ),
    "lib/screens/website_nba_home_dashboard.dart": (
        "NBA Dashboard",
        "League leaders",
        "Teams",
        "openWebsiteNbaPlayerPage",
        "openWebsiteNbaTeamPage",
    ),
    "lib/screens/website_nba_stats_screen.dart": (
        "NBA Stats",
        "Regular Season",
        "Playoffs",
        "Search players",
        "Team",
        "Position",
        "GP",
        "MPG",
        "PPG",
        "RPG",
        "APG",
        "SPG",
        "BPG",
        "TOV",
        "FG%",
        "3P%",
        "FT%",
        "DataTable",
        "openWebsiteNbaPlayerPage",
        "openWebsiteNbaTeamPage",
    ),
    "lib/screens/website_nba_advanced_stats_screen.dart": (
        "Advanced Stats",
        "Shooting & Efficiency",
        "Playmaking & Creation",
        "Defense",
        "Rebounding",
        "Impact",
        "Rate Adjusted",
        "Clutch",
        "Gravity & Spacing",
        "On / Off",
        "Lineups & Play Types",
        "will not manufacture values",
    ),
    "lib/screens/website_nba_entity_pages.dart": (
        "WebsiteNbaPlayerPage",
        "WebsiteNbaTeamPage",
        "Career statistics",
        "Contract",
        "Awards & honors",
        "Recent games",
        "Season history",
    ),
    "lib/screens/website_trade_machine_screen.dart": (
        "NBA Trade Machine",
        "TradeMachineEngine",
        "Draft assets",
        "salary_source",
        "Trade passes modeled structural checks",
        "Final execution still requires authoritative current contracts",
    ),
    "lib/services/front_office_registry_service.dart": (
        "Cache-first product read",
        "loadRemote",
        "loadCached",
    ),
    "scripts/open_terminal.sh": (
        "data/warehouse/nba_history.sqlite",
        "SPORTS_TERMINAL_NBA_HISTORY_DB",
        "build_historical_nba_canonical.py",
        "build_static_nba_website_data_v2.py",
        "build_static_nba_game_data.py",
        "--materialize-pbp",
        "web/data/nba_static",
        "Historical NBA pages are served from static files, not the API.",
    ),
    ".gitignore": (
        "/web/data/nba_static/",
    ),
    "docs/static_nba_website_architecture.md": (
        "static base + live overlay",
        "--materialize-pbp",
        "does not claim possession-level PBP",
    ),
    "lib/widgets/blueprint_terminal_frame.dart": (
        "TerminalCommandBar",
        "TerminalStatusBar",
        "TerminalDensityService",
        "ProductNbaTerminalScreen",
        "ProductTradeMachineScreen",
        "ProductPythonDevLabScreen",
        "ExcelLikeWorkspaceScreen",
    ),
    "lib/widgets/sports_terminal_operating_shell.dart": (
        "TerminalContextRail",
        "TerminalIntelligenceRail",
        "TerminalDensitySelector",
    ),
    "docs/sports_terminal_blueprint_status.json": (
        '"sports-terminal-master-blueprint-v1"',
        '"official_live_nba_feed": "rights-blocked"',
        '"nba_commercial_data_rights": "business-development-blocked"',
    ),
    ".github/workflows/flutter_quality.yml": (
        "workflow_dispatch",
        "static_nba_website_contract_test.py",
        "audit_sports_terminal_platform_v4.py --check",
    ),
}


def _run(script: str) -> tuple[int, str]:
    result = subprocess.run(
        [sys.executable, str(ROOT / script), "--check"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode, (result.stdout + result.stderr).strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/sports_terminal_platform_v4.json")
    args = parser.parse_args()

    failures: list[dict[str, str]] = []
    assertions = 0
    passed = 0

    for relative, tokens in CONVERGENCE_ASSERTIONS.items():
        path = ROOT / relative
        if not path.exists():
            failures.append({"path": relative, "missing": "<file>"})
            continue
        text = path.read_text(encoding="utf-8")
        for token in tokens:
            assertions += 1
            if token in text:
                passed += 1
            else:
                failures.append({"path": relative, "missing": token})

    entry_text = (ROOT / "lib/widgets/app_entry_gate.dart").read_text(encoding="utf-8")
    for forbidden in (
        "BlueprintTerminalFrame(",
        "RoleResearchAugmentedShell(",
        "LaunchRoleProductShell(",
        "AdminNbaTerminalOverlay(",
        "TraditionalWebsiteShell(",
    ):
        assertions += 1
        if forbidden not in entry_text:
            passed += 1
        else:
            failures.append({
                "path": "lib/widgets/app_entry_gate.dart",
                "missing": f"default customer entry must not mount {forbidden}",
            })

    website_text = (ROOT / "lib/widgets/traditional_website_shell_v2.dart").read_text(encoding="utf-8")
    for forbidden in (
        "label: 'Workspace'",
        "label: 'Python Lab'",
        "Checking launch status",
        "Quick research",
        "NBA Universe",
        "SUMMARY",
        "TERMINAL",
    ):
        assertions += 1
        if forbidden not in website_text:
            passed += 1
        else:
            failures.append({
                "path": "lib/widgets/traditional_website_shell_v2.dart",
                "missing": f"primary website must not expose {forbidden}",
            })

    historical_facade = (ROOT / "lib/services/website_nba_api_service.dart").read_text(encoding="utf-8")
    for forbidden in (
        "http://127.0.0.1:8000",
        "/v2/nba/history/seed/",
        "LaunchBackendTransport",
        "loadHistoricalSeason(",
    ):
        assertions += 1
        if forbidden not in historical_facade:
            passed += 1
        else:
            failures.append({
                "path": "lib/services/website_nba_api_service.dart",
                "missing": f"historical website runtime must not depend on {forbidden}",
            })

    legacy_code, legacy_output = _run("tools/audit_production_platform_v3.py")
    blueprint_code, blueprint_output = _run("tools/audit_sports_terminal_blueprint_v1.py")
    if legacy_code != 0:
        failures.append({
            "path": "tools/audit_production_platform_v3.py",
            "missing": "recursive-production-v3-pass",
        })
    if blueprint_code != 0:
        failures.append({
            "path": "tools/audit_sports_terminal_blueprint_v1.py",
            "missing": "master-blueprint-v1-pass",
        })

    payload = {
        "contract": "sports-terminal-blueprint-converged-platform-v4",
        "presentation": "static-first-traditional-responsive-nba-website",
        "composes": [
            "sports-terminal-code-complete-local-review-v3",
            "sports-terminal-master-blueprint-v1",
        ],
        "surfaces": len(CONVERGENCE_ASSERTIONS),
        "assertions": assertions,
        "passed": passed,
        "failures": failures,
        "legacy_output": legacy_output[-2000:],
        "blueprint_output": blueprint_output[-2000:],
        "external_non_code_requirements": [
            "commercial NBA data rights / authoritative live production feed",
            "licensed tracking and video where required",
            "operator-selected hosted/vendor accounts",
            "regulated-product legal programs before real-money execution",
        ],
    }
    output = ROOT / args.json
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps(payload, indent=2))
    return 1 if args.check and failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
