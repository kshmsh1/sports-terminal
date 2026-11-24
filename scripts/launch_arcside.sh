#!/usr/bin/env bash
# Local full-platform or standalone lab launcher. Access keys are ephemeral.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
umask 077
MODE=auto; OPEN_BROWSER=1; SKIP_INSTALL=0; SCIENCE=0; FAST=0
for arg in "$@"; do
  case "$arg" in
    --platform|--react) MODE=react ;;
    --flutter|--legacy-flutter) MODE=flutter ;;
    --labs) MODE=labs ;;
    --no-browser) OPEN_BROWSER=0 ;;
    --skip-install) SKIP_INSTALL=1 ;;
    --fast) FAST=1; SKIP_INSTALL=1 ;;
    --science) SCIENCE=1 ;;
    -h|--help)
      echo "Usage: bash scripts/launch_arcside.sh [--platform|--react|--flutter|--labs] [--no-browser] [--skip-install] [--science] [--fast]"
      echo "Default: React-first platform on original published NBA data; Flutter remains available with --flutter."
      echo "--fast reuses installed Python dependencies and prebuilt NBA static files; starts React promptly."
      echo "ARCSIDE_PYTHON_WORKSPACE can override the directory trusted by the local Python companion."
      exit 0 ;;
    *) echo "Unknown argument: $arg" >&2;exit 2 ;;
  esac
done
PYTHON_BIN="${ARCSIDE_LABS_PYTHON:-python3}"
"$PYTHON_BIN" -c 'import sys;assert sys.version_info >= (3,11),"Python 3.11+ required"'
VENV="$ROOT/.arcside-labs-venv"; RUNTIME="$ROOT/.arcside-labs-runtime"
WORKSPACE="${ARCSIDE_PYTHON_WORKSPACE:-$ROOT/arcside-python-workspace}"
mkdir -p "$RUNTIME" "$WORKSPACE"
if [[ ! -x "$VENV/bin/python" ]]; then
  if [[ "$SKIP_INSTALL" == 1 ]]; then echo "Remove --skip-install: no environment exists" >&2;exit 1;fi
  "$PYTHON_BIN" -m venv "$VENV"
fi
LAB_PY="$VENV/bin/python"
if [[ "$SKIP_INSTALL" == 0 ]]; then
  echo "Installing Arcside IDE and shared-workbook dependencies..."
  "$LAB_PY" -m pip install -q -e "$ROOT/python/arcside_companion[all]" -e "$ROOT/python/arcside_collab"
  if [[ "$SCIENCE" == 1 ]]; then
    "$LAB_PY" -m pip install -q numpy pandas scipy scikit-learn matplotlib polars plotly
  fi
