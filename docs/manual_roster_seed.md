# Manual Roster Seed

Manual roster source files are under `assets/data/nba/manual_sources/rosters/`.

Run:

```bash
bash tools/run_manual_roster_seed.sh
```

This writes player profiles and roster entries from the committed manual source files, then runs the post-import candidate checks.

After running this, use:

```bash
bash tools/check_post_import_candidate.sh
```

The strict pre-import check is only for the empty source-pending state.
