# Tools

These utilities are local-only helpers for moving from pre-data readiness into the first source-backed NBA data import.

## Safe smoke test

Use this to test the normalizer mechanics without touching app assets:

```bash
bash tools/smoke_test_common_all_players_import.sh 2026-06-05
```

This writes sample outputs to `raw/smoke_test/` and does not modify `assets/data/nba/players/player_profiles.json` or `assets/data/nba/players/player_aliases.json`.

## CommonAllPlayers real import wrapper

Use this only after saving the real source export at `raw/common_all_players.json`.

```bash
bash tools/run_common_all_players_import.sh raw/common_all_players.json 2026-06-05
```

Arguments:

1. Input path. Defaults to `raw/common_all_players.json`.
2. Source as-of date. Defaults to today's date.

## If the input file is missing

The import utility expects a saved source export. If `raw/common_all_players.json` does not exist, the script should stop with a friendly message.

Do not run `raw/common_all_players.json` as a shell command. It is a file path where the source export should be saved.

## Direct Python utility

Use `python3` on macOS.

```bash
python3 tools/normalize_common_all_players.py \
  --input raw/common_all_players.json \
  --as-of 2026-06-05 \
  --profiles assets/data/nba/players/player_profiles.json \
  --aliases assets/data/nba/players/player_aliases.json \
  --held raw/player_identity_held_rows.json
```

## Dart utility

Use this if Python is unavailable and Dart is available through Flutter.

```bash
dart run tools/normalize_common_all_players.dart \
  --input raw/common_all_players.json \
  --as-of 2026-06-05 \
  --profiles assets/data/nba/players/player_profiles.json \
  --aliases assets/data/nba/players/player_aliases.json \
  --held raw/player_identity_held_rows.json
```

## Validate player identity assets

Run this after normalization and before treating player identity as connected:

```bash
dart run tools/validate_player_identity.dart
```

The command exits non-zero if blockers are present.

## Validate player season stat assets

Run this only after player identity is connected and before treating traditional player stat rows as connected:

```bash
dart run tools/validate_player_season_stats.dart
```

The command blocks missing player joins, missing season joins, missing team joins, missing source metadata, duplicate natural keys, and unsafe values.

## Restore placeholders

If a sample import or failed import wrote into the app assets, restore the source-pending placeholders:

```bash
bash tools/restore_player_identity_placeholders.sh
```

## After normalization

Run:

```bash
flutter test test/player_identity_validator_test.dart
flutter test test/player_identity_normalizer_test.dart
flutter test test/player_identity_import_readiness_service_test.dart
flutter test test/search_route_payload_player_producer_test.dart
flutter test test/player_season_stat_validator_test.dart
```

Then run the app and route a player identity import through Search, Workspace, Compare, Reports, Export, Alerts, Dashboard, and Source Registry before importing any player stats.