fi
unset ARCSIDE_COMPANION_TOKEN ARCSIDE_COLLAB_ADMIN_KEY
ARCSIDE_COMPANION_TOKEN="$("$LAB_PY" -c 'import secrets;print(secrets.token_urlsafe(32))')"
ARCSIDE_COLLAB_ADMIN_KEY="$("$LAB_PY" -c 'import secrets;print(secrets.token_urlsafe(32))')"
export ARCSIDE_HIDE_TOKEN_IN_OUTPUT=1
collab_pid=; python_pid=; web_pid=
cleanup() {
  trap - EXIT INT TERM
  echo "Stopping Arcside local services..."
  for pid in "$web_pid" "$python_pid" "$collab_pid"; do
    if [[ -n "$pid" ]]; then kill "$pid" >/dev/null 2>&1 || true;fi
  done
  wait >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM
if [[ "$MODE" == auto ]]; then
  if [[ -s "$ROOT/web/data/nba_static/manifest.json" ]] ||
     [[ -s "$ROOT/data/warehouse/nba_history.sqlite" ]] ||
     [[ -s "$ROOT/nba_history.sqlite" ]] ||
     [[ -s "$(dirname "$ROOT")/data/warehouse/nba_history.sqlite" ]] ||
     [[ -s "$(dirname "$ROOT")/nba_history.sqlite" ]] ||
     [[ -s "${SPORTS_TERMINAL_NBA_HISTORY_DB:-/dev/null}" ]]; then
    MODE=react
  else
    MODE=labs
    echo "NBA historical warehouse not found; opening standalone Labs preview."
    echo "Use --platform after generating your original NBA static v5 corpus."
  fi
fi
ARCSIDE_COLLAB_ADMIN_KEY="$ARCSIDE_COLLAB_ADMIN_KEY" "$LAB_PY" -m arcside_collab --db "$RUNTIME/collaboration.sqlite" \
  --port 8767 --allow-origin http://127.0.0.1:8765 \
  --allow-origin http://localhost:8765 >"$RUNTIME/collab.log" 2>&1 &
collab_pid=$!
ARCSIDE_COMPANION_TOKEN="$ARCSIDE_COMPANION_TOKEN" "$LAB_PY" -m arcside_companion --workspace "$WORKSPACE" --port 8766 \
  --allow-origin http://127.0.0.1:8765 \
  --allow-origin http://localhost:8765 >"$RUNTIME/python.log" 2>&1 &
python_pid=$!
check_health() {
  local port="$1" logfile="$2" attempt
  for attempt in $(seq 1 60); do
    if curl --silent --fail --max-time 1 "http://127.0.0.1:$port/health" >/dev/null;then return 0;fi
    sleep .25
  done
  echo "Failed to start :$port; see log:" >&2
  cat "$logfile" >&2
  exit 1
}
check_health 8766 "$RUNTIME/python.log"
check_health 8767 "$RUNTIME/collab.log"
echo
echo "==================== ARCSIDE LABS ===================="
echo "Python execution:          http://127.0.0.1:8766"
echo "Workbook collaboration:    http://127.0.0.1:8767"
echo "Trusted Python workspace:  $WORKSPACE"
echo
echo "PYTHON LAB CONNECTION TOKEN:"
echo "$ARCSIDE_COMPANION_TOKEN"
echo
echo "SHEETS ROOM CREATION KEY:"
echo "$ARCSIDE_COLLAB_ADMIN_KEY"
echo
echo "Keys are private. Python runs with your operating-system permissions."
echo "Shared workbook keys do NOT grant Python execution access."
echo "Press Ctrl+C in this terminal to stop all services."
echo "======================================================"
echo
if [[ "$MODE" == labs ]]; then
  "$LAB_PY" -m http.server 8765 --bind 127.0.0.1 --directory "$ROOT/web" >"$RUNTIME/web.log" 2>&1 &
  web_pid=$!
  echo "Python Lab:      http://127.0.0.1:8765/labs/python/index.html"
  echo "Excel Workspace: http://127.0.0.1:8765/labs/sheets/index.html"
  if [[ "$OPEN_BROWSER" == 1 ]]; then
    if command -v open >/dev/null 2>&1; then
      open "http://127.0.0.1:8765/labs/sheets/index.html" || true
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "http://127.0.0.1:8765/labs/sheets/index.html" >/dev/null 2>&1 || true
    fi
  fi
  wait "$web_pid"
elif [[ "$MODE" == flutter ]]; then
  if ! command -v flutter >/dev/null 2>&1; then
    echo "Flutter missing from PATH. Install Flutter or use --platform for React." >&2;exit 1
  fi
  echo "Launching Arcside original Flutter reference at http://127.0.0.1:8765 ..."
  if [[ "$FAST" == 1 ]]; then
    [[ -s "$ROOT/web/data/nba_static/manifest.json" ]] ||
      { echo 'Original NBA static v5 corpus missing.' >&2;exit 1; }
    flutter run -d chrome --web-port 8765 --web-hostname 127.0.0.1
  else
    bash "$ROOT/scripts/open_terminal.sh" --web-port 8765
  fi
else
  [[ -s "$ROOT/web/data/nba_static/manifest.json" && -s "$ROOT/web/data/nba_static/seasons.json" ]] ||
    { echo 'Original NBA static v5 corpus missing. Use Flutter reference to rebuild it first.' >&2;exit 1; }
  command -v node >/dev/null 2>&1 ||
    { echo 'Node.js required for the React platform.' >&2;exit 1; }
  [[ -f "$ROOT/experimental/arcside-react/node_modules/vite/bin/vite.js" ]] ||
    { echo 'Run (cd experimental/arcside-react && npm ci) once before launching React.' >&2;exit 1; }
  echo "Launching React-first Arcside at http://127.0.0.1:8765/stats ..."
  echo "Flutter is available with bash scripts/launch_arcside.sh --flutter --fast."
  (
    cd "$ROOT/experimental/arcside-react"
    exec node node_modules/vite/bin/vite.js dev --host 127.0.0.1 --port 8765 --strictPort
  ) >"$RUNTIME/react.log" 2>&1 &
  web_pid=$!
  READY=0
  for i in $(seq 1 60);do
    if curl -fsS --max-time 1 http://127.0.0.1:8765/data/nba_static/manifest.json >/dev/null 2>&1;then READY=1;break;fi
    if ! kill -0 "$web_pid" 2>/dev/null;then break;fi
    sleep .25
  done
  if [[ "$READY" != 1 ]];then
    echo 'React frontend failed; inspect local Vite log:' >&2
    tail -n 80 "$RUNTIME/react.log" >&2 || true
    exit 1
  fi
  if [[ "$OPEN_BROWSER" == 1 ]];then
    if command -v open >/dev/null 2>&1;then open http://127.0.0.1:8765/stats || true
    elif command -v xdg-open >/dev/null 2>&1;then xdg-open http://127.0.0.1:8765/stats >/dev/null 2>&1 || true
    fi
  fi
  wait "$web_pid"
fi
