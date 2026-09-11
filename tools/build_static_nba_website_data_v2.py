from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.build_static_nba_website_data_v2_core import (
    build as build_core,
    dashboard_payload,
    season_catalog,
)
from tools.nba_awards_static_supplement import apply_award_supplement
from tools.nba_com_lineup_static_enrichment import materialize_lineups
from tools.nba_com_static_enrichment import enrich_static_corpus
from tools.nba_data_foundation import build_data_foundation
from tools.repair_static_nba_playoffs import repair_playoff_shards

DEFAULT_OUTPUT = ROOT / "web/data/nba_static"
DEFAULT_DATABASE = ROOT / "data/warehouse/nba_history.sqlite"

STATIC_SCHEMA_VERSION = 5
STATIC_WEBSITE_CONTRACT = "sports-terminal-static-nba-website-v5"
STATIC_DASHBOARD_CONTRACT = "sports-terminal-static-dashboard-v2"
STATIC_RUNTIME_CONTRACT = {
    "historical_http_api_required": False,
    "sqlite_required_by_browser": False,
    "live_overlay_supported": True,
    "dashboard_precomputed": True,
}
STATIC_DASHBOARD_FIELDS = (
    "team_leaders",
    "personal_fouls",
    "three_pointers_made",
)


def _argument_path(flag: str, fallback: Path) -> Path:
    args = sys.argv[1:]
    for index, value in enumerate(args):
        if value == flag and index + 1 < len(args):
            return Path(args[index + 1]).expanduser().resolve()
        if value.startswith(f"{flag}="):
            return Path(value.split("=", 1)[1]).expanduser().resolve()
    return fallback.expanduser().resolve()


def _output_from_argv() -> Path:
    return _argument_path("--output", DEFAULT_OUTPUT)


def _database_from_argv() -> Path:
    configured = os.environ.get("SPORTS_TERMINAL_NBA_HISTORY_DB", "").strip()
    fallback = Path(configured) if configured else DEFAULT_DATABASE
    return _argument_path("--database", fallback)


def build() -> int:
    """Build the immutable corpus and apply local-only enrichment layers."""
    result = build_core()
    if result != 0:
        return result

    output = _output_from_argv()
    database = _database_from_argv()

    playoff_result = repair_playoff_shards(database, output)
    if playoff_result["repaired"] or playoff_result["empty"]:
        print(
            "Static NBA playoff shards: "
            f"{playoff_result['repaired']} repaired; "
            f"{playoff_result['preserved']} preserved; "
            f"{playoff_result['empty']} empty fallbacks"
        )

    enrich_static_corpus(output)

    lineup_result = materialize_lineups(output)
    if lineup_result["captures"]:
        print(
            "Static NBA.com lineups: "
            f"{lineup_result['captures']} captures; "
            f"{lineup_result['rows']} rows; "
            f"{lineup_result['datasets']} datasets"
        )

    award_result = apply_award_supplement(output)
    print(
        "Static NBA awards supplement: "
        f"{award_result['added_history']} history rows; "
        f"{award_result['added_player']} player-honor rows; "
        f"{award_result['unmatched_players']} unmatched player names"
    )

    foundation = build_data_foundation(output, database)
    print(
        "NBA data foundation: "
        f"{foundation['available_provider_count']}/{foundation['provider_count']} "
        f"providers available; fingerprint={foundation['fingerprint'][:12]}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(build())
