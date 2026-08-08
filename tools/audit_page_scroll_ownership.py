from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHELL = ROOT / "lib/widgets/connected_role_terminal_shell.dart"

# Top-level surfaces mounted directly inside ConnectedRoleTerminalShell. The audit
# is intentionally class-scoped: pushed drill-in routes (for example a full
# community thread) may own their own viewport after leaving the terminal shell.
SHELL_SURFACES = (
    ("lib/screens/product_transaction_command_center_screen.dart", "ProductTransactionCommandCenterScreen"),
    ("lib/screens/product_role_home_screen.dart", "ProductRoleHomeScreen"),
    ("lib/screens/product_nba_public_pages_screen.dart", "ProductNbaBasicStatsScreen"),
    ("lib/screens/product_nba_public_pages_screen.dart", "ProductNbaHubV2Screen"),
    ("lib/screens/product_advanced_nba_tools_screen.dart", "ProductAdvancedNbaToolsScreen"),
    ("lib/screens/product_nba_stats_workstation_screen.dart", "ProductNbaStatsWorkstationScreen"),
    ("lib/screens/product_nba_awards_v2_screen.dart", "ProductNbaAwardsVotingScreen"),
    ("lib/screens/product_connected_transaction_screens.dart", "ProductConnectedTradeMachineScreen"),
    ("lib/screens/product_connected_transaction_screens.dart", "ProductConnectedFrontOfficeScreen"),
    ("lib/screens/product_trade_machine_v2_screen.dart", "ProductTradeMachineV2Screen"),
    ("lib/screens/product_front_office_registry_screen.dart", "ProductFrontOfficeRegistryScreen"),
    ("lib/screens/product_connected_workspace_screen.dart", "ProductConnectedWorkspaceScreen"),
    ("lib/screens/product_connected_data_studio_screen.dart", "ProductConnectedDataStudioScreen"),
    ("lib/screens/product_content_ops_screens.dart", "ProductAdminOpsCenterScreen"),
    ("lib/screens/product_content_ops_screens.dart", "ProductTrustSafetyConsoleScreen"),
    ("lib/screens/product_strategy_map_screen.dart", "ProductStrategyMapScreen"),
    ("lib/screens/product_fantasy_community_screens.dart", "ProductFantasyWarRoomScreen"),
    ("lib/screens/product_team_blogs_screen.dart", "ProductTeamBlogsScreen"),
    ("lib/screens/product_community_v2_screen.dart", "ProductCommunityV2Screen"),
    ("lib/screens/product_profile_v3_screen.dart", "ProductProfileV3Screen"),
    ("lib/screens/product_platform_content_legal_screen.dart", "ProductPlatformLegalScreen"),
)

SCROLLER_PATTERNS = (
    re.compile(r"SingleChildScrollView\s*\("),
    re.compile(r"ListView(?:\.[A-Za-z_]+)?\s*\("),
    re.compile(r"GridView(?:\.[A-Za-z_]+)?\s*\("),
    re.compile(r"CustomScrollView\s*\("),
)


def class_source(text: str, class_name: str) -> tuple[str, int] | None:
    """Return one top-level class body and its source offset.

    Product files commonly contain pushed drill-in page classes below the shell
    surface. Auditing the full file would incorrectly forbid those independent
    routes from scrolling, so we stop at the next top-level class declaration.
    """
    match = re.search(rf"(?m)^class\s+{re.escape(class_name)}\b", text)
    if match is None:
        return None
    next_class = re.search(r"(?m)^class\s+[_A-Za-z]", text[match.end() :])
    end = len(text) if next_class is None else match.end() + next_class.start()
    return text[match.start() : end], match.start()


def context(text: str, start: int, radius: int = 900) -> str:
    return text[max(0, start - 120) : min(len(text), start + radius)]


def allowed_scroll(snippet: str) -> bool:
    normalized = re.sub(r"\s+", " ", snippet)
    if "scrollDirection: Axis.horizontal" in normalized:
        return True
    if "NeverScrollableScrollPhysics" in normalized:
        return True
    if "shrinkWrap: true" in normalized and "primary: false" in normalized:
        return True
    return False


def audit_class(relative: str, class_name: str) -> list[dict[str, object]]:
    path = ROOT / relative
    if not path.exists():
        return [{"path": relative, "class": class_name, "kind": "missing-file", "line": 0}]
    text = path.read_text(encoding="utf-8")
    extracted = class_source(text, class_name)
    if extracted is None:
        return [{"path": relative, "class": class_name, "kind": "missing-class", "line": 0}]
    source, source_offset = extracted
    findings: list[dict[str, object]] = []
    for pattern in SCROLLER_PATTERNS:
        for match in pattern.finditer(source):
            snippet = context(source, match.start())
            if allowed_scroll(snippet):
                continue
            absolute = source_offset + match.start()
            line = text.count("\n", 0, absolute) + 1
            findings.append(
                {
                    "path": relative,
                    "class": class_name,
                    "kind": match.group(0).split("(", 1)[0].strip(),
                    "line": line,
                    "snippet": re.sub(r"\s+", " ", snippet[:260]).strip(),
                }
            )
    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/page_scroll_ownership.json")
    args = parser.parse_args()

    shell_text = SHELL.read_text(encoding="utf-8") if SHELL.exists() else ""
    shell_vertical_scrollers = len(re.findall(r"SingleChildScrollView\s*\(", shell_text))
    findings: list[dict[str, object]] = []
    for relative, class_name in SHELL_SURFACES:
        findings.extend(audit_class(relative, class_name))

    payload = {
        "shell": str(SHELL.relative_to(ROOT)),
        "shell_vertical_scrollers": shell_vertical_scrollers,
        "surface_count": len(SHELL_SURFACES),
        "contract": "one-shell-owned-vertical-scroll-v2",
        "violations": findings,
    }
    output = ROOT / args.json
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps(payload, indent=2))

    if shell_vertical_scrollers != 1:
        print(
            "Expected exactly one vertical SingleChildScrollView in the role shell; "
            f"found {shell_vertical_scrollers}."
        )
        return 1 if args.check else 0
    if args.check and findings:
        print(
            "Shell-mounted surfaces must render vertical content intrinsically. "
            "Use the role shell as the page scroll owner; internal table scrolling "
            "may be horizontal, and embedded lists must be shrink-wrapped/non-primary."
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
