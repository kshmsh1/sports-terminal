#!/usr/bin/env bash
set -euo pipefail

flutter test test/player_identity_validator_test.dart
flutter test test/player_identity_normalizer_test.dart
flutter test test/player_identity_import_readiness_service_test.dart
flutter test test/search_route_payload_player_producer_test.dart
flutter test test/player_season_stat_validator_test.dart
flutter test test/team_season_stat_validator_test.dart
flutter test test/standings_record_validator_test.dart
flutter test test/playoff_series_validator_test.dart
flutter test test/award_record_validator_test.dart
flutter test test/game_record_validator_test.dart
flutter test test/roster_entry_validator_test.dart
flutter test test/draft_pick_validator_test.dart
flutter test test/transaction_record_validator_test.dart
flutter test test/early_data_wave_readiness_service_test.dart

echo "Pre-data test suite passed."
