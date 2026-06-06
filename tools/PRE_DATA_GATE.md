# Pre-Data Gate

Before source rows are added, run:

```bash
bash tools/check_pre_import_state.sh
```

For the first real player identity import, run:

```bash
bash tools/import_player_identity_candidate.sh raw/common_all_players.json 2026-06-05
```

After source rows are added, run:

```bash
bash tools/check_post_import_candidate.sh
```

The pre-import check expects source-pending datasets to remain empty.

The player identity candidate command imports, validates, requires non-empty connected player rows, and then runs the post-import check.

The post-import check allows source rows but still runs tests and every asset validator.

The older general command remains available:

```bash
bash tools/run_pre_data_gate.sh
```
