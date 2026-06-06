#!/usr/bin/env bash
set -euo pipefail

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "Could not find python3 or python on PATH."
  echo "Use the Dart fallback instead: dart run tools/normalize_common_all_players.dart --input raw/common_all_players.json --as-of YYYY-MM-DD"
  exit 127
fi

INPUT_PATH="${1:-raw/common_all_players.json}"
AS_OF="${2:-$(date +%F)}"

if [[ ! -f "$INPUT_PATH" ]]; then
  echo "Input file not found: $INPUT_PATH"
  echo "This is expected until you save a CommonAllPlayers export into raw/common_all_players.json."
  echo "To smoke-test the normalizer without real NBA source data, run:"
  echo "bash tools/run_common_all_players_import.sh tools/sample_common_all_players.json $AS_OF"
  exit 66
fi

"$PYTHON_BIN" tools/normalize_common_all_players.py \
  --input "$INPUT_PATH" \
  --as-of "$AS_OF" \
  --profiles assets/data/nba/players/player_profiles.json \
  --aliases assets/data/nba/players/player_aliases.json \
  --held raw/player_identity_held_rows.json

echo "CommonAllPlayers normalization complete."
echo "Next: run flutter test test/player_identity_validator_test.dart test/player_identity_normalizer_test.dart test/player_identity_import_readiness_service_test.dart"
