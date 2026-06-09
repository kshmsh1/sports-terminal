# Tools

Local helpers for moving from pre-data readiness into source-backed NBA imports.

## Pre-data test runner

```bash
bash tools/run_pre_data_tests.sh
```

## Manual roster seed from screenshots

```bash
bash tools/run_manual_roster_seed.sh
```

This audits the committed manual roster seed files, applies them into player profiles and roster entries, summarizes 30-team coverage, validates connected identity and rosters, and runs the post-import candidate check.

The generated roster rows are explicitly treated as the final NBA rosters at the end of the 2025-2026 season:

```text
seasonId: 2025-26
snapshotLabel: 2025-26 final roster snapshot
rosterStatus: Final roster
sourceId: manual-roster-screenshots-2026-06-06
```

To inspect only the raw source files without writing generated assets, run:

```bash
dart run tools/audit_manual_roster_sources.dart
```

To inspect only the generated coverage report after applying the seed, run:

```bash
dart run tools/summarize_manual_roster_seed.dart
```

## Safe smoke test

```bash
bash tools/smoke_test_common_all_players_import.sh 2026-06-05
```

This writes sample outputs to `raw/smoke_test/` and does not modify app assets.

## Stage 1 player identity candidate

Use this only after saving the real source export at `raw/common_all_players.json`.

```bash
bash tools/import_player_identity_candidate.sh raw/common_all_players.json 2026-06-05
```

This inspects the raw export, normalizes player profiles and aliases, validates identity, requires non-empty connected player rows, writes an import report, and runs the post-import candidate check.

## Inspect raw CommonAllPlayers export

```bash
dart run tools/inspect_common_all_players_export.dart raw/common_all_players.json
```

## Real player identity import wrapper

This lower-level wrapper only normalizes and writes the player identity assets.

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
dart run tools/validate_player_identity_connected.dart
dart run tools/validate_player_season_stats.dart
dart run tools/validate_team_season_stats.dart
dart run tools/validate_standings.dart
dart run tools/validate_playoff_series.dart
dart run tools/validate_awards.dart
dart run tools/validate_games.dart
dart run tools/validate_rosters.dart
dart run tools/validate_draft.dart
dart run tools/validate_transactions.dart
dart run tools/validate_all_nba_assets.dart
```

## Import report

```bash
dart run tools/write_player_identity_import_report.dart 2026-06-05
```

The report is written to `raw/player_identity_import_report.json`.

## Restore placeholders

```bash
bash tools/restore_player_identity_placeholders.sh
```
