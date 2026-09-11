# Sports Terminal protocol

Sports Terminal should be built as sports infrastructure with a traditional, comprehensible website as its first public interface. The NBA implementation is the reference implementation of a protocol that can later support other leagues and sports without creating parallel identity systems or one-off products.

## Product thesis

The product is not a collection of independent pages. It is one canonical sports graph exposed through four layers:

1. **Sports Data Layer** — canonical identities, seasons, schedules, games, events, possessions, box scores, statistics, rosters, contracts, transactions, injuries/availability, drafts, awards, officials, venues, league rules and source lineage.
2. **Sports Intelligence Layer** — queries, comparisons, charts, derived metrics, impact models, projections, simulations, scouting analysis, natural-language research and alerts.
3. **Sports Workflow Layer** — saved queries, watchlists, boards, notebooks, spreadsheets, models, dashboards, reports, trade scenarios, front-office work and organization workspaces.
4. **Sports Network Layer** — publishing, messaging, community, shared research, professional identity, discussion and eventually marketplace / transaction workflows.

The website should make these layers feel connected without making the interface feel like a terminal emulator.

## Canonical entity graph

There is one canonical object for each real sports entity:

- Player
- Team
- Franchise
- Season
- Game
- Possession
- Event / play
- Lineup / stint
- Shot
- Contract
- Transaction
- Draft pick
- Award / honor
- Official
- Venue
- Research object

Provider IDs belong in crosswalks and provenance. They do not create new product universes.

A Jayson Tatum link in Stats, Advanced Stats, Awards, Trade Machine, Research, Contracts and Community must resolve to the same canonical Player object.

## Interaction grammar

Every important entity or data point should be able to move through the same action grammar:

**Observe → Investigate → Compare → Model → Save → Share → Discuss → Monitor → Export**

Not every action needs to be enabled on day one, but the object model should support them consistently.

Examples:

- a player name opens the Player object;
- a team abbreviation opens the Team object;
- a game opens the Game object;
- a chart point can reveal the underlying row;
- a metric can open its glossary / provenance;
- a saved comparison can become a research object;
- a trade scenario can be saved and shared;
- a watchlist can later power alerts.

## Historical runtime policy

Historical basketball pages are local-first and static-first.

The browser must not call NBA.com, Basketball-Reference, SportsDataverse or pbpstats in order to render completed historical pages. Acquisition is a separate explicit workflow.

The static rebuild compiles the canonical warehouse plus local enrichment into `web/data/nba_static`.

The historical browser path should therefore remain deterministic:

1. acquire source data explicitly;
2. store raw source payloads locally;
3. normalize and preserve source-specific definitions;
4. resolve provider IDs to canonical entities;
5. materialize immutable static serving artifacts;
6. validate the corpus;
7. serve Flutter Web from the static corpus.

A live current season can use a separate overlay. That overlay should be periodically snapshotted and, after the season is certified complete, promoted into the immutable historical corpus.

## NBA source roles

### Canonical Sports Terminal warehouse

Role: identity backbone and broad historical reference.

Use for canonical players, teams, franchises, seasons, games and the cross-era graph.

### NBA.com Stats captures

Role: official modern enrichment.

Keep distinct source families distinct. Traditional, Advanced, Misc, Scoring, Usage, Hustle, defended-shooting, tracking, game-log and lineup fields must not be merged simply because their names look similar.

### SportsDataverse / hoopR release datasets

Role: bulk acquisition without repeatedly scraping source websites.

The SportsDataverse ecosystem exposes prebuilt release datasets for play-by-play, schedules, team/player box scores, rosters, standings and season statistics. Recent releases also expose stats.nba.com-derived possessions, lineups, shots, box scores, game logs, league-dash data, officials, coaches and draft data.

Sports Terminal should prefer these prebuilt releases for broad historical acquisition where they contain the needed grain. They are acquisition-time dependencies, not browser dependencies.

### pbpstats

Role: possession and event enrichment.

