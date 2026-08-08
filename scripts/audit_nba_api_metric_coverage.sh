#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VENV="${SPORTS_TERMINAL_NBA_API_VENV:-$ROOT/.nba-api-venv}"
PYTHON="$VENV/bin/python"
NBA_API_VERSION="${NBA_API_VERSION:-1.11.4}"

if [[ ! -x "$PYTHON" ]]; then
  python3 -m venv "$VENV"
fi

"$PYTHON" -m pip install --quiet --upgrade pip
"$PYTHON" -m pip install --quiet "nba_api==$NBA_API_VERSION"
"$PYTHON" tools/audit_nba_api_metric_coverage.py "$@"
