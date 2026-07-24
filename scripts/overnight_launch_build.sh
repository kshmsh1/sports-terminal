#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${SPORTS_TERMINAL_LAUNCH_VENV:-.launch-venv}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Python 3 is required. Set PYTHON_BIN to its path." >&2
  exit 1
fi

if [ ! -d "$VENV_DIR" ]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip
python -m pip install --upgrade -r backend/requirements.txt

mkdir -p data/launch_reports
LOG_FILE="data/launch_reports/overnight_console_$(date -u +%Y%m%dT%H%M%SZ).log"

set -o pipefail
python tools/run_overnight_launch_build.py --season 2026 "$@" 2>&1 | tee "$LOG_FILE"

echo
printf 'Overnight launch pipeline completed. Console log: %s\n' "$LOG_FILE"
