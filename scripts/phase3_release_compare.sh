#!/usr/bin/env bash
# Phase 3: matched release-build Flutter/React comparison on the owner's Mac.
# Never rebuilds/scrapes the historic NBA warehouse; reads existing v5 output.
# --automated: actual-corpus browser journeys + evidence report
# --all: retired legacy protocol; never mix its pre-repair mismatches with valid trials
# --visualization-acceptance: real original Flutter top-N/OLS export and React parity
# --visualization-guided: acceptance plus human 24-trial chart UX benchmark
# --advanced-acceptance: actual Dart catalog reference + React comparison + browser journeys
# --advanced-guided: above plus isolated 30-trial post-repair operator confirmation
# --objective: repeatable non-certifying load/frame probes, Labs roundtrips, accessibility smoke and source scope audit
set -euo pipefail
MODE="${1:---automated}"
if [[ "$MODE" != "--automated" && "$MODE" != "--advanced-acceptance" && "$MODE" != "--advanced-guided" && "$MODE" != "--visualization-guided" && "$MODE" != "--visualization-acceptance" && "$MODE" != "--objective" && "$MODE" != "--all" ]]; then
 echo 'Usage: bash scripts/phase3_release_compare.sh [--automated|--advanced-acceptance|--advanced-guided|--visualization-acceptance|--visualization-guided|--objective]' >&2;exit 2
fi
if [[ "$MODE" == "--all" ]];then
 echo 'The pre-repair 90-trial --all protocol is retired. Valid season trials are preserved; use --visualization-guided for the new chart measurements.' >&2;exit 2
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
CORPUS="$ROOT/web/data/nba_static"
if [[ ! -f "$CORPUS/manifest.json" || ! -f "$CORPUS/seasons.json" ]]; then
 echo 'Missing actual published NBA static v5 release. Do not substitute fixture data.' >&2;exit 1
fi
for tool in flutter node python3 curl lsof;do
 if ! command -v "$tool" >/dev/null 2>&1;then echo "Missing required command: $tool" >&2;exit 1;fi
done
if [[ ! -x experimental/arcside-react/node_modules/.bin/vite ]];then
 echo 'Install the pinned React dependencies with npm ci first.' >&2;exit 1
fi
FLUTTER_PORT="${ARCSIDE_COMPARE_FLUTTER_PORT:-8768}"
REACT_PORT="${ARCSIDE_COMPARE_REACT_PORT:-4173}"
for PORT in "$FLUTTER_PORT" "$REACT_PORT";do
 if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t | grep -q .;then
  echo "TCP port $PORT is already in use; choose another comparison port." >&2;exit 1
 fi
done
if [[ "${ARCSIDE_COMPARE_REUSE_BUILDS:-0}" == "1" ]]; then
 if [[ ! -f "$ROOT/build/web/index.html" || ! -f "$ROOT/experimental/arcside-react/dist/index.html" ]];then
  echo 'Cannot reuse release builds: Flutter build/web or React dist missing.' >&2;exit 1
 fi
 echo 'Reusing existing release builds; only use after confirming source code has not changed.'
else
 echo 'Compiling production/release versions of BOTH shells (not Flutter debug vs Vite dev)...'
 flutter build web --release
 (cd experimental/arcside-react && npm run build)
fi
if [[ "$MODE" == "--advanced-acceptance" || "$MODE" == "--advanced-guided" ]];then
 echo "Exporting actual Flutter Advanced Stats resolver on canonical NBA shards..."
 flutter test test/phase3_advanced_acceptance_export_test.dart --reporter expanded \
  --dart-define=ARCSIDE_ADVANCED_CORPUS=web/data/nba_static \
  --dart-define=ARCSIDE_ADVANCED_SEASONS=2025-26,1986-87,1946-47
