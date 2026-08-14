from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# High-density surfaces where a player/team label without an entity route is a
# product regression. This is deliberately source-contract based rather than a
# fragile widget-test HTTP dependency: each screen must retain the link helper at
# every list/table role that renders canonical identities.
CONTRACTS: dict[str, tuple[str, ...]] = {
    "lib/screens/product_nba_public_pages_screen.dart": (
        "openNbaPlayerPage(context, row.playerId, row.player)",
        "openNbaTeamPage(context, id, id)",
        "class ProductNbaPlayerPage",
        "class ProductNbaTeamPage",
        "class ProductNbaHubV2Screen",
        "_GameTeamLink",
        "_StandingRow",
    ),
    "lib/screens/product_nba_advanced_stats_page_screen.dart": (
        "openNbaPlayerPage(context, row.playerId, row.player)",
        "openNbaTeamPage(context, id, id)",
    ),
    "lib/screens/product_nba_awards_v2_screen.dart": (
        "_openHistoricalPlayerPage(",
        "ProductHistoricalPlayerDossier(",
        "class _AwardHistoryRow",
    ),
    "lib/screens/product_trade_machine_v2_screen.dart": (
        "openNbaTeamPage(context, team, team)",
        "openNbaPlayerPage(context, view.playerId, view.asset.label)",
        "class _AssetRouteRow",
    ),
    "lib/screens/product_team_blogs_screen.dart": (
        "openNbaPlayerPage(context, row.playerId, row.player)",
        "openNbaTeamPage(context, team, team)",
        "onOpenTeam",
        "game['opponent_team_id']",
    ),
    "lib/screens/product_historical_nba_entity_dossier.dart": (
        "class ProductHistoricalPlayerDossier",
        "class ProductHistoricalTeamDossier",
        "nbaTerminalStatFamilies",
        "NbaStatsSeasonType.playoffs",
    ),
}


def _normalize_source(value: str) -> str:
    """Ignore formatter-only whitespace while preserving semantic source tokens."""
    return re.sub(r"\s+", "", value)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", default="artifacts/nba_entity_link_audit.json")
    args = parser.parse_args()

    failures: list[dict[str, str]] = []
    passed = 0
    assertions = 0
    for relative, required in CONTRACTS.items():
        path = ROOT / relative
        if not path.exists():
            failures.append({"path": relative, "missing": "<file>"})
            continue
        text = path.read_text(encoding="utf-8")
        normalized_text = _normalize_source(text)
        for token in required:
            assertions += 1
            if _normalize_source(token) not in normalized_text:
                failures.append({"path": relative, "missing": token})
            else:
                passed += 1

    payload = {
        "contract": "canonical-player-team-links-v2-all-era",
        "surfaces": len(CONTRACTS),
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
