#!/usr/bin/env bash
set -euo pipefail

command_name="${1:-plan}"
from_season="${2:-1947}"
to_season="${3:-2026}"
profile="${4:-historical}"

case "$command_name" in
  plan|seed) ;;
  *)
    echo "Usage: bash tools/prepare_historical_nba_catalog.sh [plan|seed] [from-season] [to-season] [core|extended|historical]" >&2
    exit 2
    ;;
esac

python_bin="python3"
if [[ -x .venv/bin/python ]]; then
  python_bin=".venv/bin/python"
fi

"$python_bin" - "$command_name" "$from_season" "$to_season" "$profile" <<'PY'
import json
import sys

sys.path.insert(0, "tools")

from sports_reference.client import SportsReferenceClient
from sports_reference.crawler import BasketballReferenceCrawler
from sports_reference.page_store import SportsReferencePageStore
from sports_reference.url_scope import BasketballReferenceUrlScope

command, start, end, profile = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
store = SportsReferencePageStore("raw/basketball_reference/catalog.sqlite")
scope = BasketballReferenceUrlScope()
crawler = BasketballReferenceCrawler(
    client=SportsReferenceClient(cache_dir=".cache/sports_reference"),
    store=store,
    scope=scope,
)
plan = crawler.plan_site(start, end, profile=profile)
plan.pop("seedUrls", None)
if command == "plan":
    print(json.dumps(plan, indent=2))
else:
    queued = crawler.seed_site(start, end, profile=profile)
    print(json.dumps({"queued": queued, "plan": plan, "status": store.status()}, indent=2, default=str))
PY
