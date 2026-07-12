# Sports Terminal domain engines phase

## Purpose

The product shell now exposes a broad NBA platform, but several screens still contain screen-local proxy logic. This phase introduces reusable domain engines so the UI can evolve without duplicating parsing, scenario state, cap calculations, or validation rules.

## NBA statistics query engine

`lib/services/nba_stats_query_engine.dart` converts natural-language filters into an explicit query plan. The plan currently supports:

- age, games played, minutes, points, rebounds, assists, steals, blocks, turnovers, fouls, shooting percentages, and plus-minus aliases;
- greater-than, greater-than-or-equal, less-than, less-than-or-equal, and equality constraints;
- percentage normalization from human values such as `50` into stored decimal values such as `0.50`;
- regular-season versus playoff intent;
- per-game, per-36-minute, per-100-possession, and totals intent;
- sorting direction and top-N limits;
- deterministic in-memory execution against generated player-stat rows;
- unparsed-fragment reporting so the interface can explain what it understood and what still needs clarification.

The next Stats Center integration should display the generated query plan as removable filter chips, apply it to the current generated data asset, expose a clear “query understood” panel, and export both the result rows and the query plan into Workspace.

## Trade Machine engine

`lib/services/trade_machine_engine.dart` creates a reusable model for unlimited-team scenarios. It supports players, draft picks, draft rights, cash, free-agent rights, trade exceptions, and signing exceptions as first-class assets. Each asset has one origin and one destination, allowing the UI to represent three-team and larger transactions without special-case screen logic.

The engine calculates incoming salary, outgoing salary, post-trade salary, and asset counts for every participating team. It also returns structured findings rather than a single pass/fail label. Current checks include:

- minimum team count;
- empty scenarios;
- assets routed outside the scenario;
- assets routed back to their origin team;
- duplicate asset assignments;
- missing cap context;
- modeled hard-cap violations;
- first-apron and second-apron status;
- second-apron cash review;
- exception amount, expiration, aggregation, and hard-cap review requirements.

This is deliberately a framework for CBA validation rather than a claim that all 2026-27 rules are already encoded. Live salary data, transaction restrictions, pick protections, Stepien logic, trade matching bands, aggregation restrictions, sign-and-trades, BYC, poison-pill treatment, and exception-specific rules should enter as versioned rule modules backed by sourced data.

## Immediate UI integration sequence

1. Replace the Stats Center’s screen-local query interpretation with `NbaStatsQueryEngine` and show the parsed plan.
2. Replace the Trade Machine’s destination map with a persisted `TradeScenario` object.
3. Add package summaries by team, including incoming assets, outgoing assets, salary delta, apron position, and findings.
4. Add scenario duplication and side-by-side comparison.
5. Add JSON export to Workspace and Python Lab.
6. Add asset-level metadata panels for restrictions, pick protections, exception expiration, and cash limits.
7. Add a versioned CBA rules service and source/method panel.

## Testing

`test/product_engines_test.dart` covers representative multi-constraint stat queries, basis detection, result filtering and ordering, valid two-team trade summaries, duplicate-asset errors, same-team routing errors, hard-cap findings, and exception review findings.

## Product effect

This phase changes the architecture from “many visible prototypes” toward “one connected product system.” Stats queries can become reusable saved objects. Trade scenarios can move between Trade Machine, Front Office, Workspace, Python Lab, articles, and community discussions. The same structured validation report can power user-facing warnings, operator QA, exports, and future backend persistence.
