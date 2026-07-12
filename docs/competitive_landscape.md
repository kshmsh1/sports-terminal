# Sports Terminal Competitive Landscape

This document turns the current NBA product market into a build target. The goal is not to copy any single site. The goal is to absorb the jobs users hire those sites for, combine them in one coherent workflow, and make the product feel faster, more connected, more social, and more useful than switching across many tools.

## Core thesis

The NBA analytics web is fragmented. A serious fan, fantasy manager, writer, bettor, or front-office-style user has to move between natural-language stat search, official box scores, advanced impact metrics, play-by-play tools, lineup/on-off tools, salary/cap tools, trade machines, community simulators, articles, fantasy ranks, and spreadsheets.

Sports Terminal should become the connective layer: one account, one workspace, one command/search layer, one player/team/game identity graph, and one backend that remembers the user's favorites, watchlists, workbooks, posts, messages, and scenarios.

## Competitor map

| Competitor / category | What users go there for | What Sports Terminal should absorb | How we beat it |
| --- | --- | --- | --- |
| StatMuse | Natural-language stats, quick social-ready facts, trending stats, news/standings context. | A command bar that answers stat questions, returns cited tables, creates charts, saves queries, and exports results into workbooks/articles. | Combine natural-language search with transparent source tables, reproducible query history, spreadsheet export, and team/player/game context pages. |
| NBA.com/stats | Official stats, players, teams, leaders, lineups, clutch, shot dashboards, tracking, hustle, box scores, fantasy news, articles. | Official-style stats taxonomy, player/team/game stat pages, shot charts, tracking-like categories, leaders, lineups, glossary, weekly spotlights. | Make it cleaner, faster, more customizable, less fragmented, with saved views, user workspaces, commentary, and community discussion attached to every entity. |
| Cleaning the Glass | Filtered basketball stats, garbage-time/heave removal, percentiles, transition/halfcourt splits, on/off, position context, pro-quality interpretation. | Possession-quality filters, percentile explanations, garbage-time toggles, halfcourt/transition-style breakdowns, on/off and role context. | Expose methodology, let users toggle raw vs adjusted views, connect to articles/workspaces, and make every number explain itself. |
| Dunks & Threes | EPM, player impact, team ratings, predictions, player/team/game dashboards, API access, interactive visuals. | Player impact board, predictive player/team/game cards, win probability, team strength, percentile dashboard, API-ready backend. | Make impact metrics one layer among many, not the whole product; connect impact ratings to fantasy, salary, trade, game, and community workflows. |
| BBall Index | Player grades, LEBRON-style impact, roles/archetypes, matchup context, offensive/defensive skill decomposition. | Role cards, archetype labels, matchup difficulty, skill grades, percentile traits, player comparison modules. | Build explainable role/skill cards from transparent source stats first, then support proprietary or custom models later. |
| PBP Stats | Play-by-play, on/off, lineups, possession-level splits, shot/score/event context. | Possession explorer, player/team on-off pages, lineup combinations, score-margin filters, event queries, WOWY-style surfaces. | Put PBP tools inside player/team/game pages and workbooks instead of making users build every query from scratch. |
| databallr | Large toolset: stats, WOWY lineups, dashboards, live, shot quality, contracts, team compare, rankings, games like SixRings, WNBA support. | Tool launcher, player dashboards, WOWY, team compare, shot profile similarity, rankings, games, shareable lists, WNBA expansion path. | Reduce tool sprawl by tying every tool to a shared object graph and user workspace; make workflows feel guided rather than isolated. |
| NBA RAPM | Clean player-impact history, peak windows, RAPM/RAPTOR/DARKO/LEBRON/LAKER comparison. | Historical impact timeline, peak windows, all-in-one metric comparison, uncertainty/era context. | Let users compare metrics side by side and understand where they disagree instead of treating one model as truth. |
| SalarySwish / Spotrac / HoopsHype | Salaries, cap sheets, contracts, exceptions, transactions, free agents, waivers, trade machine, CBA reference. | Salary/cap module, contract cards, cap tables, free-agent tracker, transaction timeline, CBA tooltips. | Integrate cap data with player performance, role, fantasy, and trade simulator so financial analysis is not isolated from basketball analysis. |
| Fanspo / HoopsMatic | Community posts, trade machines, mock drafts, grid builders, roster manager, poll/social workflows. | Trade machine, roster builder, mock draft, grid/list creator, community feedback, comments, polls, scenario sharing. | Make social creations data-backed and reusable: trades become cap-valid, lineup-impact-aware, saveable, discussable, and exportable. |
| Dynatyze / Hooper / fantasy tools | Dynasty rankings, trade calculators, league imports, advanced fantasy metrics, player notes, shot/highlight creation. | Fantasy watchlists, player values, trade calculator, league import, highlights/shot-story cards, alerts. | Combine fantasy decisions with NBA stats, impact metrics, contracts, news, community, and spreadsheet modeling. |
| ESPN | Mainstream news, scores, standings, stats, teams, players, fantasy ecosystem. | News rail, scores, standings, team/player hubs, fantasy hooks. | Go deeper and more customizable while still keeping a friendly consumer-level entry point. |

