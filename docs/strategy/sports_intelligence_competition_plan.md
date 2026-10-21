# Sports Terminal: Sports Intelligence Platform

**Working thesis:** Outperform general sports chat products on reproducibility, interactive decision analysis, workflow integration, and user control before chasing equal breadth of proprietary data.

**Competitor:** Blitz Analytics (public research reviewed 2026-10-20)
- https://www.blitzanalytics.com/
- https://www.blitzanalytics.com/features
- https://www.blitzanalytics.com/leaderboard

This document distinguishes **Blitz's published claims** from capabilities independently measured by Sports Terminal. We do not claim the ability to reproduce its proprietary training, datasets, models or customer integrations.

## The product to build

A question is the beginning of a **Research Object**, not the end of a chat message.

Every research object should contain:
1. Immutable question text and interpreted intent.
2. Typed query plan, source tables/fields, filters, date window, league, season and segment.
3. Dataset versions, timestamps, source licenses, coverage and source citations.
4. Deterministic executor results with sample sizes, exclusions, null/estimated-value markers.
5. Interactive tables and visualizations, plus benchmarked summaries explicitly grounded in the result.
6. Follow-up analysis, scenario branches, saved notebooks, version differences and reproducible exports.
7. Optional simulation, forecast or alert attached to the source-backed query with model version and evaluation metrics.

No agent can fabricate an unavailable metric. The correct state is `unsupported`, `source_missing`, `not_materialized`, `stale`, `ambiguous`, or `ready` — not an apparently confident number.

## Competitive landscape and proposed edge

| Dimension | Blitz publicly advertises | Sports Terminal direction | Proof required |
|---|---|---|---|
| Conversational questions | Multi-step warehouse-backed Chat | Typed planner → verified execution → citation-ready Research Object | Held-out question benchmark, zero fabricated fields |
| Data coverage | Cross-sport historical/live/odds/tracking | NBA-first canonical warehouse and acquisition registry; expand leagues on quality gates | Row-level coverage audits, provenance, rights |
| Visualization | Embedded charts and sport-specific boards | Visualization Studio linked directly to answer dataset + provenance | Reproduce any displayed chart deterministically |
| Production workflow | Briefs, show notes, graphics, insights | Versioned briefs / dashboards / exports; reusable analysis artifacts | Editor-quality review against ground truth |
| Real-time | Event-triggered live insights | Licensed incremental events → materialized aggregates → subscriptions | Timestamp and delivery-latency SLAs |
| Decisions | Forecasts and what-if analyses | NBA CBA-aware transactions, roster/rotation scenarios, model uncertainty | Rule fixtures and out-of-sample backtests |
| Platform | Integrations and white label | Research API and embedded SDK with scoped permission / metering | Stable schemas, tenant isolation, uptime |
| Collaboration | Shared queries and production packets | Notebooks, team workspaces, experiments and lineage | Permission tests and deterministic replay |

## Differentiated user journeys

### A. Fan / analyst
Ask “Top 10 assist leaders in the 2024-25 playoffs, minimum five games.” Receive ranked rows and the exact query definition. Open visualizations and player comparisons using the same cohort. Save a notebook and share a read-only link with data-version identifiers.

### B. Front office
Find lineup strategies and contract/cap constraints. Open a scenario linked to the verified stats cohorts. Simulate a proposed NBA trade against the specific CBA ruleset and date. Generate an audit bundle including assumptions and confidence, never a legal assertion without source data.

### C. Broadcast producer
Open tonight's game, read source-backed storylines, inspect notable historical records, build graphics from verified values, route a packet through editorial review, export a production-ready artifact. Live content only when an authorized timely data feed is enabled.

### D. Quant researcher
Explore reproducible feature tables and timestamps, create train/validation/test splits, backtest models with leakage checks and calibration, then compare probabilistic forecasts against realized outcomes. No claimed betting edge without rigorous out-of-sample evidence.

## Technical architecture

```text
Licensed sources / official feeds / documented public datasets
    ↓
Ingestion and provenance (schema + source authority + license + refresh jobs)
    ↓
Canonical event & entity warehouse (game, person, team, season, contract, play)
    ↓
Curated research datasets (stat schemas, coverage matrix, temporal snapshots)
    ↓
Capability registry: supported league x dataset x question family x date
    ↓
Planner: deterministic grammar first; optional LLM plan with schema validator
    ↓
Read-only query executor (whitelist, resource limits, versioned query receipts)
    ↓
Evidence verifier (count, unit, denominator, nulls, provenance, edge cases)
    ↓
Research Object (answer, rows, citations, charts, audit receipt, provenance)
    ↓
Interactive terminal / notebooks / reports / API / alerts / simulations
```

