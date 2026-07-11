# NBA Terminal Data Pipeline

This pipeline turns the completed local Basketball Reference raw catalog into the first product-facing Sports Terminal data layer. It makes no network requests.

## Current 2024-25 milestone

The 2024-25 season is considered complete when there are no incomplete 2025 season-scoped pages in `raw/basketball_reference/catalog.sqlite`. Seasonless depth-two player pages may remain queued because they are broader graph expansion, not required season coverage.

The current local product pipeline is:

1. Build the warehouse from the raw catalog.
2. Export compact terminal seed JSON from the warehouse.
3. Repair text encoding and validate the seed.
4. Mirror validated seed JSON into Flutter asset space.
5. Open the app and use the `2025 Data` screen to inspect the generated seed.

## One-command run

```bash
python tools/run_nba_terminal_data_pipeline.py --season 2025
```

The command writes:

```text
data/warehouse/nba_2025.sqlite
data/terminal_seed/nba_2025/*.json
assets/data/nba/terminal_seed/nba_2025/*.json
```

Expected result:

```json
{"status": "pass"}
```

## Individual steps

```bash
python tools/build_nba_warehouse.py \
  --season 2025 \
  --output data/warehouse/nba_2025.sqlite

python tools/export_nba_terminal_seed.py \
  --database data/warehouse/nba_2025.sqlite \
  --output data/terminal_seed/nba_2025

python tools/finalize_nba_terminal_seed.py \
  --warehouse data/warehouse/nba_2025.sqlite \
  --seed data/terminal_seed/nba_2025 \
  --season 2025

python tools/sync_nba_terminal_assets.py \
  --seed data/terminal_seed/nba_2025 \
  --asset-output assets/data/nba/terminal_seed/nba_2025 \
  --clean
```

## Offline tests

```bash
python tools/test_nba_terminal_pipeline.py
```

This test compiles the pipeline scripts, creates a synthetic warehouse and seed directory, runs finalization, verifies text repair, and confirms Flutter asset sync.

## Flutter asset usage

The generated JSON assets are registered through `pubspec.yaml` under:

```text
assets/data/nba/terminal_seed/nba_2025/
```

The app reads them through `NbaTerminalSeedRepository` and exposes them in the `2025 Data` navigation tab.
