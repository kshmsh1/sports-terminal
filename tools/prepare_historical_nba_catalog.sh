#!/usr/bin/env bash
set -euo pipefail

command_name="${1:-plan}"
from_season="${2:-1947}"
to_season="${3:-2026}"
profile="${4:-historical}"

case "$command_name" in
  plan|seed)
    ;;
  *)
    echo "Usage: bash tools/prepare_historical_nba_catalog.sh [plan|seed] [from-season] [to-season] [core|extended|historical]" >&2
    exit 2
    ;;
esac

python_bin="python3"
if [[ -x .venv/bin/python ]]; then
  python_bin=".venv/bin/python"
fi

"$python_bin" tools/crawl_basketball_reference.py \
  "$command_name" \
  --from-season "$from_season" \
  --to-season "$to_season" \
  --profile "$profile"

if [[ "$command_name" == "seed" ]]; then
  "$python_bin" tools/crawl_basketball_reference.py status
fi
