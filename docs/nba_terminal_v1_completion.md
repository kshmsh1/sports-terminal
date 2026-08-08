# NBA Terminal v1 Completion Architecture

## Goal

The NBA-first Sports Terminal should behave as one professional operating system, not as a collection of individually capable screens. The canonical historical warehouse now spans roughly eight decades of NBA/BAA/ABA history, so the primary product problem is convergence: every research object, season, workflow and decision surface should be discoverable and routable through one terminal layer.

This document defines the current NBA Terminal v1 completion boundary. It distinguishes implemented product architecture from external production dependencies that cannot be solved by application code alone.

## Unified operating model

The product is organized around five shared primitives:

1. **Canonical sports objects** — players, teams, franchises, seasons, games, awards, All-Star selections, drafts, contracts, draft assets and transaction cases.
2. **Shared NBA research context** — current or historical scope plus active season, league, segment and selected player/team/game.
3. **Terminal commands** — deterministic routable functions such as Stats, Analytics, Historical Intelligence, Entity Intelligence, Trade Machine, Workspace and Python Lab.
4. **Persistent working state** — terminal favorites/recents, research contexts, entity watchlists, workspaces, routed datasets and front-office scenarios.
5. **Explicit data integrity** — source registry, coverage by domain/era, field provenance, canonical conflicts and no fabrication of unavailable historical fields.

## NBA Terminal desks

### Command

The Command desk is the primary entry point. It searches two universes simultaneously:

- product functions and terminal commands;
- canonical historical NBA objects.

Command resolution supports direct IDs, shortcuts and natural language aliases. Examples include `STAT`, `HIST`, `PY`, `TRD`, `all time records`, `salary matching apron`, `spreadsheet model`, and `player dossier`.

Canonical object search spans players, teams, franchises, seasons and games. Search results can be inspected without leaving the terminal and historical objects can be activated into the shared NBA research context.

### Season Index

The Season Index exposes the canonical season dimension for NBA, ABA and BAA. Each season reports bounded counts for teams, players, games and awards. A season can be activated directly into shared historical context and then opened in Stats, Analytics, Historical Intelligence or Entity Intelligence.

### Data & Coverage

The terminal manifest reports:

- canonical season span;
- counts for players, teams, franchises, seasons, games, player seasons, team seasons, player games, awards, All-Star selections and draft rows;
- source registry and licensing metadata;
- domain-by-league coverage ranges;
- canonical build metadata;
- field provenance and material conflict availability;
- explicit integrity guarantees.

The coverage surface is intentionally descriptive rather than inferential. If a statistic is unavailable for an era, the terminal reports the gap instead of creating a modeled substitute and labeling it historical fact.

### Context & Recents

All primary NBA research surfaces share the same context store. Users can move between current and historical analysis without re-entering the season or selected entity. Recent contexts are deduplicated and restorable.

### Platform Map

The Platform Map exposes the broader terminal as one routable system. Current command groups include:

- Core;
- NBA;
- Research;
- Front Office;
- Operations;
- Tools;
- Organization;
- Network;
- Account.

## Implemented NBA research system

The current product architecture includes:

- Stats Workstation;
- Analytics Suite;
- Historical Intelligence;
- Entity & Season Intelligence;
- NBA Universe;
- Research Command Center and persistent research boards;
- all-time leaderboards and peak/career/best-N analysis;
- cross-era comparison and era adjustment;
- historical game and play-by-play investigation where source coverage exists;
- franchise lineage across renames and relocations;
- player/team/franchise/season dossiers;
- awards, All-Star and draft history;
- canonical source conflicts and field provenance;
- current/historical compatibility with existing Stats and Analytics engines;
- entity watchlists and recent research contexts.

## Implemented modeling and front-office system

The broader product already includes:

- Trade Machine;
- cap/apron and salary-matching logic;
- front-office scenario modeling;
- versioned contracts and team financial positions;
- draft-asset registry;
- transaction ledger;
- personal and organization transaction cases;
- approvals, activity and notifications;
- multi-sheet workspace with formulas, imports, versions, permissions and conflict handling;
- routed sports-object packages;
- bounded Python runtime for analysis of routed datasets.

## Implemented platform and organization system

The application already includes:

- first-party authentication and session restoration;
- analyst, organization-admin and platform-admin entry paths;
- organization membership and governance controls;
- automation governance;
- customer onboarding and entitlement state;
- customer notification inbox;
- support-case workflows;
- incident-management state;
- moderated community publishing;
- blocks, mutes and sanctions;
- protected messaging;
- trust/safety audit state;
- platform launch/readiness status.

## Terminal persistence

The NBA Terminal now persists:

- favorite commands;
- recent commands;
- recent canonical search queries;
- current/historical research context;
- recent research contexts;
- entity watchlists;
- workbook state and versions;
- routed dataset history;
- front-office and trade scenarios through their existing stores.

The persistence model is deliberately offline-tolerant. Shared backend synchronization is used where supported, while local state remains a durable fallback for product continuity.

## Backend contract

The unified terminal adds:

- `GET /v2/nba/terminal/manifest`
- `GET /v2/nba/terminal/seasons`
- `GET /v2/nba/terminal/commands`

These routes are registered before the generic `/v2/nba/{season}/{dataset}` route so `terminal` cannot be interpreted as a season identifier.

The season index uses correlated counts rather than a player-season × team-season × game join. This preserves bounded query behavior against the full warehouse.

## Validation boundary

CI now validates the NBA Terminal on top of every existing historical-data contract:

- raw historical ingestion;
- canonical historical build;
- traded-player leaderboard semantics;
- historical seed compatibility;
- deep historical research;
- entity and season intelligence;
- unified terminal manifest/season/command contract;
- launch backend contracts;
- deterministic command matching;
- persistent terminal state;
- strict Flutter analyzer;
- complete Flutter test suite;
- release web build;
- pre-data readiness gate.

## What remains external to application-code completion

A codebase can be internally feature-complete while still not be public-production-ready. The existing completion-status API intentionally separates these states.

The remaining production dependencies are primarily external or operational:

- verified current-season contract/team-position/draft-asset population at launch thresholds;
- commercial data-rights approval for production distribution;
- managed production database configuration;
- payment-provider configuration if paid plans are launched;
- transactional email provider;
- production monitoring/observability provider;
- public-community approval;
- staffed moderation operations;
- staffed customer support;
- staffed incident response;
- production deployment, secrets, domains and infrastructure hardening.

These should remain visible as external launch blockers rather than being mislabeled as missing NBA Terminal product functionality.

## NBA-first completion principle

The platform remains intentionally NBA-first. The architecture is designed so future leagues and sports can reuse the terminal command, object-routing, context, workspace, Python, organization and platform layers, but no other sport should dilute NBA completion until the NBA product is operating at professional-terminal quality.