fi
if [[ "$MODE" == "--visualization-acceptance" || "$MODE" == "--visualization-guided" ]];then
 echo "Exporting original Flutter Visualization Studio source-backed population and regression reference..."
 flutter test test/phase3_visualization_reference_export_test.dart --reporter expanded \
  --dart-define=ARCSIDE_VIS_CORPUS=web/data/nba_static \
  --dart-define=ARCSIDE_VIS_SEASONS=2025-26,1986-87,1946-47
fi
if [[ "$MODE" == "--objective" ]];then
 echo 'Exporting original Dart CBA rule reports and verifying independent TypeScript parity...'
 flutter test test/phase3_trade_reference_export_test.dart --reporter expanded
 (cd experimental/arcside-react && npm run test:trade:goldens)
fi
OUT="$ROOT/experimental/arcside-react/evidence/release"
mkdir -p "$OUT"
FLUTTER_PID=''; REACT_PID=''
cleanup(){
 for PID in "$FLUTTER_PID" "$REACT_PID";do
  if [[ -n "$PID" ]];then kill "$PID" 2>/dev/null || true;wait "$PID" 2>/dev/null || true;fi
 done
}
trap cleanup EXIT INT TERM
python3 -m http.server "$FLUTTER_PORT" --bind 127.0.0.1 --directory "$ROOT/build/web" >"$OUT/flutter-release-server.log" 2>&1 &
FLUTTER_PID=$!
(
 cd "$ROOT/experimental/arcside-react"
 exec node node_modules/vite/bin/vite.js preview \
  --host 127.0.0.1 --port "$REACT_PORT" --strictPort
) >"$OUT/react-release-server.log" 2>&1 &
REACT_PID=$!
FLUTTER_URL="http://127.0.0.1:$FLUTTER_PORT"
REACT_URL="http://127.0.0.1:$REACT_PORT"
for URL in "$FLUTTER_URL" "$REACT_URL";do
 READY=0
 for i in $(seq 1 60);do
  if curl -fsS --silent "$URL/data/nba_static/manifest.json" >/dev/null 2>&1;then READY=1;break;fi
  sleep 1
 done
 if [[ "$READY" -ne 1 ]];then
  echo "Release server could not serve authentic manifest: $URL" >&2
  echo '--- Flutter release server log ---' >&2
  tail -n 40 "$OUT/flutter-release-server.log" >&2 || true
  echo '--- React release server log ---' >&2
  tail -n 80 "$OUT/react-release-server.log" >&2 || true
  exit 1
 fi
done
printf 'Flutter release: %s\nReact release: %s\n' "$FLUTTER_URL" "$REACT_URL"
STATUS=0
(
 cd "$ROOT/experimental/arcside-react"
 ARCSIDE_BROWSER_CHANNEL="${ARCSIDE_BROWSER_CHANNEL:-chrome}" \
 ARCSIDE_REAL_BROWSERS="${ARCSIDE_REAL_BROWSERS:-chromium}" \
 ARCSIDE_FLUTTER_URL="$FLUTTER_URL" ARCSIDE_REACT_URL="$REACT_URL" \
 npm run test:real
) || STATUS=1
if [[ "$MODE" == "--advanced-acceptance" || "$MODE" == "--advanced-guided" ]];then
 echo "Evaluating Flutter catalog resolver against React on original NBA corpus..."
 (cd "$ROOT/experimental/arcside-react" && node scripts/advanced_acceptance_compare.mjs) || STATUS=1
fi
if [[ "$MODE" == "--visualization-acceptance" || "$MODE" == "--visualization-guided" ]];then
 echo "Comparing exact original Flutter chart population, player data and regression against React..."
 (cd "$ROOT/experimental/arcside-react" && node scripts/visualization_acceptance_compare.mjs) || STATUS=1
fi
if [[ "$MODE" == "--advanced-guided" ]];then
 if [[ "$STATUS" -ne 0 ]];then
  echo "Advanced source/browser acceptance failed; skipping invalid manual timings." >&2
 else
  echo "Starting NEW corrected 30-trial Advanced Stats UX/performance protocol."
  (
   cd "$ROOT/experimental/arcside-react"
   ARCSIDE_BROWSER_CHANNEL="${ARCSIDE_BROWSER_CHANNEL:-chrome}" \
   ARCSIDE_FLUTTER_URL="$FLUTTER_URL" ARCSIDE_REACT_URL="$REACT_URL" \
   node scripts/guided_advanced_acceptance.mjs
  ) || STATUS=1
 fi