## Product pillars we need to win

### 1. Command layer

Sports Terminal needs a universal command/search bar that accepts natural-language questions, player names, teams, games, IDs, and saved query templates. The output should never be a black box. Every answer should have a table, source, filters, and one-click actions: save to workspace, create chart, compare, add to watchlist, share to community, or draft article.

### 2. Entity graph

Everything should connect through canonical entities: player, team, game, season, lineup, contract, article, community thread, workspace cell range, fantasy asset, and scenario. A user should be able to move from Shai Gilgeous-Alexander to his game log, on/off profile, fantasy value, contract, trade scenarios, team context, articles, posts, saved charts, and messages without feeling like they changed products.

### 3. Player pages that become command centers

A player page should include: overview, per-game/per-75/advanced toggle, game log, recent form, highs/lows, role/archetype, impact metrics, shot profile, lineup/on-off context, fantasy panel, contract/cap panel, article/thread modules, saved notes, comparison, and export to workspace.

### 4. Team pages that feel front-office grade

A team page should include: record, schedule, roster, salary/cap table, rotations, lineup combinations, four factors, clutch, opponent profile, momentum, player roles, trade needs, fantasy watch, team room, and articles.

### 5. Game pages with full postgame workflow

A game page should include: score, pace, periods, team stats, player box scores, advanced box, four factors, lead/momentum chart, play-by-play events, lineup stints, big runs, top performers, fantasy impact, article recap draft, and comments.

### 6. Excel-like workspace

The workspace should become where serious users build their own boards. It needs editable cells, formulas, copy/paste, templates, imported stat tables, scenario outputs, saved charts, and backend sync. The long-term goal is not a generic spreadsheet; it is Excel for sports objects.

### 7. Community tied to data objects

Community should not be a disconnected forum. Every player, team, game, trade, article, and workbook should support discussion, but with moderation, reporting, mute/block, and quality filters from day one.

### 8. Fantasy and dynasty workflows

Fantasy should use the same data graph as the NBA product. A watchlist player should carry box-score trends, role changes, minutes volatility, schedule context, health/news notes, sentiment, trade value, league roster status, and alerts.

### 9. Front-office simulator

A trade machine alone is not enough. We need a roster/cap/scenario system that can combine CBA legality, salary matching, player impact, rotation fit, pick inventory, timeline, fantasy impact, community voting, and article generation.

### 10. Trust and methodology

Most analytics sites force users to trust labels. Sports Terminal should explain every stat, show formulas where possible, separate raw vs adjusted views, show sample sizes, and flag missing data or unsupported claims.

## Differentiation requirements

| Requirement | Why it matters |
| --- | --- |
| One workspace for every workflow | Users should stop exporting screenshots and manually stitching tools together. |
| One identity graph | Player/team/game/fantasy/community/CMS/backend objects should all connect. |
| Saveable state | Favorites, watchlists, workbooks, posts, messages, backend sync, and queries must persist. |
| Source transparency | Every stat output should show source, filters, date, and method. |
| Stats plus storytelling | Articles should be generated from real data modules and attached to entities. |
| Social proof | Threads, polls, ranked lists, and community reactions should sit directly on data objects. |
| Scenario modeling | Trades, lineups, fantasy, and roster moves should create reusable scenarios, not dead-end pages. |
| Friendly surface, terminal depth | Casual fans should understand the page, but expert users should be able to drill down. |

## Feature backlog by phase

### Phase 1: beat the fragmented analytics tab problem

- Add a Competitor/Market Map operator screen.
- Wire Backend Sync Center into direct Profile/NBA/Fantasy/Workspace/Community screens.
- Build routed player/team/game pages.
- Add saved query templates and source/method footers.
- Add workspace table imports from player/team/game pages.

### Phase 2: beat the advanced analytics sites

- Add percentile cards, role/archetype cards, impact timeline, on/off/WOWY, lineup combinations, and possession filters.
- Add transparent metric comparison: BPM, on/off, RAPM-like placeholders, DPM/EPM-style import slots, and future custom models.
- Add chart blocks for trends, shot profile, game log, and team momentum.

### Phase 3: beat cap/trade/fantasy/community silos

- Add salary/cap tables, contract cards, CBA glossary, transaction timeline, and trade scenario model.
- Add fantasy league import placeholders, roster board, watchlist alerts, dynasty value context, and trade calculator.
- Add community objects for trades, polls, tier lists, grids, and data-backed posts.

### Phase 4: become the sports terminal

- Hosted backend, auth, roles, billing, moderation, audit logs, real deployments, current-season ingestion, live data agreements, and official/commercial data decisions.
- Public API and workspace sharing.
- Multi-sport expansion only after NBA is coherent and sticky.

## Build principle

Do not add another isolated tab unless it either becomes a reusable component inside an entity page or a serious operator surface. Every feature should answer one of these questions: does it make a player page better, a team page better, a game page better, a workspace better, a community object better, or a backend/admin workflow more real?
