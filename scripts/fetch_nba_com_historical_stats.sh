#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v python3 >/dev/null 2>&1 || { echo "python3 is required." >&2; exit 1; }

VENV="$ROOT/.venv"
if [[ ! -x "$VENV/bin/python" ]]; then
  echo "==> Creating .venv"
  python3 -m venv "$VENV"
fi
PYTHON="$VENV/bin/python"

if ! "$PYTHON" -c 'import curl_cffi' >/dev/null 2>&1; then
  echo "==> Installing one-time Chrome-like NBA.com fetch transport"
  "$PYTHON" -m pip install --disable-pip-version-check -q 'curl-cffi>=0.7,<1.0'
fi

echo "==> NBA.com Stats Part 1 historical acquisition"
echo "    Default scope: every configured variant, Regular Season + Playoffs, 2025-26 back through 1946-47"
echo "    Raw responses stay local under raw/nba_com_stats; the browser never calls NBA.com."
exec "$PYTHON" tools/fetch_nba_com_historical_stats.py --transport chrome "$@"
