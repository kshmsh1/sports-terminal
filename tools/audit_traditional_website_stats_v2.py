from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CHECKS: dict[str, list[str]] = {
    "lib/screens/website_nba_stats_screen.dart": [
        "values: const [0, 65, 60, 50, 40, 30]",
        "values: const [0, 20, 15, 10]",
        "Use the triangle beside RPG, FG%, 3P% or FT%",
        "Copy CSV",
        "WebsiteStickyStatsTable",
    ],
    "lib/screens/website_nba_advanced_stats_screen.dart": [
        "values: const [0, 65, 60, 50, 40, 30]",
        "values: const [0, 20, 15, 10]",
        "'three_pct': ['fg3_pct', 'three_pct']",
        "'three_dfg_pct': ['three_dfg_pct']",
        "3P DFG% is the opponent",
        "Copy CSV",
    ],
    "lib/widgets/website_sticky_stats_table.dart": [
        "The page owns all vertical scrolling",
        "scrollDirection: Axis.horizontal",
        "first column stays frozen horizontally",
    ],
    "lib/widgets/website_pagination.dart": [
        "const [10, 20, 50, 100]",
    ],
    "lib/widgets/traditional_website_shell_impl.dart": [
        "Lineup Analysis",
        "Search Sports Terminal",
        "Python Lab · detached",
        "Excel Workspace · detached",
    ],
    "lib/screens/website_nba_lineup_analysis_screen.dart": [
        "LeagueDashLineups",
        "data/nba_static/lineups/",
        "WebsiteStickyStatsTable",
    ],
    "tools/nba_com_lineup_static_enrichment.py": [
        "lineups_advanced",
        "lineups_base",
        "sports-terminal-static-lineups-v1",
    ],
    "tools/fetch_nba_com_lineups.py": [
        "leaguedashlineups",
        "impersonate=\"chrome\"",
        "GroupQuantity",
    ],
}


def audit() -> dict[str, object]:
    failures: list[str] = []
    for relative, tokens in CHECKS.items():
        path = ROOT / relative
        if not path.is_file():
            failures.append(f"missing file: {relative}")
            continue
        text = path.read_text(encoding="utf-8")
        for token in tokens:
            if token not in text:
                failures.append(f"{relative} missing token: {token}")

    table = ROOT / "lib/widgets/website_sticky_stats_table.dart"
    if table.is_file():
        text = table.read_text(encoding="utf-8")
        if "Border(bottom:" in text or "BorderSide(color: divider)" in text:
            failures.append("stats table reintroduced cell/header separator lines")
        if "scrollDirection: Axis.vertical" in text:
            failures.append("stats table reintroduced internal vertical scrolling")

    pagination = ROOT / "lib/widgets/website_pagination.dart"
    if pagination.is_file() and "Custom rows per page" in pagination.read_text(encoding="utf-8"):
        failures.append("stats pagination reintroduced custom row counts")

    enrichment = ROOT / "tools/nba_com_static_enrichment.py"
    if not enrichment.is_file():
        failures.append("missing NBA.com static enrichment source")
    else:
        text = enrichment.read_text(encoding="utf-8")
        offensive = '"FG3_PCT": "three_pct"'
        defended = '"FG3_PCT": "three_dfg_pct"'
        if offensive not in text:
            failures.append("offensive 3P% lineage missing from NBA.com enrichment")
        if defended not in text:
            failures.append("defended 3P% lineage missing from NBA.com enrichment")
        if offensive == defended:
            failures.append("offensive and defended 3P percentage keys collided")

    return {
        "contract": "sports-terminal-traditional-stats-ux-v2",
        "files_checked": len(CHECKS),
        "failures": failures,
        "status": "pass" if not failures else "fail",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    result = audit()
    print(json.dumps(result, indent=2, sort_keys=True))
    return 1 if args.check and result["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
