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

Direct Python command uses `python3`, not `python`:

```bash
python3 tools/normalize_common_all_players.py \
  --input raw/common_all_players.json \
  --as-of 2026-06-05 \
  --profiles assets/data/nba/players/player_profiles.json \
  --aliases assets/data/nba/players/player_aliases.json \
  --held raw/player_identity_held_rows.json
```

Dart fallback:

```bash
dart run tools/normalize_common_all_players.dart \
  --input raw/common_all_players.json \
  --as-of 2026-06-05 \
  --profiles assets/data/nba/players/player_profiles.json \
  --aliases assets/data/nba/players/player_aliases.json \
  --held raw/player_identity_held_rows.json
```

Validate imported identity assets:

```bash
dart run tools/validate_player_identity.dart
```

Validate player stat assets only after identity is connected:

```bash
dart run tools/validate_player_season_stats.dart
```

Restore placeholders after sample or failed imports:

```bash
bash tools/restore_player_identity_placeholders.sh
```

## RoutePayload loop

1. Open the app.
2. Go to Core MVP Gaps or the first-release workflow area.
3. Publish a Team payload.
4. Retarget it to Workspace, Compare, Reports, Saved View, Export, Alerts, Dashboard, Search, Action Center, and Source Audit.
5. Confirm each surface shows the active payload without crashing.
6. Repeat with a Season payload.
7. Repeat with an operations payload if available from the route engine.

## Search producer

1. Open Search.
2. Use the Search RoutePayload Producer panel.
3. Publish a Team result.
4. Retarget the active payload from another consumer.
5. Publish a Season result.
6. Confirm history and active state update.
7. After a real player identity import, publish a Player result.

## Player identity pre-import checks

1. Open Player Identity Import.
2. Search for `cutover`.
3. Search for `source decision`.
4. Search for `validation`.
5. Search for `alias`.
6. Search for `mapping`.
7. Search for `player stat validator`.
8. Confirm the import screen shows cutover, source, contract, validation, schema, acceptance, pre-stat, and wave items.

## Expected state before real data

1. Teams should be connected.
2. Seasons should be connected.
3. Player profiles should be empty.
4. Player aliases should be empty.
5. Player stats should be empty.
6. Team stats should be empty.
7. Games, rosters, awards, draft, transactions, standings, and playoffs should be empty.
8. Empty means source-pending, not broken.

## Alias asset

The `player_aliases.json` asset now exists and is registered in `pubspec.yaml`.

## First source path

The first player identity import path is documented in `docs/player_identity_source_decision.md`.

Do not import player stats until player identity rows pass validation and route cleanly through the terminal.
