# NBA MVP Endgame

The first end platform is a local, zero-cost NBA historical terminal prototype that works with real, source-backed data and avoids invented sports records.

## MVP target

A user should be able to open the app locally and explore NBA teams, seasons, players, stats, comparisons, and reports from a consistent terminal interface.

The MVP does not need live data, paid APIs, accounts, cloud storage, push notifications, or packaged desktop/mobile builds. Those can come later. The MVP should prove that the architecture, data model, joins, search, and core workflows are useful.

## Ship criteria

1. Reference foundation is stable: teams and seasons load from local JSON and are used as join targets.
2. Player identity is real: player profiles contain source-backed rows with stable IDs and source metadata.
3. Traditional player stats are real: player-season rows join to players, teams, and seasons.
4. Team context is real: team-season stats and standings connect to Teams and Seasons.
5. Search is useful: it indexes terminal surfaces and asset-backed records.
6. Core screens are useful: Dashboard, Teams, Seasons, Players, and Stats show real readiness and selected-detail views.
7. Compare and Reports consume source-backed entity/stat rows once populated.
8. Source governance is preserved through source IDs, source notes, data lineage, and validation checks.

## Build order from here

1. Keep Teams and Seasons stable.
2. Finish Search as the command layer.
3. Import real player identity.
4. Import traditional player-season stats.
5. Import team-season stats and standings.
6. Deepen Players, Stats, Teams, and Seasons around populated rows.
7. Convert Compare from templates to selectable comparisons.
8. Convert Reports from templates to generated report shells.
9. Add local saved view persistence after core data surfaces work.
10. Keep alerts design-only until snapshots and persistence exist.

## Local MVP boundaries

The local MVP should not depend on paid data feeds, accounts, cloud sync, external notifications, live game updates, or invented player/stat records. The prototype should stay honest: real rows only, source-pending otherwise.

## Product philosophy

Build fewer fake things and more connected real things. The terminal becomes valuable when data can move from source to local asset to repository to joined screen to search to comparison/report, with source lineage preserved at every step.
