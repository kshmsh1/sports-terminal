# Tools

These utilities are local-only helpers for moving from pre-data readiness into the first source-backed NBA data import.

## CommonAllPlayers import wrapper

Use this first. It detects `python3` or `python` and runs the Python normalizer.

```bash
bash tools/run_common_all_players_import.sh raw/common_all_players.json 2026-06-05
```

Arguments:

1. Input path. Defaults to `raw/common_all_players.json`.
2. Source as-of date. Defaults to today's date.

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

## After normalization

Run:

```bash
flutter test test/player_identity_validator_test.dart
flutter test test/player_identity_normalizer_test.dart
flutter test test/player_identity_import_readiness_service_test.dart
```

Then run the app and route a player identity import through Search, Workspace, Compare, Reports, Export, Alerts, Dashboard, and Source Registry before importing any player stats.
