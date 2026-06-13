#!/usr/bin/env bash
set -euo pipefail

python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements-scraping.txt

cat <<'EOF'
Sports ingestion environment is ready.

Activate it with:
  source .venv/bin/activate

Inspect available league page tables:
  python tools/import_basketball_reference.py --season 2026 --list-tables league

Fetch a raw player per-game candidate:
  python tools/import_basketball_reference.py --season 2026 --dataset player_per_game
EOF
