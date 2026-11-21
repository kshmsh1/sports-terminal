#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -s web/data/nba_static/manifest.json ]] || { echo 'Missing actual NBA v5 corpus.' >&2; exit 2; }
[[ -s build/web/index.html ]] || { echo 'Missing Flutter release build.' >&2; exit 2; }
[[ -s experimental/arcside-react/dist/index.html ]] || { echo 'Missing React release build.' >&2; exit 2; }
for tool in lsof curl python3 node;do command -v "$tool" >/dev/null || { echo "Missing $tool" >&2; exit 2; };done
FLUTTER_PORT="$(printenv ARCSIDE_COMPARE_FLUTTER_PORT || echo 8768)"
REACT_PORT="$(printenv ARCSIDE_COMPARE_REACT_PORT || echo 4173)"
for p in "$FLUTTER_PORT" "$REACT_PORT";do
 if lsof -nP -iTCP:"$p" -sTCP:LISTEN -t | grep -q .; then echo "Port $p is busy." >&2;exit 2;fi
done
mkdir -p experimental/arcside-react/evidence/release
fl_pid='';rx_pid=''
cleanup(){
 for pid in "$fl_pid" "$rx_pid";do
  if [[ -n "$pid" ]];then kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;fi
 done
}
trap cleanup EXIT INT TERM
python3 -m http.server "$FLUTTER_PORT" --bind 127.0.0.1 --directory "$ROOT/build/web" \
 > experimental/arcside-react/evidence/release/native-flutter-server.log 2>&1 &
fl_pid="$!"
(
 cd experimental/arcside-react
 exec node node_modules/vite/bin/vite.js preview --host 127.0.0.1 --port "$REACT_PORT" --strictPort
) > experimental/arcside-react/evidence/release/native-react-server.log 2>&1 &
rx_pid="$!"
for url in "http://127.0.0.1:$FLUTTER_PORT" "http://127.0.0.1:$REACT_PORT";do
 ready=0
 for i in $(seq 1 40);do
  if curl -fsS --silent "$url/data/nba_static/manifest.json" >/dev/null 2>&1;then ready=1;break;fi
  sleep 1
 done
 if [[ "$ready" -ne 1 ]];then echo "Missing actual v5 manifest at $url" >&2;exit 1;fi
done
echo "Flutter: http://127.0.0.1:$FLUTTER_PORT"
echo "React: http://127.0.0.1:$REACT_PORT"
echo "Open native test in a SECOND terminal. CTRL-C here stops both."
while kill -0 "$fl_pid" 2>/dev/null && kill -0 "$rx_pid" 2>/dev/null;do sleep 1;done
echo 'A release server exited unexpectedly; inspect evidence/release logs.' >&2
exit 1