LLMs should plan and narrate under guardrails, **not** invent calculations, data, denominators or unsupported source references.

## Immediate implementation — PR #65

- Reuse `WebsiteNbaApiService.seasonSnapshot` + `NbaStatsWorkstationEngine`.
- A deterministic leaderboard question planner with strict abstention for tracking, on/off, career, live, odds, video and prediction questions.
- Visible question interpretation, cohort qualification, sample sizes, historical data path, no invented outputs.
- Copyable result+methodology receipts and regression tests.
- Research raised to the top navigation; no runtime external queries added.

**This is an initial executable slice only.** It does not implement full multi-step agents, broadcast packets, live coverage, or licensed tracking.

## Development sequence and acceptance gates

| Stage | Scope | Prerequisites | Exit gate |
|---|---|---|---|
| 0. Foundation | Complete UX PR #64 and verify PR #63 separately; stabilize static corpus | Existing Flutter CI | All public routes work at mobile/tablet/desktop widths; critical regressions fixed |
| 1. Evidence-first research | Current PR #65 plus validated question-family registry, entity resolution, follow-up constraints, query receipts | NBA season snapshots | ≥99% exact answers on supported golden queries; 100% abstention on unsupported benchmark; no visible stale results |
| 2. Deep NBA analysis | Multi-season queries, game logs, box score joins, playoff filters, PBP and genuine lineup splits when present | Dataset-specific coverage + game/person identity | Exact source-row trace for each generated value; test false-null vs true zero |
| 3. Research Studio | Linked cohorts → visualizations, compare, team/player dossiers, notebook snapshots, CSV and publication | Versioned Research Objects | Round-trip reproducibility and correct chart filters |
| 4. Decision Studio | CBA-synced trade scenarios, rotation/lineup analysis, salary modeling, contract events | CBA regression fixtures, salary provenance | No invalid trades marked legal; explain each rule and assumption |
| 5. Sports data expansion | NFL → MLB → NHL, then WNBA/college/soccer as rights and accuracy permit | Per-league source licensing and schema validation | Published coverage matrix and parity tests before UI activation |
| 6. Production & live | Licensed event ingestion, real-time boards, editorial packets, alerts, graphics | Feed agreements, event clocks, editorial QA | Latency, uptime and data quality SLOs measured |
| 7. Model layer | Forecasts, simulators, counterfactuals, evaluation dashboards | Clean temporally aligned data | Calibration and predictive scores reported on held-out seasons |
| 8. Platform | Public API/SDK, multi-tenant workspaces, governance, metering | Auth, isolated storage and rate limits | Security review, documentation, contract tests, billing correctness |

Stages can overlap when prerequisites are met; *do not* label the platform “live” or “multi-sport” before the relevant data is actually present.

## Gold-set benchmark to beat the competition fairly

Create independent, dated queries with verifiable ground-truth results and available-source flags. Distinguish:
- **Supported:** the pipeline possesses the source and can answer exactly.
- **Unavailable:** tracking/odds/media/live information not licensed or not materialized.
- **Ambiguous:** query requires clarifying a season, denominator, or entity.
- **Contradictory:** prompt assumes a false historical claim.
- **Temporal:** ask for a historical state as it was known at time T, not revised hindsight.

Measure exact result accuracy, evidence trace completeness, unsupported abstention, median and p95 latency, question coverage, deterministic replay and prompt injection resistance. Report both accuracy on attempted answers and coverage — declining every question cannot be counted as victory.

Never claim competitive superiority without running comparable questions against both products under permitted access and matching data freshness.

## Data sourcing and business model

Sports Terminal should acquire data through official public endpoints subject to terms, properly licensed commercial feeds, open datasets with known usage rights and user-provided data with explicit consent. Do not bypass paywalls, access controls or source restrictions.

Potential revenue lines: free NBA research tier; paid individual research workspaces; analyst/broadcast plans; front-office license; APIs/white-label; compute metering on expensive query families. Validate buyer demand before investing in multi-league ingestion.

### Scope constraints

The current canonical product is Flutter web with mostly static NBA corpus shards. The repository contains many legacy and experimental screens not wired into the public product. Extend the existing warehouse and route orchestration instead of activating unverified placeholders or duplicating logic. PR #63/#64 are open and should not be silently overwritten.
