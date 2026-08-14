# Sports Terminal — Pre-Capital Product Readiness

## Purpose

This document defines the boundary between work that can still be completed through product engineering, local/open data collection and rigorous QA, versus work that requires paid infrastructure, commercial data rights, professional services or operating staff.

The target is not merely a feature-rich prototype. The target is an NBA-first Sports Terminal that is coherent, navigable, source-aware, historically complete where data exists, useful for real research and front-office workflows, and internally stable enough that the remaining launch work is mostly external to application code.

## Current product state

Sports Terminal now has a unified NBA-first application architecture rather than a set of disconnected demos. Its shared primitives are canonical sports objects, persistent research context, terminal commands, source-aware data provenance, workspaces and routable product destinations.

### Data foundation

The historical warehouse contains the imported NBA/BAA/ABA source layer spanning roughly eight decades. The canonical layer standardizes players, teams, franchises, seasons and games while preserving source provenance and material conflicts. Historical data can be projected into the same general snapshot contract used by the original current-season application, which means the same product infrastructure can consume current or historical NBA contexts.

The data system includes:

- lossless multi-source historical ingestion;
- canonical player/team/franchise/season/game identity;
- source registry, licensing metadata, hashes and coverage inventories;
- regular-season/playoff separation;
- player-season and team-season facts;
- games, player-game records and play-by-play where source coverage exists;
- awards, All-Star and draft facts;
- field-level provenance and material conflict preservation;
- historical/current compatibility projection;
- NBA API schema coverage auditing for modern tracking/advanced fields.

The modern NBA API layer now adds a separate archival and transformation path. Raw NBA API results are stored before transformation, request/failure metadata is retained, deterministic recipes materialize Sports Terminal metrics, and the resulting player-season overlays can be merged into Advanced Stats without replacing the historical/current base snapshot.

### Terminal and navigation

The application uses a horizontal top-level navigation model and dark mode is the first-run default. The NBA Terminal command layer provides deterministic commands, aliases, recent/favorite commands, canonical object search, an all-season index, data/coverage inspection and direct routing into major product surfaces. Command-K / Control-K opens the terminal globally in supported role shells.

The role/product shell is intended to own vertical page scrolling. Data tables may use horizontal scrolling where necessary, but major screens should not create competing vertical scroll regions inside the application viewport.

### NBA statistics and research

The user-facing Stats destination is intentionally simple and focused on core box-score statistics. Advanced Stats contains the professional research workstation and the 187-metric source-aware registry.

Implemented capabilities include:

- Regular Season as the default and Playoffs as an explicitly separate segment;
- Basic, Defense/Hustle, Playmaking/Possession, Rebounding, Efficiency, Impact, Aggregate, Movement, Clutch, Shot Profile, Play Type, Gravity/Creation, Physical, Discipline and Availability families;
- expandable parent metrics and family-specific expansions;
- rate bases including per-game, per-36, per-48, per-75 possessions, per-100 possessions and totals;
- team/position/player filtering, qualification thresholds and sorting;
- source-aware unavailable states rather than fabricated values;
- concise metric glossary definitions;
- modern NBA API overlay support for source-backed metrics;
- historical Stats and cross-era comparison;
- all-time/career/peak/best-N leaderboards;
- historical game and play-by-play research;
- franchise lineage and season intelligence;
- entity watchlists, saved contexts and research boards.

### Player, team, franchise, season and game objects

Players and teams are treated as routable product objects rather than text labels. Dedicated entity surfaces provide a foundation for opening an object from Stats, Advanced Stats, NBA Hub, awards, team publications, research and other modules.

Entity infrastructure includes:

- player pages;
- team pages;
- franchise lineage/dossiers;
- season command pages;
- game/PBP investigation;
- canonical entity search;
- entity watchlists;
- direct handoff into Stats, Analytics and Historical Intelligence;
- automated entity-link auditing for major NBA surfaces.

### NBA Hub and historical intelligence

The NBA Hub acts as an NBA operating homepage with linked teams/players, leaders and direct access to standings, schedules, transactions, awards, draft, injuries, contracts/cap and historical research destinations.

Historical Intelligence and Entity Intelligence provide deeper career, era, game, franchise, coverage/conflict and canonical-object workflows than the original single-season product could support.

### Awards and voting

The canonical awards system reads historical award and All-Star facts and classifies them into a broad Sports Terminal award taxonomy. It exposes award catalog, award history, season awards and player-awards APIs.

