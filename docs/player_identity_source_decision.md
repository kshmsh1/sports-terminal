# Player Identity Source Decision

## Decision

Use `nba_api` CommonAllPlayers as the first no-cost player identity source path to evaluate for the initial player identity import.

This does not mean every field is automatically trusted or connected. It means this path is the first import target because it is zero-cost, programmatic, and aligned with the NBA-first direction of the terminal.

## Source target

Primary endpoint candidate:

`CommonAllPlayers`

Important source fields for first mapping:

1. `PERSON_ID`.
2. `DISPLAY_FIRST_LAST`.
3. `DISPLAY_LAST_COMMA_FIRST`.
4. `ROSTERSTATUS`.
5. `FROM_YEAR`.
6. `TO_YEAR`.
7. `PLAYERCODE`.
8. `TEAM_ID`.
9. `TEAM_CITY`.
10. `TEAM_NAME`.
11. `TEAM_ABBREVIATION`.
12. `TEAM_CODE`.
13. `GAMES_PLAYED_FLAG`.
14. `OTHERLEAGUE_EXPERIENCE_CH`.

## Initial mapping

`PERSON_ID` becomes the provider ID and can seed the internal player ID.

`DISPLAY_FIRST_LAST` becomes `displayName`.

`DISPLAY_LAST_COMMA_FIRST` can be retained as an alias row.

`ROSTERSTATUS` can inform `isActive` only if the value semantics are verified during the first export.

`FROM_YEAR` can inform `nbaDebutYear` when available.

`TEAM_ABBREVIATION` can inform `primaryTeamAbbreviation` only as a current/latest-team convenience field, not as historical roster truth.

`PLAYERCODE` can become an alias/provider code.

## Restrictions

The first import should not treat team fields as historical roster windows.

The first import should not infer height, weight, birthdate, college, draft data, or position from this endpoint unless those fields are available from the selected export.

The first import should not import player stats, awards, rosters, draft, or transactions at the same time.

## Acceptance

The first import passes only if `PlayerIdentityValidator` returns zero blockers.

Duplicate display names require review.

Rows missing source ID or source as-of metadata must not be connected.

Ambiguous rows should be quarantined rather than force-joined.

## Next step

Create a one-off import/export script outside the Flutter app, normalize rows into `player_profiles.json`, generate aliases into `player_aliases.json`, run validator tests, and then commit the source-backed asset update.
