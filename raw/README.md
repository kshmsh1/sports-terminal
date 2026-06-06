# Raw Source Exports

This directory is for local source exports that should be reviewed before becoming connected app assets.

The first expected file is:

```text
raw/common_all_players.json
```

That file is not committed by default because it should come from your local source export process.

## Why the import failed

If the normalizer says this file does not exist, the import utility is working correctly but has no source export to read yet.

## Test without the real export

To test the mechanics only, run:

```bash
bash tools/run_common_all_players_import.sh tools/sample_common_all_players.json 2026-06-05
```

This writes sample-normalized rows into the app assets. Revert those files before committing real data.

## Real import

After saving the real source export as `raw/common_all_players.json`, run:

```bash
bash tools/run_common_all_players_import.sh raw/common_all_players.json 2026-06-05
```

Then run:

```bash
flutter test test/player_identity_validator_test.dart
flutter test test/player_identity_normalizer_test.dart
flutter test test/player_identity_import_readiness_service_test.dart
```
