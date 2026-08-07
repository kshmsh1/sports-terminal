#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HISTORY_DB="${SPORTS_TERMINAL_NBA_HISTORY_DB:-data/warehouse/nba_history.sqlite}"
POLICY="${SPORTS_TERMINAL_NBA_CANONICAL_POLICY:-assets/data/nba/metadata/historical_canonical_policy.json}"
REPORT="${SPORTS_TERMINAL_NBA_CANONICAL_REPORT:-data/warehouse/nba_canonical_build_report.json}"

if [ -x ".historical-venv/bin/python" ]; then
  PYTHON_BIN=".historical-venv/bin/python"
else
  PYTHON_BIN="${PYTHON_BIN:-python3}"
fi

if [ ! -f "$HISTORY_DB" ]; then
  echo "Historical warehouse not found: $HISTORY_DB" >&2
  echo "Run: bash scripts/import_historical_nba_sources.sh --replace" >&2
  exit 2
fi

"$PYTHON_BIN" tools/build_historical_nba_canonical.py \
  --database "$HISTORY_DB" \
  --policy "$POLICY" \
  --report "$REPORT" \
  "$@"

echo
"$PYTHON_BIN" tools/summarize_historical_nba_warehouse.py --database "$HISTORY_DB"

echo
if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 1 http://127.0.0.1:8000/v2/launch/readiness >/dev/null 2>&1; then
  echo "Historical API status"
  echo "====================="
  curl -fsS http://127.0.0.1:8000/v2/nba/history/status || true
  echo
else
  echo "Launch backend is not currently reachable on 127.0.0.1:8000; canonical warehouse build is complete regardless."
fi
