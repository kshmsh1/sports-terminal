# Player Identity Import Contract

Player identity is the first real data unlock for the NBA terminal. Nothing player-centric should be considered connected until player identity is source-backed, validated, and routable.

## Canonical row

The canonical player row is `PlayerProfile`.

Required for a connected import:

1. `id` as the internal canonical player ID.
2. `displayName` as the primary UI label.
3. `sourceId` to identify the source path.
4. `asOf` to preserve source timing.

Allowed as optional source-backed fields:

1. `firstName`.
2. `lastName`.
3. `position`.
4. `height`.
5. `weightPounds`.
6. `birthDate`.
7. `birthCountry`.
8. `college`.
9. `draftYear`.
10. `draftRound`.
11. `draftPick`.
12. `nbaDebutYear`.
13. `isActive`.
14. `primaryTeamAbbreviation`.

Optional fields should stay blank when not source-backed. Do not replace unknown values with fake text, fake zeros, or guessed labels.

## Alias and provider ID policy

The canonical player row should not absorb every provider ID or name variant. Use `PlayerAlias` for:

1. Provider IDs.
2. Historical names.
3. Suffixes and spelling variants.
4. Source-specific aliases.
5. Name-collision review.
6. Ambiguous imported rows.

Duplicate display names should block import until reviewed. Ambiguous rows should be quarantined rather than force-joined.

## Validator

`PlayerIdentityValidator` currently checks:

1. Blank player IDs.
2. Duplicate player IDs.
3. Blank display names.
4. Duplicate display names.
5. Missing `sourceId`.
6. Missing `asOf`.
7. Blank first or last name warnings.
8. Blank active-status warnings.
9. Alias rows referencing missing player IDs.
10. Blank alias values.
11. Duplicate alias rows.

## Import acceptance

The first player identity import should produce:

1. Raw source export retained outside normalized asset.
2. Normalized `player_profiles.json` rows.
3. Validation output from `PlayerIdentityValidator`.
4. A lineage note.
5. A source note.
6. A row-count note.
7. A duplicate-name review note.
8. A rollback note.

## Cutover rule

The app can move from pre-data build mode into real player identity import mode when the local browser smoke test passes and the selected player identity source path is documented.
