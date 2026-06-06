#!/usr/bin/env bash
set -euo pipefail

INPUT_PATH="${1:-raw/common_all_players.json}"
AS_OF="${2:-$(date +%F)}"

if [[ ! -f "$INPUT_PATH" ]]; then
  echo "Input file not found: $INPUT_PATH"
  echo "Save the real CommonAllPlayers export there before running the player identity import candidate."
  exit 66
fi

dart run tools/inspect_common_all_players_export.dart "$INPUT_PATH"
bash tools/run_common_all_players_import.sh "$INPUT_PATH" "$AS_OF"
dart run tools/validate_player_identity.dart
dart run tools/validate_player_identity_connected.dart
dart run tools/write_player_identity_import_report.dart "$AS_OF"
bash tools/check_post_import_candidate.sh

echo "Player identity import candidate passed."
echo "Import report: raw/player_identity_import_report.json"
echo "Next: launch the app and route imported Player payloads from Search through the major consumers."
