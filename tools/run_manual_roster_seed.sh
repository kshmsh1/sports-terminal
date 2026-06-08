#!/usr/bin/env bash
set -euo pipefail

dart run tools/apply_manual_roster_seed.dart
dart run tools/summarize_manual_roster_seed.dart
dart run tools/validate_player_identity_connected.dart
dart run tools/validate_rosters.dart
bash tools/check_post_import_candidate.sh

echo "Manual roster seed passed."
