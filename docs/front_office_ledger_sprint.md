# Front Office Ledger Sprint — July 2026

## Purpose

This phase replaces the former basketball-value proxy screen with a persistent front-office ledger that can support sourced contracts and transaction rules later without fabricating current team payrolls.

## Product modules

The Front Office destination now contains four connected work areas:

1. Contract-year ledger
2. Cap reconciliation
3. Draft asset ledger
4. Transaction impact

All user-entered records persist locally. Contract and draft ledgers can be routed through the schema-v2 sports-object system into Workspace or Python Lab.

## Contract-year schema

Each modeled annual contract row preserves:

- player label;
- team and operating season;
- salary and guaranteed amount;
- guarantee classification;
- team, player, early-termination or qualifying-offer option state;
- trade-kicker percentage;
- no-trade-clause flag;
- notes.

The engine validates duplicate IDs, missing identity, non-positive salary, impossible guarantees, trade-kicker guardrails and no-trade consent review.

## Team cap reconciliation

A team ledger combines active contract salary with user-entered:

- dead money;
- free-agent cap holds;
- draft cap holds;
- incomplete-roster charges;
- cash sent and received metadata.

The result is reconciled against the existing official NBA salary cap, tax, first-apron and second-apron environments for the selected season.

## Draft assets

The draft ledger tracks current owner, original team, draft year, round, protections, swap rights, Stepien availability and conveyance notes. Unspecified protections remain a visible warning rather than being treated as trade-ready.

## Transaction impact

The transaction module calculates outgoing salary, incoming salary, post-transaction team salary and post-transaction cap tier. It flags first- and second-apron review and any modeled increase in incoming salary.

It is intentionally not a full CBA legality engine. Salary matching bands, aggregation, sign-and-trades, base-year compensation, poison-pill treatment, exceptions, cash limits and hard-cap triggers remain dedicated future modules.

## Trade Machine interoperability

`TradeScenarioRouteService` converts a Trade Machine scenario into one structured package containing:

- team salary summaries;
- asset assignments;
- validation findings;
- cap context;
- scenario metadata;
- warning and error blockers.

This gives Workspace, Python Lab, Reports and future consumers one stable trade-scenario contract even before the final Trade Machine UI button is connected.

## Accuracy boundary

The current NBA–NBPA CBA took effect July 1, 2023 and runs through the 2029-30 season, subject to the agreement's opt-out provisions. The product uses official league cap environments but treats all contract, draft and team-ledger inputs in this phase as user modeled.

## Validation

The phase adds deterministic tests for:

- contract JSON round trips;
- team salary reconciliation;
- duplicate and impossible-contract validation;
- apron-aware transaction review flags;
- structured contract and draft routing;
- Trade Machine scenario packaging.
