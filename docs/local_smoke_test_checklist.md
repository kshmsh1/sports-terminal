# Local Smoke Test Checklist

Run this checklist after the latest pre-data pushes.

## Command

```bash
cd ~/sports_terminal
git pull
flutter run -d chrome
```

## Test commands

```bash
flutter test test/player_identity_validator_test.dart
flutter test test/player_identity_normalizer_test.dart
flutter test test/player_identity_import_readiness_service_test.dart
flutter test test/search_route_payload_player_producer_test.dart
flutter test test/player_season_stat_validator_test.dart
flutter test test/team_season_stat_validator_test.dart
flutter test test/early_data_wave_readiness_service_test.dart
```

## Safe import smoke test

To test the normalizer mechanics without modifying app assets:

```bash
bash tools/smoke_test_common_all_players_import.sh 2026-06-05
```

This writes to `raw/smoke_test/` only.

## Import utility commands

If you have a saved CommonAllPlayers export, prefer the wrapper:

```bash
bash tools/run_common_all_players_import.sh raw/common_all_players.json 2026-06-05
```

Validate imported identity assets:

```bash
dart run tools/validate_player_identity.dart
```

Validate player stat assets only after identity is connected:

```bash
dart run tools/validate_player_season_stats.dart
```

Validate team stat assets before standings depend on them:

```bash
dart run tools/validate_team_season_stats.dart
```

Restore placeholders after sample or failed imports:

```bash
bash tools/restore_player_identity_placeholders.sh
```

## RoutePayload loop

1. Open the app.
2. Publish a Team payload.
3. Retarget it to Workspace, Compare, Reports, Saved View, Export, Alerts, Dashboard, Search, Action Center, and Source Audit.
4. Repeat with a Season payload.
5. After a real player identity import, publish a Player result from Search.

## Player identity and early wave checks

1. Open Player Identity Import.
2. Search for `cutover`.
3. Search for `early wave`.
4. Search for `source decision`.
5. Search for `validation`.
6. Search for `player stat validator`.
7. Search for `team stat validator`.

## Expected state before real data

Teams and Seasons should be connected. Player profiles, player aliases, player stats, team stats, games, rosters, awards, draft, transactions, standings, and playoffs should remain source-pending until real validated imports exist.
