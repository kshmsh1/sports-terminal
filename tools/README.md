# Tools

Local helpers for moving from pre-data readiness into source-backed NBA imports.

## Pre-data test runner

```bash
bash tools/run_pre_data_tests.sh
```

## Safe smoke test

```bash
bash tools/smoke_test_common_all_players_import.sh 2026-06-05
```

This writes sample outputs to `raw/smoke_test/` and does not modify app assets.

## Real player identity import wrapper

Use this only after saving the real source export at `raw/common_all_players.json`.

```bash
bash tools/run_common_all_players_import.sh raw/common_all_players.json 2026-06-05
```

Do not run `raw/common_all_players.json` as a shell command. It is a file path.

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

```bash
dart run tools/normalize_common_all_players.dart \
  --input raw/common_all_players.json \
  --as-of 2026-06-05 \
  --profiles assets/data/nba/players/player_profiles.json \
  --aliases assets/data/nba/players/player_aliases.json \
  --held raw/player_identity_held_rows.json
```

## Validators

```bash
dart run tools/validate_player_identity.dart
dart run tools/validate_player_season_stats.dart
dart run tools/validate_team_season_stats.dart
dart run tools/validate_standings.dart
dart run tools/validate_playoff_series.dart
dart run tools/validate_awards.dart
```

## Restore placeholders

```bash
bash tools/restore_player_identity_placeholders.sh
```