The taxonomy includes major annual awards, postseason MVP awards, All-Star honors, All-NBA teams, All-Defensive teams, All-Rookie teams, NBA Cup honors and periodic awards where source data is available. Voting/share/rank fields are preserved where the historical source supplies them rather than being collapsed into winner-only records.

### Trade Machine and front office

The Trade Machine is built on a reusable CBA-aware validation engine rather than a visual-only transaction mockup. It supports multi-team routing and multiple asset types including players, picks, rights, cash and exceptions.

The modeled validation layer includes salary matching/cap room, hard-cap checks, first/second-apron behavior, second-apron aggregation/cash/exception restrictions, roster projections, no-trade consent, trade-restriction metadata, trade bonuses and distant first-round-pick constraints. Dedicated tests cover edge-rule behavior.

The broader front-office system includes:

- versioned player contracts;
- team financial positions;
- draft-asset registry;
- transaction ledger and immutable events;
- personal/organization transaction cases;
- approvals, assignments, notifications and activity;
- reconciliation and source-status tracking;
- scenario modeling and research handoffs.

### Workspaces and Python

Sports Terminal includes persistent research/workflow tooling beyond fixed dashboards:

- multi-sheet analytical workspaces;
- formulas/imports and version history;
- optimistic conflict detection;
- permission controls and restore workflows;
- routable sports-object datasets;
- persistent research boards;
- bounded server-side Python execution;
- multi-cell Python notebook;
- individual cell execution and Run All;
- execution duration/status;
- output displayed directly below each cell;
- routed Sports Terminal data available to approved notebook helpers.

### Community, messaging and trust/safety

The community layer is a real backend-backed network system rather than static social cards. It includes league/general communities and all 30 team communities, ranked discovery, follows, saves, voting, nested replies, flair/metadata, reputation/badges and moderation integration.

The platform also has:

- content reporting;
- moderation cases/actions/audit records;
- sanctions;
- blocks and mutes;
- protected direct/group messaging;
- trust/safety enforcement at publishing/messaging boundaries;
- community/profile reputation integration.

This is sufficient product architecture for a serious private/public beta. Operating a large public network safely is nevertheless a staffing/operations problem in addition to a code problem.

### Profiles and user preferences

Profiles are persisted server-side and include:

- display name and unique handle;
- bio;
- avatar URL with validation;
- public/private profile state;
- favorite NBA teams;
- favorite/watchlisted players;
- community reputation/badges;
- joined communities;
- email digest, fantasy, trade and editorial preferences;
- notification-preference storage.

Direct binary image upload is intentionally not treated as complete until production object storage/media processing exists.

### Team publications and editorial

Every NBA team has a team-publication architecture with roster/game/transaction/draft/cap entry points. The broader Articles product supports a premium multi-sport editorial hierarchy spanning NBA, WNBA, NFL, NHL, MLB, college basketball, college football, tennis and major domestic/international soccer sections.

The software architecture for editorial discovery exists; live original journalism, licensed feeds and staffed editorial operations are separate operating inputs.

### Identity, organizations and customer operations

Sports Terminal includes:

- first-party account/session flows;
- analyst, organization-admin and platform-admin roles;
- organization/member governance;
- onboarding and entitlement state;
- notification inbox;
- customer support cases/comments;
- service incident state;
- automation governance;
- launch/readiness reporting.

### Legal and account consent

The product includes detailed Privacy Policy and Terms & Conditions surfaces plus About and Contact pages. Account creation requires affirmative Terms and Privacy acceptance. Acceptance is server-enforced, document-versioned and timestamped rather than being only a UI checkbox.

The legal text remains a product draft and must be reviewed/finalized by qualified counsel before a public commercial launch, especially governing-law, arbitration/venue, entity/contact, privacy-jurisdiction and data-rights provisions.

## Remaining work that should not require capital

The following tasks should be completed before declaring that the capital boundary has been reached.

### 1. Populate the modern NBA API overlay

Run the rate-limited collector across the desired modern seasons and both season segments, inspect endpoint failures, validate dynamic tracking schemas, and materialize reviewed recipes. This should fill a meaningful portion of Advanced Stats columns that currently display unavailable states.

Primary command:

```bash
bash scripts/collect_nba_api_modern_stats.sh --season 2025-26 --season-type both --replace-scope
```

Then backfill historical modern/tracking eras selectively after the current-season pipeline is stable.

### 2. Build the complete current-season release

The application can still fall back to the validated prior-season seed if the current-season release asset is absent. Before near-finished status, the supported current season should have a complete certified seed/release rather than relying on fallback behavior.

