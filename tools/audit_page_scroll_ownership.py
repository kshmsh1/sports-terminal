from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHELL = ROOT / "lib/widgets/connected_role_terminal_shell.dart"

# These are shell-mounted product surfaces. Dedicated drill-in routes such as the
# full community thread page or legal modal intentionally own their own page scroll
# and are not listed here.
SHELL_SURFACES = (
    "lib/screens/product_transaction_command_center_screen.dart",
    "lib/screens/product_role_home_screen.dart",
    "lib/screens/product_nba_public_pages_screen.dart",
    "lib/screens/product_advanced_nba_tools_screen.dart",
    "lib/screens/product_nba_stats_workstation_screen.dart",
    "lib/screens/product_nba_awards_v2_screen.dart",
    "lib/screens/product_connected_transaction_screens.dart",
    "lib/screens/product_trade_machine_v2_screen.dart",
    "lib/screens/product_front_office_registry_screen.dart",
    "lib/screens/product_connected_workspace_screen.dart",
    "lib/screens/product_connected_data_studio_screen.dart",
    "lib/screens/product_content_ops_screens.dart",
    "lib/screens/product_strategy_map_screen.dart",
    "lib/screens/product_fantasy_community_screens.dart",
    "lib/screens/product_team_blogs_screen.dart",
    "lib/screens/product_community_v2_screen.dart",
    "lib/screens/product_profile_persisted_screen.dart",
    "lib/screens/product_platform_content_legal_screen.dart",
)

SCROLLER_PATTERNS = (
    re.compile(r"SingleChildScrollView\s*\("),
    re.compile(r"ListView(?:\.[A-Za-z_]+)?\s*\("),
    re.compile(r"GridView(?:\.[A-Za-z_]+)?\s*\("),
    re.compile(r"CustomScrollView\s*\("),
)


def context(text: str, start: int, radius: int = 900) -> str:
    return text[max(0, start - 120) : min(len(text), start + radius)]


def allowed_scroll(snippet: str) -> bool:
    normalized = re.sub(r"\s+", " ", snippet)
    if "scrollDirection: Axis.horizontal" in normalized:
        return True
    if "NeverScrollableScrollPhysics" in normalized:
        return True
    # A shrink-wrapped list/grid that explicitly disables primary scrolling is
    # page content rather than a competing page scroll owner.
    if "shrinkWrap: true" in normalized and "primary: false" in normalized:
        return True
    return False


def audit_file(relative: str) -> list[dict[str, object]]:
    path = ROOT / relative
    if not path.exists():
        return [{"path": relative, "kind": "missing", "line": 0}]
    text = path.read_text(encoding="utf-8")
    findings: list[dict[str, object]] = []
    for pattern in SCROLLER_PATTERNS:
        for match in pattern.finditer(text):
            snippet = context(text, match.start())
            if allowed_scroll(snippet):
                continue
            line = text.count("\n", 0, match.start()) + 1
            findings.append(
                {
                    "path": relative,
                    "kind": match.group(0).split("(", 1)[0].strip(),
                    "line": line,
                    "snippet": re.sub(r"\s+", " ", snippet[:260]).strip(),
                }
            )
    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument(
        "--json",
        default="artifacts/page_scroll_ownership.json",
    )
    args = parser.parse_args()

    shell_text = SHELL.read_text(encoding="utf-8") if SHELL.exists() else ""
    shell_vertical_scrollers = len(re.findall(r"SingleChildScrollView\s*\(", shell_text))
    findings: list[dict[str, object]] = []
    for relative in SHELL_SURFACES:
        findings.extend(audit_file(relative))

    payload = {
        "shell": str(SHELL.relative_to(ROOT)),
        "shell_vertical_scrollers": shell_vertical_scrollers,
        "surface_count": len(SHELL_SURFACES),
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
            "Use the role shell as the page scroll owner, or mark internal lists "
            "shrinkWrap/non-scrollable."
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
