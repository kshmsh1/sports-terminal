#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VENV="$ROOT/.venv"
if [[ ! -x "$VENV/bin/python" ]]; then
  python3 -m venv "$VENV"
fi
PYTHON="$VENV/bin/python"

if ! "$PYTHON" -c 'import curl_cffi' >/dev/null 2>&1; then
  echo "==> Installing Chrome-compatible HTTP transport into Sports Terminal .venv"
  "$PYTHON" -m pip install --disable-pip-version-check -q curl-cffi
fi

"$PYTHON" tools/fetch_nba_com_lineups.py "$@"
