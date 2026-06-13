#!/usr/bin/env bash
set -euo pipefail

python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements-scraping.txt
python tools/test_sports_reference_parsers.py
python tools/test_sports_reference_catalog.py

cat <<'EOF'
Sports ingestion environment is ready and all offline ingestion tests passed.

Activate it with:
  source .venv/bin/activate

Preview one completed season without network requests:
  python tools/crawl_basketball_reference.py plan --from-season 2025 --to-season 2025 --profile historical

Queue that season without network requests:
  python tools/crawl_basketball_reference.py seed --from-season 2025 --to-season 2025 --profile historical

Inspect the queue:
  python tools/crawl_basketball_reference.py status

The first live crawl should remain small and explicitly acknowledge current site rules.
EOF
