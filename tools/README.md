# Tools

Local helpers for moving from pre-data readiness into source-backed NBA imports.

## Pre-data test runner

```bash
bash tools/run_pre_data_tests.sh
```

## Basketball Reference raw ingestion

Create the local Python environment:

```bash
bash tools/setup_sports_ingestion.sh
source .venv/bin/activate
```

Inspect current table identifiers before collecting a dataset:

```bash
python tools/import_basketball_reference.py --season 2026 --list-tables league
```

Fetch one raw candidate at a time:

```bash
python tools/import_basketball_reference.py --season 2026 --dataset player_per_game
python tools/import_basketball_reference.py --season 2026 --dataset player_totals
python tools/import_basketball_reference.py --season 2026 --dataset player_advanced
python tools/import_basketball_reference.py --season 2026 --dataset team_per_game
python tools/import_basketball_reference.py --season 2026 --dataset standings
```

The importer uses robots checks, a descriptive user agent, a minimum request interval, and local HTML caching. It writes review-only CSV, JSON, linked JSON, and manifest files beneath `raw/basketball_reference/` and does not modify canonical app assets.

Full single-page instructions are in `docs/basketball_reference_ingestion.md`.

## Historical Basketball Reference catalog

The historical crawler discovers and stores all tables and provider links from bounded page families rather than requiring a hand-written scraper for every table.

Preview one completed season without using the network:

```bash
python tools/crawl_basketball_reference.py \
  plan \
  --from-season 2025 \
  --to-season 2025 \
  --profile historical
```

Queue that season without using the network:

```bash
python tools/crawl_basketball_reference.py \
  seed \
  --from-season 2025 \
  --to-season 2025 \
  --profile historical
```

Inspect the local raw backend:

```bash
python tools/crawl_basketball_reference.py status
python tools/crawl_basketball_reference.py coverage
python tools/crawl_basketball_reference.py schema-drift
python tools/crawl_basketball_reference.py queue --status queued --limit 25
```

After reviewing the current site access rules, run a small bounded live batch:

```bash
python tools/crawl_basketball_reference.py \
  crawl \
  --max-pages 10 \
  --max-depth 1 \
  --from-season 2025 \
  --to-season 2025 \
  --minimum-interval 4.0 \
  --acknowledge-site-rules
```

The historical backend is stored in:

```text
raw/basketball_reference/catalog.sqlite
raw/basketball_reference/snapshots/
```

It is resumable, cached, page-budgeted, depth-bounded, schema-aware, link-aware, and separate from canonical Flutter assets. Full architecture and operating instructions are in `docs/historical_basketball_reference_crawler.md`.

The legacy PyPI package can be checked separately:

```bash
python -m pip install sportsreference==0.5.2
python tools/probe_sportsreference.py --season 2026
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
