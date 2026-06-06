# Pre-Data Troubleshooting

## `python: command not found`

Use `python3` or the wrapper:

```bash
bash tools/run_common_all_players_import.sh raw/common_all_players.json 2026-06-05
```

## `raw/common_all_players.json` not found

That file is not created by the repo. It is the real source export path.

Before the real export exists, run:

```bash
bash tools/check_pre_import_state.sh
```

## Sample rows were written into app assets

Restore source-pending placeholders:

```bash
bash tools/restore_player_identity_placeholders.sh
```

Then run:

```bash
bash tools/check_pre_import_state.sh
```

## Need to test normalizer mechanics only

Use the safe smoke test:

```bash
bash tools/smoke_test_common_all_players_import.sh 2026-06-05
```

This writes to `raw/smoke_test/` and does not modify app assets.

## After real source rows are imported

Run:

```bash
bash tools/check_post_import_candidate.sh
```

Then launch the app and route imported player identity from Search through the major consumers.