### 3. Populate and verify front-office source catalogs

The software already models these objects, but the launch readiness gate intentionally requires real current records:

- current player contract catalog;
- all 30 team financial/cap positions;
- current draft-asset ownership/protection ledger.

This is primarily source collection/reconciliation/QA rather than missing application architecture. Commercial redistribution rights remain a separate issue.

### 4. Continue CBA edge-case certification

The Trade Machine should receive additional fixture-driven validation for less common transaction structures and timing rules, including sign-and-trades, BYC/poison-pill cases, acquisition/aggregation waiting periods, exception expiration/usage, full Stepien/protection interactions and any current-CBA edge cases exposed during real scenario testing.

### 5. Full browser runtime QA

CI is broad but cannot replace an aggressive human click-through of the debug web application. Every major route should be exercised at desktop and compact widths with special attention to:

- page-scroll ownership;
- Flutter runtime-only assertions;
- entity links/back navigation;
- empty/error/loading states;
- persisted state after refresh;
- backend unavailable/fallback behavior;
- tables with unusually wide/long datasets;
- account/profile/community flows;
- trade/workspace/notebook state changes.

### 6. Finish no-cost polish rather than add new architecture

At this stage additional unpaid product work should be mostly refinement: visual consistency across older modules, terminology, empty-state copy, source labels, keyboard behavior, loading skeletons, accessibility basics, deterministic fixtures and removal of demo text that could be mistaken for live editorial/data content.

## Capital / paid-service boundary

Once the no-capital tasks above are complete, the remaining serious launch blockers are primarily external.

### Commercial data rights

A public/paid product needs explicit rights for any data whose terms do not permit commercial redistribution. This may include current/live official feeds, contracts/transactions, injuries, betting/odds, tracking, news, media, proprietary models and other third-party content.

The architecture should continue to support open/public/licensed feeds interchangeably, but rights cannot be solved with code.

### Production database and infrastructure

Local SQLite is excellent for development and historical warehousing, but a public multi-user service needs paid/managed infrastructure, including:

- managed relational database;
- backups and point-in-time recovery;
- deployment/runtime hosting;
- domains and TLS;
- object storage for avatars/media/exports;
- CDN/static delivery where appropriate;
- secrets management;
- environment isolation;
- scaling/failover policy.

### Identity communications

A production account system should add external email delivery for email verification, password recovery, security notifications and potentially MFA or SMS/passkey support depending on the final identity architecture.

### Payments

If paid plans launch, a payment/subscription provider and associated tax/refund/entitlement operations become required. The internal entitlement model is provider-neutral so this is an integration rather than a product rewrite.

### Observability and security

Public production requires real error monitoring, logs, metrics/traces, uptime checks, alerting, analytics and an incident path. Before meaningful commercial exposure, an external security assessment/penetration test is appropriate.

### Legal review

Qualified counsel should review Terms, Privacy, intellectual-property protections, data licensing, user-generated-content rules, consumer/subscription requirements, dispute terms and applicable privacy regimes. The product already enforces versioned acceptance; counsel finalizes what users are accepting.

### Human operations

A public community/content/customer product requires people, not merely endpoints:

- moderation coverage;
- customer support;
- incident response;
- data QA/reconciliation;
- community management;
- editorial staff or licensed content feeds if Articles launches as a live publication.

### Licensed media and proprietary models

Official team/player imagery, certain logos/media assets and third-party proprietary metrics may require licenses. EPM, LEBRON, DARKO and similar third-party models should never be silently recreated/rebranded as source data. Sports Terminal can either license them, omit them, or build clearly named original models from legitimately available underlying data.

## Definition of near-finished before capital

Sports Terminal should be considered near-finished on the engineering side when all of the following are true:

1. the core NBA application can be navigated end-to-end without runtime exceptions;
2. current and historical NBA contexts both work through the shared product architecture;
3. the modern NBA API overlay is collected/materialized for the supported season and Advanced Stats displays the source-backed fields it can legitimately obtain;
4. current contracts/team positions/draft assets are populated and reconciled to the launch gate;
5. player/team/entity links work across the major NBA surfaces;
6. legal consent, profiles, community, messaging, workspaces, Python and front-office workflows persist correctly;
7. all automated quality gates are green;
8. remaining blockers are dominated by licensing, hosting, payments, email, monitoring, legal/security review and operating staff—not by missing core screens or missing internal architecture.

At that point additional capital should buy production inputs and scale rather than fund a fundamental rewrite of the product.
