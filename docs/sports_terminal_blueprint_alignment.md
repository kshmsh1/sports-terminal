# Sports Terminal Blueprint Alignment

This document translates the current NBA build into a simpler implementation rule: **Sports Terminal is an operating system built on one canonical sports graph, while the consumer website is a clean, traditional website view over that graph.**

## Product architecture

Every capability should belong to one of four layers:

1. **Sports Data Layer** — canonical players, teams, franchises, games, seasons, events, possessions, statistics, lineups, shots, rosters, contracts, transactions, injuries/availability, drafts, awards, officials, facilities, ownership, league rules and source provenance.
2. **Sports Intelligence Layer** — comparisons, visualizations, derived metrics, scouting views, projections, simulations, natural-language query, alerts, model outputs and reproducible research.
3. **Sports Workflow Layer** — watchlists, saved queries, notebooks, spreadsheets, reports, trade scenarios, front-office models, shared workspaces and publication drafts.
4. **Sports Network Layer** — profiles, messaging, communities, research publication, creator distribution and organization collaboration.

The NBA build is the reference implementation for these layers. New work should reuse the same entity graph instead of creating separate player/team/game objects for different screens.

## Website UX rule

The public/product website should feel like a conventional modern sports website, not like a Bloomberg terminal skin.

Primary navigation should remain small and legible. The core basketball navigation is:

- Home
- Stats
- Advanced Stats
- Lineup Analysis
- Trade Machine

Additional top-level or More-menu destinations may expose Front Office, Research and Community. Python Lab and Excel Workspace can be visible as detached tools without being required by the core website experience.

Pages should use familiar website patterns: page titles, filters, responsive tables, cards only where they add information density, obvious links, stable breadcrumbs/context, and restrained use of gradients or terminal-style chrome.

## Canonical object behavior

A player name or team name should resolve to one canonical object everywhere. Clicking the same player from Stats, Advanced Stats, awards, game logs, a dashboard or search should open the same player page.

Player pages should progressively combine:

- identity and position history
- regular-season and playoff career tables
- advanced-stat families
- game logs
- awards and honors grouped by award with winning years
- team history
- contract data where sourced
- draft data
- source lineage

Team pages should follow the same principle for roster, season history, team stats, advanced metrics, games, transactions, awards/franchise history and front-office context.

## Observe-to-workflow action grammar

The platform should make it natural to move from a fact into work. The long-run action grammar is:

`Observe → Investigate → Compare → Model → Save → Share → Discuss → Monitor → Export`

Those actions should become reusable behaviors attached to canonical objects rather than one-off screen buttons.

## Data/runtime rule

Historical NBA pages are static. Data acquisition libraries and external providers are build-time tools. The browser should not need NBA.com, Basketball-Reference, SportsDataverse or pbpstats to render historical pages.

The active season can use a live overlay, but it should periodically snapshot locally and become immutable historical data once finalized.

## Provenance rule

Every data family should be able to answer:

- where did this value come from?
- what provider/version/capture produced it?
- what canonical entity does it map to?
- what transformation created the displayed metric?
- are there competing source values?

Missing data should remain missing. Sports Terminal should not invent values to make the UI look complete.
