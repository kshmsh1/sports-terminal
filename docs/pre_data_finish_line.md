# Pre-Data Finish Line

The Sports Terminal build should not drift into endless architecture work. The pre-data phase is complete when the app can safely accept the first real NBA data wave without fake rows, broken screens, or lost source context.

## Current progress

The major shared-route surfaces are now active. The app-level RoutePayloadController exists, the route engine can publish active payloads, and Saved Views, Action Center, Export Center, Alerts, Workspace Studio, Dashboard, Reports, Compare, Search, and Source Registry/Source Audit intake can read or produce shared route state.

The remaining pre-data work is now narrower: tighten source-review registry state, finalize player identity contract details, choose the first player identity source path, lock import acceptance checks, then run a local smoke test before importing player identity.

## Definition of done before ingestion

The pre-data phase is done when:

1. The shared RoutePayload model is stable.
2. The app-level RoutePayloadController is the main selected-object store.
3. Team, Season, and operations rows can publish active payloads.
4. Saved Views, Action Center, Export Center, Alerts, Workspace Studio, Dashboard, Reports, and Compare consume active payloads.
5. Search can produce active payloads from connected result rows.
6. Source Registry can read active payloads as source-review intake.
7. Team and Season rows complete the full workflow loop.
8. Operations rows complete the report, export, alert, dashboard, and source-review loop.
9. Player identity schema is locked.
10. Player alias and provider-ID policy is locked.
11. First import acceptance checks are specified.
12. Source posture is decided for player identity and traditional stats.
13. Screens safely handle connected rows, connected-empty rows, and source-pending rows.

## First real data unlock

The first real data unlock is player identity. Do not import player stats, award voting, rosters, draft, transactions, game logs, or fantasy data before player identity is source-backed and validated.

## Data sequence

1. Player identity.
2. Traditional player season stats.
3. Traditional team season stats.
4. Standings.
5. Playoff series.
6. MVP voting.
7. Games and box scores.
8. Rosters, draft, transactions.
9. Advanced stats and league context.
10. Fantasy, scouting, community, contracts, and other network/product layers.

## Build discipline

Future pre-data build turns should mostly close checklist items. New tabs or broad new concepts should be avoided unless they directly support the readiness gate, player identity import, source posture, validation, or first workflow consumers.
