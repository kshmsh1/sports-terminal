# First Player Identity Import Plan

This is the cutover plan from pre-data architecture work into the first real NBA data import.

## Goal

Create the first source-backed `player_profiles.json` and `player_aliases.json` files without fake records, broken joins, or lost source context.

## Selected first source path

The first source path to evaluate is `nba_api` CommonAllPlayers.

The source decision is documented in `docs/player_identity_source_decision.md`.

The field mapping is documented in `lib/data/player_identity_nba_api_mapping_items.dart`.

## Input

Save a CommonAllPlayers export locally before normalization.

Minimum fields expected from the first source export:

1. `PERSON_ID`.
2. `DISPLAY_FIRST_LAST`.
3. `DISPLAY_LAST_COMMA_FIRST` when available.
4. `ROSTERSTATUS` when available.
5. `FROM_YEAR` when available.
6. `PLAYERCODE` when available.
7. `TEAM_ABBREVIATION` when available.

Minimum connected fields after normalization:

1. Internal canonical `id`.
2. `displayName`.
3. `sourceId`.
4. `asOf`.

Optional fields can be imported only when source-backed.

## Normalization utility

Use the no-dependency utility:

```bash
python tools/normalize_common_all_players.py \
  --input raw/common_all_players.json \
  --as-of 2026-06-05 \
  --profiles assets/data/nba/players/player_profiles.json \
  --aliases assets/data/nba/players/player_aliases.json \
  --held raw/player_identity_held_rows.json
```

The utility writes normalized player rows, alias rows, and held rows that need review.

## Output

The normalized player output is `assets/data/nba/players/player_profiles.json`.

The normalized alias output is `assets/data/nba/players/player_aliases.json`.

The review output is `raw/player_identity_held_rows.json`, which should not be treated as connected data.

## Validation

Run `PlayerIdentityValidator` before considering the import connected.

Blockers:

1. Blank canonical player ID.
2. Duplicate canonical player ID.
3. Blank display name.
4. Duplicate display name without review.
5. Missing source ID.
6. Missing source as-of date.
7. Alias row pointing to a missing player ID.
8. Blank alias value.

Warnings:

1. Blank first or last name.
2. Blank active-status field.
3. Duplicate alias rows.

## Test commands

```bash
flutter test test/player_identity_validator_test.dart
flutter test test/player_identity_normalizer_test.dart
```

## Acceptance

The first import is accepted only if:

1. Validator blockers are zero.
2. Row count is documented.
3. Source as-of date is documented.
4. Any warnings are reviewed.
5. Ambiguous rows are held out of connected assets.
6. Player rows can produce RoutePayload objects.
7. Search, Workspace, Compare, Reports, Export, Alerts, Dashboard, and Source Registry do not break.

## Rollback

Because this is a local JSON asset project, rollback is a git revert of the import commit and any related manifest or lineage updates.

## Next step

Save a CommonAllPlayers export, run the normalizer, run tests, review held rows, then import player identity before touching player stats.
