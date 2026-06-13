#!/usr/bin/env bash
set -euo pipefail

python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements-scraping.txt
python tools/test_sports_reference_parsers.py
python tools/test_sports_reference_catalog.py
python tools/test_sports_reference_scope.py

cat <<'EOF'
Sports ingestion environment is ready and all offline scraper tests passed.

Activate it with:
  source .venv/bin/activate

Preview the full historical catalog without network requests:
  bash tools/prepare_historical_nba_catalog.sh plan 1947 2026 historical

Prepare the local queue without fetching pages:
  bash tools/prepare_historical_nba_catalog.sh seed 1947 2026 historical

Inspect the queue:
  python tools/crawl_basketball_reference.py status

No live collection begins during setup, planning, or queue preparation.
EOF
