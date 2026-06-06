#!/usr/bin/env bash
set -euo pipefail

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "Could not find python3 or python on PATH."
  echo "Try installing Python 3 or use the Dart normalizer once available."
  exit 127
fi

INPUT_PATH="${1:-raw/common_all_players.json}"
AS_OF="${2:-$(date +%F)}"

"$PYTHON_BIN" tools/normalize_common_all_players.py \
  --input "$INPUT_PATH" \
  --as-of "$AS_OF" \
  --profiles assets/data/nba/players/player_profiles.json \
  --aliases assets/data/nba/players/player_aliases.json \
  --held raw/player_identity_held_rows.json

echo "CommonAllPlayers normalization complete."
echo "Next: run flutter test test/player_identity_validator_test.dart test/player_identity_normalizer_test.dart"