pbpstats can attach on-court lineups to events, split games into possessions, preserve possession start/end context, expose shot-zone detail and correct common raw event-order problems. The recommended Sports Terminal pattern is to maintain a local cache and consume it from disk.

### Basketball-Reference

Role: historical backfill and cross-check.

Basketball-Reference remains valuable for historical player/team totals, advanced totals, schedules, standings, game logs, shooting splits, rosters and some contract surfaces. Existing Sports Terminal source-index mappings should remain the identity bridge.

The `basketball_reference_web_scraper` project may be used for explicit acquisition into raw local storage. It must not become a runtime dependency of the website.

### Curated awards supplement

Role: award and honor backfill.

Awards should preserve the actual honor and tier: First-Team All-NBA is not the same object as generic All-NBA; First-Team All-Defense and Second-Team All-Defense are distinct honors. Player dossiers should aggregate these canonical award rows into human-readable histories.

## Data-quality rules

1. Never fabricate a value because the UI has a column for it.
2. Never silently substitute a similarly named metric with a different definition.
3. Preserve source, definition, season type, rate basis and grain.
4. Treat regular season and playoffs as distinct samples everywhere.
5. Keep raw totals available so per-game / per-minute / per-possession rates can be derived reproducibly.
6. Preserve the original numerator and denominator when possible.
7. Validate season IDs, JSON shape and rate sanity before launch.
8. Historical files must never fall through to HTML route responses.
9. User-visible dashes are preferable to invented or semantically wrong values.
10. Every derived metric should be traceable to inputs and a formula/version.

## Stats product model

### Stats

The conventional Stats page is the broad historical box-score table. It should prioritize speed, scanability and stable definitions.

Core controls:

- season;
- Regular Season / Playoffs;
- player search;
- team;
- position;
- qualification filters;
- sortable columns;
- rate basis where appropriate;
- sticky headers / first column;
- direct player/team navigation;
- export.

### Advanced Stats

Advanced Stats is a research table, not a dumping ground for every metric in one row. Metrics should be organized by basketball question:

- Overview
- Shooting & Efficiency
- Playmaking & Creation
- Defense
- Rebounding
- Impact
- Rate Adjusted
- Clutch
- Gravity & Spacing
- On / Off
- Lineups & Possessions
- Movement / Tracking
- Fouls / Discipline
- Physical / Bio where appropriate

Columns with missing historical source coverage should remain present and show `—`.

### Games / possessions / events

Game, possession and event objects are first-class. Event-level and possession-level data should be usable by Clutch, On/Off, Lineups, shooting-context, research and later video-linked workflows.

## Research catalog

`tools/nba_research_catalog.py` builds `web/data/nba_static/research_catalog.json`.

The catalog intentionally separates dataset families from provider inventory. It records:

- grain;
- source preference;
- product surfaces;
- static-runtime policy;
- availability status;
- coverage notes.

The Data Coverage page reads this catalog so future acquisition gaps are visible without destabilizing the current website.

## Validation

`tools/validate_nba_static_corpus_v2.py` is the pre-launch static contract validator.

It checks:

- manifest / season catalog presence;
- valid one-year season IDs;
- both `regular.json` and `playoffs.json` for every season;
- JSON rather than HTML fallthrough;
- core index documents;
- basic rate sanity for impossible GP / MPG / PPG values.

This should become part of release confidence checks before Sports Terminal is treated as production-ready.

## Scaling beyond the NBA

The NBA implementation should prove the universal primitives rather than bake NBA assumptions into every layer.

The later WNBA / G League / NCAA / international basketball and multi-sport expansions should reuse:

- canonical identity contracts;
- source/provider registry;
- dataset catalog;
- provenance model;
- action grammar;
- research objects;
- static-historical / live-overlay pattern;
- workflow and network layers.

The long-run moat is not one metric or one page. It is the dependency created when authoritative information, analysis, proprietary work and collaboration all resolve through the same canonical sports graph.