fi
if [[ "$MODE" == "--visualization-guided" ]];then
 if [[ "$STATUS" -ne 0 ]];then
  echo "Flutter bootstrap / original-source React chart journeys failed; refusing invalid chart timings." >&2
 else
  echo 'Starting NEW 24-trial Visualization V2 protocol; prior valid season and Advanced Stats evidence remain unchanged.'
  (
   cd "$ROOT/experimental/arcside-react"
   ARCSIDE_BROWSER_CHANNEL="${ARCSIDE_BROWSER_CHANNEL:-chrome}" \
   ARCSIDE_FLUTTER_URL="$FLUTTER_URL" ARCSIDE_REACT_URL="$REACT_URL" \
   node scripts/guided_visualization_acceptance.mjs
  ) || STATUS=1
 fi
fi
if [[ "$MODE" == "--objective" ]];then
 echo 'Collecting original-corpus scope coverage (absent React modules remain explicit blockers)...'
 (cd "$ROOT/experimental/arcside-react" && node scripts/phase3_readiness_audit.mjs) || STATUS=1
 echo 'Collecting observational, alternating release browser metrics (NOT GPU/chart parity)...'
 (cd "$ROOT/experimental/arcside-react" && \
  ARCSIDE_FLUTTER_URL="$FLUTTER_URL" ARCSIDE_REACT_URL="$REACT_URL" \
  ARCSIDE_BROWSER_CHANNEL="${ARCSIDE_BROWSER_CHANNEL:-chrome}" \
  node scripts/phase3_objective_benchmark.mjs) || STATUS=1
 echo 'Probing browser-semantic accessibility (NOT native Safari/VoiceOver/NVDA)...'
 (cd "$ROOT/experimental/arcside-react" && \
  ARCSIDE_REACT_URL="$REACT_URL" ARCSIDE_BROWSER_CHANNEL="${ARCSIDE_BROWSER_CHANNEL:-chrome}" \
  node scripts/phase3_accessibility_probe.mjs) || STATUS=1
 echo 'Checking original Labs exports using isolated disposable browser data...'
 (cd "$ROOT/experimental/arcside-react" && \
  ARCSIDE_REACT_URL="$REACT_URL" ARCSIDE_BROWSER_CHANNEL="${ARCSIDE_BROWSER_CHANNEL:-chrome}" \
  node scripts/phase3_lab_integrity_probe.mjs) || STATUS=1
 echo 'Verifying original published player dossiers across source-backed career routes...'
 (cd "$ROOT/experimental/arcside-react" && \
  ARCSIDE_REACT_URL="$REACT_URL" ARCSIDE_BROWSER_CHANNEL="${ARCSIDE_BROWSER_CHANNEL:-chrome}" \
  node scripts/phase3_profile_corpus_probe.mjs) || STATUS=1
 echo 'Checking five additional NBA pilot modules against genuine source corpus...'
 (cd "$ROOT/experimental/arcside-react" && \
  ARCSIDE_REACT_URL="$REACT_URL" ARCSIDE_BROWSER_CHANNEL="${ARCSIDE_BROWSER_CHANNEL:-chrome}" \
  node scripts/phase3_module_corpus_probe.mjs) || STATUS=1
fi
(cd "$ROOT/experimental/arcside-react" && node scripts/phase3_decision.mjs) || STATUS=1
echo 'Phase 3 evidence: experimental/arcside-react/evidence/{real,guided,advanced,visualization,objective,readiness,accessibility,labs,profiles,modules,trade,decision}/'
if [[ "$STATUS" -ne 0 ]];then
 echo 'At least one evaluation step failed. Inspect evidence; NEVER call this a pass.' >&2
fi
exit "$STATUS"
