#!/usr/bin/env bash
set -euo pipefail

dart run tools/audit_manual_roster_sources.dart

# Compile the roster parser and validator before mutating connected assets.
flutter test \
  test/roster_measurement_formatter_test.dart \
  test/roster_entry_validator_test.dart

backup_dir="$(mktemp -d)"
report_existed=0
cp assets/data/nba/players/player_profiles.json "$backup_dir/player_profiles.json"
cp assets/data/nba/rosters/roster_entries.json "$backup_dir/roster_entries.json"
if [[ -f raw/manual_roster_seed_report.json ]]; then
  cp raw/manual_roster_seed_report.json "$backup_dir/manual_roster_seed_report.json"
  report_existed=1
fi

restore_on_failure() {
  status=$?
  if [[ $status -ne 0 ]]; then
    cp "$backup_dir/player_profiles.json" assets/data/nba/players/player_profiles.json
    cp "$backup_dir/roster_entries.json" assets/data/nba/rosters/roster_entries.json
    if [[ $report_existed -eq 1 ]]; then
      cp "$backup_dir/manual_roster_seed_report.json" raw/manual_roster_seed_report.json
    else
      rm -f raw/manual_roster_seed_report.json
    fi
    echo "Manual roster seed failed. Connected roster assets were restored from backup."
  fi
  rm -rf "$backup_dir"
  exit "$status"
}
trap restore_on_failure EXIT

dart run tools/apply_manual_roster_seed.dart
dart run tools/summarize_manual_roster_seed.dart
dart run tools/validate_player_identity_connected.dart
dart run tools/validate_rosters.dart
bash tools/check_post_import_candidate.sh

trap - EXIT
rm -rf "$backup_dir"
echo "Manual roster seed passed."
