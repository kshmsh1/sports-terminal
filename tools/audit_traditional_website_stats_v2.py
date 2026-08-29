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
        "Conventional, borderless website statistics table",
        "ClipRRect",
        "stripeRows",
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
        "Unit size",
        "Search players in lineups",
        "Lineup GP",
        "Metric group",
        "_openMembers",
        "q$_groupQuantity",
    ],
    "tools/nba_com_lineup_static_enrichment.py": [
        "lineups_advanced",
        "lineups_base",
        "sports-terminal-static-lineups-v2",
        "GROUP_QUANTITIES = (2, 3, 4, 5)",
        "group_quantity",
    ],
    "tools/fetch_nba_com_lineups.py": [
        "leaguedashlineups",
        "impersonate=\"chrome\"",
        "GroupQuantity",
        "--group-quantity",
        "GROUP_QUANTITIES = (2, 3, 4, 5)",
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
        if "return Card(" in text:
            failures.append("stats table reintroduced global Card border styling")
        if "elevation: _stickyOffset > 0 ? 2 : 0" in text:
            failures.append("stats table reintroduced sticky-header shadow rule")

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

    lineup_fetcher = ROOT / "tools/fetch_nba_com_lineups.py"
    lineup_materializer = ROOT / "tools/nba_com_lineup_static_enrichment.py"
    if lineup_fetcher.is_file() and lineup_materializer.is_file():
        fetcher_text = lineup_fetcher.read_text(encoding="utf-8")
        materializer_text = lineup_materializer.read_text(encoding="utf-8")
        for quantity in (2, 3, 4, 5):
            if str(quantity) not in fetcher_text or str(quantity) not in materializer_text:
                failures.append(f"lineup pipeline missing {quantity}-player unit support")

    return {
        "contract": "sports-terminal-traditional-stats-ux-v3",
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
