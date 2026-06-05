# First Player Identity Import Plan

This is the cutover plan from pre-data architecture work into the first real NBA data import.

## Goal

Create the first source-backed `player_profiles.json` file without fake records, broken joins, or lost source context.

## Input

The first source export must include enough information to map into the player identity contract.

Minimum connected fields:

1. Internal canonical `id`.
2. `displayName`.
3. `sourceId`.
4. `asOf`.

Optional fields can be imported only when source-backed.

## Output

The normalized output is `assets/data/nba/players/player_profiles.json`.

The alias output is `assets/data/nba/players/player_aliases.json` once it is registered in `pubspec.yaml` locally.

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

## Acceptance

The first import is accepted only if:

1. Validator blockers are zero.
2. Row count is documented.
3. Source as-of date is documented.
4. Any warnings are reviewed.
5. Ambiguous rows are quarantined.
6. Player rows can produce RoutePayload objects.
7. Search, Workspace, Compare, Reports, Export, Alerts, Dashboard, and Source Registry do not break.

## Rollback

Because this is a local JSON asset project, rollback is a git revert of the import commit and any related manifest or lineage updates.

## Next step

Choose the first no-cost source path, export rows, map fields, run validation, then import player identity before touching player stats.
