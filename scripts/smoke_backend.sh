#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/backend"

PYTHON_BIN="${PYTHON_BIN:-python3}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Could not find $PYTHON_BIN. On macOS, install Python 3 or set PYTHON_BIN=/path/to/python3." >&2
  exit 1
fi

PY_VERSION="$($PYTHON_BIN - <<'PY'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PY
)"

if [ -d ".venv" ]; then
  VENV_VERSION="$(.venv/bin/python - <<'PY' 2>/dev/null || true
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PY
)"
  if [ "$VENV_VERSION" != "$PY_VERSION" ]; then
    echo "Rebuilding backend virtualenv for Python $PY_VERSION..."
    rm -rf .venv
  fi
fi

if [ ! -d ".venv" ]; then
  "$PYTHON_BIN" -m venv .venv
fi

source .venv/bin/activate

PY_MINOR="$(python - <<'PY'
import sys
print(sys.version_info.minor)
PY
)"

if [ "$PY_MINOR" -ge 14 ]; then
  export PYO3_USE_ABI3_FORWARD_COMPATIBILITY=1
fi

python -m pip install --upgrade -r requirements.txt
python scripts/smoke_test.py "${1:-http://127.0.0.1:8000}"
