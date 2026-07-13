# Responsive Stats and Trade Workflow Phase

## Purpose

This phase converts the NBA Stats Center and Trade Machine from broad visual prototypes into responsive, engine-backed workflows. It also adds regression tests for the exact runtime overflow class reported during Chrome testing.

## Runtime layout correction

The previous Trade Machine placed a `DropdownButtonFormField` inside a fixed 120-pixel container. After form decoration and the dropdown icon, the usable content width fell to roughly 64 pixels, causing every visible roster row to overflow.

The replacement implementation uses:

- `isExpanded: true` on dropdown controls;
- explicit content padding;
- a wider destination control;
- ellipsized labels and hints;
- row-to-column switching for narrow asset cards;
- one-column team boards below 1180 pixels;
- horizontally scrollable asset category controls;
- responsive cap cards that move from four columns to two or one;
- horizontally scrollable financial tables.

Responsive widget tests cover both 820×1000 and 1440×1100 surfaces for the Stats Center and Trade Machine.

## Trade Machine workflow

The Trade Machine now creates one structured `TradeScenario` from the visible selections. Every selected asset has an origin, destination, type, label and modeled salary value.

Supported asset classes in the current local workflow:

| Asset class | Current behavior |
| --- | --- |
| Players | Generated roster rows with salary proxies and destination routing |
| Draft picks | First-round, second-round and swap placeholders with destination routing |
| Draft rights | International and unsigned-rights placeholders |
| Cash | Cash-consideration asset with second-apron review support |
| Free-agent rights | Bird-rights and cap-hold placeholders |
| Trade exceptions | TPE placeholder with exception review finding |
| Signing exceptions | NTMLE and TMLE placeholders with exception review finding |

The scenario persists locally with its name, operating year, participating teams, selected assets, asset destinations, active team tabs and selected-only view.

The validation panel uses `TradeMachineEngine` to provide:

- duplicate-asset detection;
- origin/destination scope validation;
- same-team routing errors;
- missing or inactive team warnings;
- incoming and outgoing salary summaries;
- post-trade salary estimates;
- hard-cap checks when a hard-cap value exists;
- first- and second-apron status;
- second-apron cash review;
- exception review findings.

The team cap tracker displays baseline salary proxy, post-trade salary, tax position and apron position for every participating team.

## NBA Stats Center workflow

The Stats Center now sends its query through `NbaStatsQueryEngine` and displays the interpreted plan before presenting results.

Current controls include:

- natural-language command query;
- regular season, playoffs and combined selectors;
- per-game, per-36-minute, estimated per-100-possession and totals bases;
- sortable statistical fields;
- ascending or descending order;
- 10, 25, 50 or 100 rows per page;
- optional OREB and DREB columns;
- preset query chips;
- pagination;
- full-result TSV copy for Workspace, Excel or Python Lab.

Playoff requests return no rows while the local seed contains regular-season summaries only. The interface explicitly states this instead of relabeling regular-season data.

Per-100 values are currently estimates using 2.05 possessions per player-minute. This method remains visible until possession-level data is connected.

## Natural-language query upgrades

The query engine now recognizes both field-first and operator-first syntax.

Examples:

- `PPG > 15`
- `more than 15 PPG`
- `RPG at least 8`
- `fewer than 6 assists`
- `FG% between 45 and 55`
- `over the age of 29`
- `top 25 sorted by points`
- `per 36 minutes`
- `in the playoffs`

Short aliases are boundary protected. For example, `GP` is not parsed from inside `RPG`.

## Data truth and current limitations

The visible product still uses generated 2024–25 basketball data. Trade salary values are transparent proxies, not current contracts. Draft assets, rights, cash balances and exceptions are workflow placeholders, not authoritative inventories.

The current phase does not claim complete trade legality. A launch-quality trade engine still requires versioned contract data and sourced CBA rules covering salary matching, aggregation, aprons, hard-cap triggers, Stepien restrictions, pick protections, sign-and-trades, BYC, poison-pill treatment, exception expiration and other transaction-specific restrictions.

## Validation commands

Run from the repository root:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

The connected repository currently has no GitHub status checks, so local Flutter analysis, tests and browser rendering remain the source of truth.

## Next integration sequence

1. Replace generated salary proxies with a versioned contract and cap warehouse.
2. Connect real 2026 offseason rosters, picks, rights, cap holds and exceptions.
3. Add scenario duplication, comparison, backend persistence and shareable URLs.
4. Export structured trade scenarios into Workspace and Python Lab.
5. Add server-side or indexed Stats pagination for larger datasets.
6. Add postseason, lineup, tracking, shot-zone, clutch and matchup datasets.
7. Save Stats queries as reusable screeners and condition-based alerts.
8. Add routed player, team and game command centers linked directly from result rows.
