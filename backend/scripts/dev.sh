#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PYTHON_BIN="${PYTHON_BIN:-python3}"
PORT_VALUE="${PORT:-8000}"

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

python -m pip install --upgrade pip
python -m pip install --upgrade -r requirements.txt

export SPORTS_TERMINAL_CORS_ORIGINS="${SPORTS_TERMINAL_CORS_ORIGINS:-http://localhost:3000,http://localhost:5000,http://localhost:8000,http://127.0.0.1:5000,http://127.0.0.1:8000}"

# A prior Sports Terminal dev server can survive when Flutter is stopped or a
# terminal session is interrupted. Starting a second uvicorn instance then
# fails with "Address already in use", while the frontend keeps talking to the
# stale server. Detect that case explicitly so local development is deterministic.
if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 1 "http://127.0.0.1:${PORT_VALUE}/v2/launch/readiness" >/dev/null 2>&1; then
  echo "Sports Terminal launch backend is already healthy on port ${PORT_VALUE}."
  echo "Reusing the existing backend process."
  exit 0
fi

if command -v lsof >/dev/null 2>&1; then
  EXISTING_PID="$(lsof -tiTCP:"${PORT_VALUE}" -sTCP:LISTEN 2>/dev/null | head -n 1 || true)"
  if [ -n "$EXISTING_PID" ]; then
    if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 1 "http://127.0.0.1:${PORT_VALUE}/health" 2>/dev/null | grep -q 'sports-terminal-api'; then
      echo "Stopping stale Sports Terminal backend process ${EXISTING_PID} on port ${PORT_VALUE}..."
      kill "$EXISTING_PID" || true
      for _ in 1 2 3 4 5; do
        if ! lsof -tiTCP:"${PORT_VALUE}" -sTCP:LISTEN >/dev/null 2>&1; then
          break
        fi
        sleep 0.4
      done
    else
      echo "Port ${PORT_VALUE} is already in use by another process (${EXISTING_PID})." >&2
      echo "Stop that process or run with PORT=<another-port>." >&2
      exit 3
    fi
  fi
fi

exec uvicorn app.main_launch:app --reload --port "${PORT_VALUE}"
