from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATUS = ROOT / "docs" / "sports_terminal_blueprint_status.json"

REQUIRED_FILES = {
    "universal_terminal_shell": ROOT / "lib" / "widgets" / "sports_terminal_operating_shell.dart",
    "terminal_design_system": ROOT / "lib" / "design" / "terminal_design_system.dart",
    "universal_object_header": ROOT / "lib" / "widgets" / "terminal_object_header.dart",
    "universal_actions": ROOT / "lib" / "models" / "terminal_action.dart",
    "actionable_metrics": ROOT / "lib" / "widgets" / "terminal_metric_action_menu.dart",
    "contextual_navigation": ROOT / "lib" / "widgets" / "terminal_context_rail.dart",
    "density_modes": ROOT / "lib" / "services" / "terminal_density_service.dart",
    "boards": ROOT / "lib" / "models" / "terminal_board.dart",
    "board_store": ROOT / "lib" / "services" / "terminal_board_store.dart",
    "board_workspace": ROOT / "lib" / "widgets" / "terminal_board_workspace.dart",
    "research_objects": ROOT / "lib" / "models" / "research_object.dart",
    "research_reproduction": ROOT / "lib" / "services" / "research_object_service.dart",
    "certified_release_ux": ROOT / "lib" / "widgets" / "terminal_release_badge.dart",
    "data_rights_envelope": ROOT / "lib" / "models" / "data_rights_envelope.dart",
    "source_audit_v2": ROOT / "lib" / "widgets" / "terminal_source_audit_panel.dart",
    "universal_query_object": ROOT / "lib" / "models" / "universal_query.dart",
    "query_continuity": ROOT / "lib" / "services" / "query_continuity_service.dart",
    "historical_player_convergence": ROOT / "lib" / "widgets" / "nba_player_terminal_convergence.dart",
    "command_system": ROOT / "lib" / "services" / "terminal_command_engine.dart",
    "command_bar": ROOT / "lib" / "widgets" / "terminal_command_bar.dart",
}

SOURCE_ASSERTIONS = {
    "lib/widgets/sports_terminal_operating_shell.dart": [
        "TerminalCommandBar",
        "TerminalContextRail",
        "TerminalIntelligenceRail",
        "TerminalStatusBar",
        "TerminalDensitySelector",
    ],
    "lib/models/terminal_action.dart": [
        "COMPARE",
        "CHART",
        "WATCH",
        "QUERY",
        "MODEL",
        "EXPORT",
        "SOURCE",
        "BOARD",
        "SHARE",
        "DISCUSS",
    ],
    "lib/widgets/terminal_metric_action_menu.dart": [
        "Definition",
        "Source",
        "Method",
        "Release",
        "Coverage",
    ],
    "lib/services/research_object_service.dart": [
        "Research revisions are immutable",
        "currentData",
        "explicit data release",
    ],
    "lib/models/data_rights_envelope.dart": [
        "redistribution",
        "retentionRule",
        "territories",
        "intersect",
    ],
    "lib/services/query_continuity_service.dart": [
        "Dashboard",
        "Compare",
        "Python Lab",
        "Workspace",
        "Export",
        "Source Audit",
    ],
    "lib/widgets/nba_player_terminal_convergence.dart": [
        "openResolvedNbaPlayerCareerPage",
        "openNbaPlayerCareerPage",
        "never silently treated as historical keys",
    ],
}

EXTERNAL_KEYS = {
    "official_live_nba_feed",
    "licensed_tracking",
    "licensed_game_video",
    "commercial_social_streams",
    "production_email_provider",
    "production_object_storage",
    "hosted_managed_postgres",
    "external_monitoring_delivery",
    "payment_provider",
    "enterprise_idp_registration",
    "nba_commercial_data_rights",
}


def audit() -> dict[str, object]:
    failures: list[str] = []
    if not STATUS.exists():
        failures.append("missing blueprint status manifest")
        status = {}
    else:
        status = json.loads(STATUS.read_text(encoding="utf-8"))

    for label, path in REQUIRED_FILES.items():
        if not path.exists():
            failures.append(f"missing {label}: {path.relative_to(ROOT)}")

    for relative, tokens in SOURCE_ASSERTIONS.items():
        path = ROOT / relative
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        for token in tokens:
            if token not in text:
                failures.append(f"{relative} missing token: {token}")

    software = status.get("softwareNow", {}) if isinstance(status, dict) else {}
    if isinstance(software, dict):
        for key in (
            "universal_terminal_shell",
            "terminal_design_system",
            "universal_actions",
            "boards",
            "research_objects",
            "data_rights_envelope",
            "universal_query_object",
            "terminal_command_system_v2",
        ):
            if software.get(key) != "implemented":
                failures.append(f"software status is not implemented: {key}")
    else:
        failures.append("softwareNow must be an object")

    external = status.get("rightsOrExternalDependency", {}) if isinstance(status, dict) else {}
    if not isinstance(external, dict):
        failures.append("rightsOrExternalDependency must be an object")
    else:
        missing_external = sorted(EXTERNAL_KEYS - set(external))
        if missing_external:
            failures.append(f"missing explicit external dependency states: {missing_external}")
        for key, value in external.items():
            if value == "implemented":
                failures.append(f"external dependency must not be fabricated as implemented: {key}")

    return {
        "contract": "sports-terminal-master-blueprint-v1",
        "required_surfaces": len(REQUIRED_FILES),
        "source_assertion_files": len(SOURCE_ASSERTIONS),
        "external_dependencies": len(EXTERNAL_KEYS),
        "failures": failures,
        "status": "pass" if not failures else "fail",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    result = audit()
    print(json.dumps(result, indent=2, sort_keys=True))
    if args.check and result["status"] != "pass":
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
