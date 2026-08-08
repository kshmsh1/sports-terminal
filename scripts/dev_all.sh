#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

WEB_HOST="${WEB_HOST:-127.0.0.1}"
WEB_PORT="${WEB_PORT:-5000}"
BACKEND_PORT="${PORT:-8000}"
BACKEND_LOG="${BACKEND_LOG:-/tmp/sports_terminal_backend.log}"
RUN_CHECKS="${RUN_CHECKS:-0}"

flutter pub get

if [ "$RUN_CHECKS" = "1" ]; then
  flutter analyze
  flutter test
fi

PORT="$BACKEND_PORT" bash scripts/dev_backend.sh >"$BACKEND_LOG" 2>&1 &
BACKEND_PID=$!

cleanup() {
  if kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

READY=0
for _ in $(seq 1 90); do
  if curl -fsS --max-time 1 "http://127.0.0.1:${BACKEND_PORT}/v2/launch/readiness" >/tmp/sports_terminal_readiness.json 2>/dev/null; then
    READY=1
    break
  fi
  if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    break
  fi
  sleep 1
done

if [ "$READY" != "1" ]; then
  echo "Sports Terminal backend failed to become ready on port ${BACKEND_PORT}." >&2
  tail -n 120 "$BACKEND_LOG" >&2 || true
  exit 1
fi

echo "Sports Terminal backend ready on http://127.0.0.1:${BACKEND_PORT}"
echo "Launching Flutter Web on http://${WEB_HOST}:${WEB_PORT}"
echo "Backend log: ${BACKEND_LOG}"

flutter run -d chrome --web-hostname "$WEB_HOST" --web-port "$WEB_PORT"
