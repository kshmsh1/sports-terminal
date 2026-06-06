#!/usr/bin/env bash
set -euo pipefail

AS_OF="${1:-2026-06-05}"

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "Could not find python3 or python on PATH."
  echo "Use the Dart fallback command in tools/README.md."
  exit 127
fi

mkdir -p raw/smoke_test

"$PYTHON_BIN" tools/normalize_common_all_players.py \
  --input tools/sample_common_all_players.json \
  --as-of "$AS_OF" \
  --profiles raw/smoke_test/player_profiles.sample.json \
  --aliases raw/smoke_test/player_aliases.sample.json \
  --held raw/smoke_test/player_identity_held_rows.sample.json

echo "Smoke test output written to raw/smoke_test/."
echo "No app assets were modified."
