# Sports Terminal Launch Transformation

## Launch objective

The first customer release is a professional NBA terminal scoped to one complete season: **2025–26**. The architecture deliberately separates code completion, data-release certification, and external commercial requirements so the product cannot label itself launch-ready while any of those layers remain incomplete.

## Customer products

### Individual Terminal

The individual product contains NBA research, structured data routing, Workspace, Data Studio, Cap Lab, modeled Trade Machine and Front Office modules, and a personal transaction command center. First-party accounts receive durable sessions, server-backed personal cases, activity, notifications, and a versioned personal workbook when the launch backend is online.

### Organization Terminal

The organization product contains the same analytical foundation plus organization cases, members, assignments, approvals, organization activity, a versioned organization workbook, and administration surfaces. Organization signup creates the account, organization, and owner membership as one transaction.

### Platform Admin Terminal

Platform administrators remain in the internal terminal. The launch API adds data-release and launch-readiness contracts that can later replace prototype governance surfaces with server-backed release operations.

## Authentication

The launch backend includes a first-party closed-beta authentication implementation:

- PBKDF2-HMAC-SHA256 password hashing with random salts;
- 310,000 derivation iterations;
- hashed random bearer tokens;
- 30-day durable sessions;
- session restore and logout;
- failed-login tracking and temporary lockout;
- password changes that revoke other sessions;
- individual and organization signup.

Public launch still requires email delivery and verification operations, account recovery, optional MFA, abuse prevention, and either a reviewed first-party security program or an external identity provider.

## Server-backed product contracts

The launch API adds persistent tables and endpoints for:

- organizations and memberships;
- personal and organization transaction-case snapshots;
- organization activity;
- user notifications;
- organization member/reviewer records;
- saved structured sports objects;
- versioned personal and organization workspaces;
- NBA data releases;
- launch checks and consolidated readiness.

Flutter repositories are remote-first with local fallback. The local application remains usable during development or a temporary API outage, but a reachable launch backend becomes the shared source across browser sessions.

## Workspace persistence

Authenticated analysts use a personal primary workbook. Organization administrators use an organization primary workbook. Each save writes a complete workbook snapshot and an immutable numbered version; the latest 50 versions are retained. Local cells remain the offline fallback.

The current Flutter spreadsheet remains a fixed-grid implementation. Dynamic sheets, full spreadsheet formulas, large-table virtualization, concurrent editing, granular permissions, and XLSX compatibility remain separate product work.

## 2025–26 data-release architecture

The client reads `assets/data/nba/launch/season_config.json` and attempts to load:

```text
assets/data/nba/terminal_seed/nba_2026
```

Until that release exists and passes certification, the application uses the existing validated development seed:

```text
assets/data/nba/terminal_seed/nba_2025
```

The user-facing launch-status chip identifies:

- supported season;
- certified or development fallback data;
- shared backend or local mode;
- validation status;
- resolved asset path;
- warehouse generation timestamp;
- launch blockers.

The product therefore never silently represents the 2024–25 fallback as the completed 2025–26 release.

## Overnight release build

Run:

```bash
bash scripts/overnight_launch_build.sh
```

The pipeline:

1. verifies or prepares the local raw source catalog;
2. builds `data/warehouse/nba_2026.sqlite`;
3. exports the compact terminal seed;
4. exports complete player game logs and standings;
5. performs release-specific reconciliation checks;
6. updates the release manifest only after validation passes;
7. copies the validated release into Flutter assets;
8. activates the 2025–26 configuration only after successful certification;
9. compiles and smoke-tests the launch backend;
10. runs Flutter analysis, the complete test suite, and a release web build;
11. records timestamped logs and a machine-readable final report.

A failed build does not activate incomplete data.

## Dataset certification

Launch validation currently requires:

- all required release files;
- season end year 2026;
- exactly 30 teams and unique IDs;
- 30 team records and standings rows;
- at least 1,230 loaded games;
- unique game IDs;
- exactly two team-game rows per game;
- at least 400 player identities and season summaries;
- at least 10,000 complete player-game rows;
- sufficient search identities;
- passing base-pipeline validation;
- no missing game dates;
- no invalid game scores;
- no duplicate player-game identities.

These thresholds are minimum release gates, not a substitute for manual reconciliation of schedule scope, Play-In, playoffs, awards, rosters, transactions, contracts, and source rights.

## CBA evaluator

The transaction evaluator now calculates a modeled maximum incoming salary rather than returning only a generic salary-matching warning. It supports:

- cap-room matching;
- standard traded-player matching;
- aggregated standard matching;
- expanded below-first-apron matching with a season-scaled allowance;
- removal of the additional allowance for teams beginning or ending above the first apron;
- second-apron incoming, aggregation, cash, and exception blockers;
- hard-cap checks;
- no-trade consent;
- recently signed and poison-pill review;
- date-aware recently-acquired aggregation review;
- Stepien, pick-term, and roster assumptions.

The evaluator remains a preliminary workflow tool. Final approval still requires sourced contracts, protected compensation, complete team salary, exact transaction dates, hard-cap trigger history, verified draft ownership, and legal review of every applicable CBA provision.

## Launch-readiness boundary

`/v2/launch/readiness` separates repository work from external launch requirements. The external state includes:

- authentication provider or reviewed first-party auth operations;
- managed database;
- payment provider;
- approved data rights;
- public community enablement.

Community and messaging remain disabled until moderation, block/mute controls, operator audit logs, rate limits, and incident procedures are ready.

## Work that still requires external action

The repository cannot independently complete:

- acquiring or approving commercial data rights;
- obtaining external identity, email, MFA, payment, hosting, database, monitoring, or object-storage credentials;
- production DNS and certificates;
- privacy, terms, trademark, and licensing legal review;
- payment settlement and tax configuration;
- customer support staffing and incident-response operations.

The code represents these as explicit blockers rather than simulated integrations.
