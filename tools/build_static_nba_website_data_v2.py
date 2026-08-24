from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.build_static_nba_website_data_v2_core import build as build_core  # noqa: E402
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

    The core compiler remains unchanged and may skip its expensive warehouse pass
    when the SQLite fingerprint is current. The enrichment layer has its own raw
    capture fingerprint, so newly imported NBA.com JSON still reaches the website
    on the very next normal launch without requiring --rebuild-static.
    """
    result = build_core()
    if result != 0:
        return result
    enrich_static_corpus(_output_from_argv())
    return 0


if __name__ == "__main__":
    raise SystemExit(build())
