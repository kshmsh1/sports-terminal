#!/usr/bin/env bash
# React-first LOCAL development: original static NBA v5 data, no warehouse rebuild.
# Labs are served but Python execution/collaboration services are not started here.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
MODE=dev; OPEN_BROWSER=1
for flag in "$@"; do
  case "$flag" in
    --release) MODE=preview ;;
    --no-browser) OPEN_BROWSER=0 ;;
    --help|-h)
      echo 'Usage: bash scripts/launch_arcside_react.sh [--release] [--no-browser]'
      echo 'Local React-first preview, original NBA v5 static data. Labs services require scripts/launch_arcside.sh --platform.'
      exit 0 ;;
    *) echo "Unknown argument: $flag" >&2; exit 2 ;;
  esac
done
[[ -s web/data/nba_static/manifest.json && -s web/data/nba_static/seasons.json ]] ||
 { echo 'Missing original NBA v5 published corpus; build original static source first. No synthetic data used.' >&2;exit 2; }
command -v node >/dev/null || { echo 'Node.js is required.' >&2;exit 2; }
command -v curl >/dev/null || { echo 'curl is required.' >&2;exit 2; }
[[ -f experimental/arcside-react/node_modules/vite/bin/vite.js ]] ||
 { echo 'Run (cd experimental/arcside-react && npm ci) once.' >&2;exit 2; }
if [[ "$MODE" == preview && ! -s experimental/arcside-react/dist/index.html ]]; then
 echo 'Release build missing; run (cd experimental/arcside-react && npm run build).' >&2;exit 2
fi
PORT="${ARCSIDE_REACT_PORT:-8765}"
[[ "$PORT" =~ ^[0-9]+$ ]] && ((PORT>=1024 && PORT<=65535)) ||
 { echo 'ARCSIDE_REACT_PORT must be an unprivileged TCP port.' >&2;exit 2; }
URL="http://127.0.0.1:$PORT"
if curl -fsS --max-time 1 "$URL/" >/dev/null 2>&1; then
 echo "Port $PORT is already serving something; refusing to reuse an unidentified process." >&2;exit 1
fi
echo "React-first Arcside ($MODE) at $URL/stats"
echo 'Actual local NBA v5; Flutter is retained as the reference and rollback.'
echo 'Quick mode does not start CPython execution or workbook collaboration servers.'
cd "$ROOT/experimental/arcside-react"
node node_modules/vite/bin/vite.js "$MODE" --host 127.0.0.1 --port "$PORT" --strictPort &
SERVER_PID=$!
cleanup(){ trap - EXIT INT TERM; kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
READY=0
for i in $(seq 1 60);do
 if curl -fsS --max-time 2 "$URL/data/nba_static/manifest.json" >/dev/null 2>&1; then READY=1;break;fi
 if ! kill -0 "$SERVER_PID" 2>/dev/null;then break;fi
 sleep .25
done
if [[ "$READY" == 0 ]];then echo 'React server did not become ready.' >&2;exit 1;fi
if [[ "$OPEN_BROWSER" == 1 ]];then
 if command -v open >/dev/null 2>&1;then open "$URL/stats" || true
 elif command -v xdg-open >/dev/null 2>&1;then xdg-open "$URL/stats" >/dev/null 2>&1 || true
 fi
fi
wait "$SERVER_PID"
