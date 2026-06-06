#!/usr/bin/env bash
set -euo pipefail

flutter test test/player_identity_validator_test.dart
flutter test test/player_identity_normalizer_test.dart
flutter test test/player_identity_import_readiness_service_test.dart
flutter test test/search_route_payload_player_producer_test.dart
flutter test test/player_season_stat_validator_test.dart
flutter test test/team_season_stat_validator_test.dart
flutter test test/early_data_wave_readiness_service_test.dart

echo "Pre-data test suite passed."
