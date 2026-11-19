#!/usr/bin/env bash
# Re-export the UPDATED original Dart reference and immediately compare the
# EXACT same local source shards with React. Never reuse stale Dart goldens.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
CORPUS="${ARCSIDE_PARITY_CORPUS:-web/data/nba_static}"
SEASONS="${ARCSIDE_PARITY_SEASONS:-2025-26,1986-87,1946-47}"
if [[ ! -f "$CORPUS/manifest.json" ]]; then
  printf 'Missing canonical v5 corpus manifest: %s/manifest.json\n' "$CORPUS" >&2
  exit 1
fi
if [[ ! -d "$ROOT/experimental/arcside-react/node_modules" ]]; then
  echo 'React node_modules missing. First run npm ci in experimental/arcside-react.' >&2
  exit 1
fi
echo '=== STEP 1: Export updated source-backed Dart goldens ==='
flutter test test/phase3_stats_parity_export_test.dart --reporter expanded \
  "--dart-define=ARCSIDE_PARITY_CORPUS=$CORPUS" \
  "--dart-define=ARCSIDE_PARITY_SEASONS=$SEASONS"
echo '=== STEP 2: Compare original Dart to React using the same raw local shards ==='
(cd experimental/arcside-react && ARCSIDE_PARITY_REPORT_ONLY=1 npm run test:parity)
echo '=== STEP 3: Summarize all real-corpus errors, not only the first 150 ==='
python3 - <<'PY'
import json
from pathlib import Path
p=Path('experimental/arcside-react/evidence/parity/parity-comparison.json')
d=json.loads(p.read_text())
print('source:',d['source'],'cases:',d['caseCount'])
print('comparisons:',d['comparisons'],'mismatches:',d['mismatchCount'])
print('match rate:',f"{100*(1-d['mismatchCount']/max(1,d['comparisons'])):.3f}%")
print('by category:',json.dumps(d.get('byCategory',{}),sort_keys=True))
print('by difference:',json.dumps(d.get('byDifference',{}),sort_keys=True))
print('top mismatch fields:',json.dumps(sorted(d['byField'].items(),key=lambda e:-e[1])[:15]))
print('by-case mismatches:')
for name,entry in sorted(d.get('byCase',{}).items()):
    print(' ',name,'-',entry['mismatches'],'of',entry['comparisons'])
print('report:',p.resolve())
print('STRICT PARITY:', 'PASS' if d['passed'] else 'NOT YET PASSING — review byCase/representativeByCase')
PY
