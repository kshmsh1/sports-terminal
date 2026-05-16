# Sports Terminal Data Strategy

## Current decision

Sports Terminal will start with the NBA and will be built as a historical-first, data-ready product. The initial product should organize real NBA information wherever it is available, while keeping unconnected data fields blank instead of filling them with fake values.

The app should not depend directly on any one data vendor or website. The Flutter interface should read from a clean internal data layer. That data layer can later be backed by local JSON, CSV imports, official league data, a licensed provider, or a custom internal API.

## Data principles

1. Do not show fake sports statistics in product-facing screens.
2. Use stable real reference data immediately, such as teams, conferences, divisions, player identity, seasons, awards, and franchise history.
3. Use nullable fields for data that is not connected yet.
4. Track source, season, season type, and as-of date for every dataset.
5. Keep current/live data separate from historical datasets.
6. Avoid building features that require commercial data rights until the product has a lawful data source.

## NBA-first scope

The first sport is NBA only. The initial data model should eventually cover:

- Teams and franchise history
- Players and player identity
- Seasons
- Rosters
- Traditional player and team stats
- Advanced player and team stats
- Game logs
- Box scores
- Playoffs
- Awards
- Draft history
- Transactions
- Injuries and availability
- Contracts and salary data, if a lawful source is identified
- Bios, height, weight, college, country, draft year, draft pick, and position

## Historical-first approach

The first data priority is historical NBA information rather than live/current data. Live data creates more technical complexity and more licensing risk. Historical data allows the product to become useful without needing a real-time feed.

The initial goal is to create a structure that can store season-by-season NBA data as snapshots. Each snapshot should include metadata such as:

- source
- source URL or provider
- season
- season type
- per-mode
- pulled_at
- license status or usage note

## Official NBA source preference

Official NBA data should be preferred when legally and technically feasible. NBA.com/stats has official player, team, leader, all-time, bio, box score, tracking, shooting, hustle, and related statistics pages. Any use of NBA.com statistics should include attribution and should remain private and non-commercial unless formal rights are obtained.

## Commercial data provider context

Sports data companies typically obtain data through league partnerships, commercial licensing, official data feeds, event collection systems, video and optical tracking, broadcast monitoring, editorial operations, and data validation workflows. Major providers include Sportradar, Genius Sports, Stats Perform/Opta, and Elias Sports Bureau.

Sports Terminal should be built so a future provider can be plugged in without rewriting the app.

## Product architecture

The app should use this pattern:

Flutter UI -> data services -> local normalized data -> future API/provider

Flutter should not call NBA.com directly from screens. Instead, ingestion scripts should pull and normalize data into local files or a future database/API.

## Placeholder policy

Missing values should render as blank, dash, or "not available." They should not render as zero unless the true value is actually zero.

Example:

- pointsPerGame = null -> display "—"
- pointsPerGame = 0.0 -> display "0.0"

## Near-term implementation

1. Keep the real NBA team directory.
2. Remove or quarantine fake player stat data from product-facing screens.
3. Add nullable data models for players, teams, seasons, stat lines, and source metadata.
4. Build UI tables that handle missing fields gracefully.
5. Add a local historical data folder under assets/data/nba/.
6. Add scripts/nba/ for future ingestion.
7. Start with one historical data slice, preferably player traditional regular-season stats, once a safe source workflow is selected.
