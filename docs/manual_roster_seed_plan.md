# Manual Roster Seed Plan

The user provided screenshots for the first five NBA team roster pages:

1. Boston Celtics.
2. Atlanta Hawks.
3. Brooklyn Nets.
4. Charlotte Hornets.
5. Chicago Bulls.

These rows should be treated as a manual source-backed seed, not as fake placeholder data.

## Target canonical assets

The manual seed should populate:

```text
assets/data/nba/players/player_profiles.json
assets/data/nba/rosters/roster_entries.json
```

The canonical roster entries should preserve jersey number, position, age, height, weight, college, salary, source ID, as-of date, team ID, and season ID.

## Source metadata

Use:

```text
sourceId: manual-roster-screenshots-2026-06-06
asOf: 2026-06-06
seasonId: 2025-26
```

## Validation mode after seed

After applying these rows, the project is no longer in pre-import state. Use:

```bash
bash tools/check_post_import_candidate.sh
```

To return to the source-pending state, restore placeholders.
