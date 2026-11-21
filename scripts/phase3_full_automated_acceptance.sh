#!/usr/bin/env bash
# Full available *automated* Phase 3 local acceptance on the ORIGINAL Mac.
# Never a substitute for human visual, native AT, security, GPU or signoff gates.
# Flutter remains authoritative; no deployment, merge or data migrations.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if [[ ! -s web/data/nba_static/manifest.json ]]; then
  echo "Missing original published NBA v5 corpus; no synthetic substitution." >&2
  exit 2
fi
echo "[1/5] Independent React unit tests"
(cd experimental/arcside-react && npm test)
echo "[2/5] Rebuild both release shells and run original-corpus objective evidence"
# Builds both shells; subsequent phases reuse those builds and do not rebuild the warehouse.
env -u ARCSIDE_COMPARE_REUSE_BUILDS bash scripts/phase3_release_compare.sh --objective
echo "[3/5] Guard the production entry bundle"
(cd experimental/arcside-react && node scripts/phase3_bundle_gate.mjs)
echo "[4/5] Recheck original Dart Advanced Stats source contract"
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --advanced-acceptance
echo "[5/5] Recheck original Dart Visualization Studio source contract"
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --visualization-acceptance
echo "Reviewing all evidence gate reports; this does not authorize a full migration."
(cd experimental/arcside-react && node scripts/phase3_decision.mjs)
echo "Automated evidence finished. Read experimental/arcside-react/evidence/decision/phase3-decision.md"
echo "Native Safari/VoiceOver, NVDA, service security, matched GPU, full UI parity and owner approval are separately required."
