from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.build_static_nba_website_data_v2_core import build as build_core  # noqa: E402
from tools.nba_com_lineup_static_enrichment import materialize_lineups  # noqa: E402
from tools.nba_com_static_enrichment import enrich_static_corpus  # noqa: E402

DEFAULT_OUTPUT = ROOT / "web/data/nba_static"


def _output_from_argv() -> Path:
    args = sys.argv[1:]
    for index, value in enumerate(args):
        if value == "--output" and index + 1 < len(args):
            return Path(args[index + 1]).expanduser().resolve()
        if value.startswith("--output="):
            return Path(value.split("=", 1)[1]).expanduser().resolve()
    return DEFAULT_OUTPUT.resolve()


def build() -> int:
    """Build the canonical static corpus, then join authorized NBA.com captures.

    Player/team historical materialization and lineup materialization are both
    local-only build steps. A normal website launch never needs a runtime NBA.com
    request for already-captured historical data.
    """
    result = build_core()
    if result != 0:
        return result
    output = _output_from_argv()
    enrich_static_corpus(output)
    lineup_result = materialize_lineups(output)
    if lineup_result["captures"]:
        print(
            "Static NBA.com lineups: "
            f"{lineup_result['captures']} captures; "
            f"{lineup_result['rows']} rows; "
            f"{lineup_result['datasets']} datasets"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(build())
