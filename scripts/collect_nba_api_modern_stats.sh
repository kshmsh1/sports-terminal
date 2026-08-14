#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VENV="${SPORTS_TERMINAL_NBA_API_VENV:-$ROOT/.nba-api-venv}"
PYTHON="$VENV/bin/python"

if [[ ! -x "$PYTHON" ]]; then
  python3 -m venv "$VENV"
fi

"$PYTHON" -m pip install --quiet --upgrade pip
"$PYTHON" -m pip install --quiet 'nba_api==1.11.4'

exec "$PYTHON" tools/collect_nba_api_modern_stats.py "$@"
