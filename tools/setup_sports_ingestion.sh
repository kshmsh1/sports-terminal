#!/usr/bin/env bash
set -euo pipefail

python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements-scraping.txt
python tools/test_sports_reference_parsers.py
python tools/test_sports_reference_catalog.py
python tools/test_sports_reference_scope.py
python tools/test_sports_reference_link_promoter.py
python tools/test_sports_reference_queue_maintenance.py
python tools/test_sports_reference_crawl_filters.py
python tools/test_nba_terminal_pipeline.py

cat <<'EOF'
Sports ingestion environment is ready and all offline scraper and NBA terminal pipeline tests passed.

Activate it with:
  source .venv/bin/activate

Preview the full historical catalog without network requests:
  bash tools/prepare_historical_nba_catalog.sh plan 1947 2026 historical

Prepare the local queue without fetching pages:
  bash tools/prepare_historical_nba_catalog.sh seed 1947 2026 historical

Inspect the queue:
  python tools/crawl_basketball_reference.py status

No live collection begins during setup, planning, queue preparation, link promotion, queue-pruning dry runs, or local terminal data pipeline tests.
EOF
