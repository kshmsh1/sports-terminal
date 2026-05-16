# NBA Stats Ingestion Strategy

## Objective

The first working NBA MVP should prefer NBA.com/stats as the primary source target for statistical data, while keeping the app itself local-first, stable, and zero-cost. The Flutter application should not scrape NBA.com/stats live from the UI. Instead, any future ingestion should happen outside the app through a deliberate source-discovery and snapshot process.

## Working Principle

The pipeline should be:

1. Identify the relevant NBA.com/stats table or structured response.
2. Confirm permitted-use posture before automated collection.
3. Capture a raw local snapshot.
4. Normalize the snapshot into Sports Terminal JSON assets.
5. Validate joins, required fields, null handling, row counts, source IDs, and as-of metadata.
6. Load the normalized asset through `NbaAssetRepository`.

## Why not live scraping inside Flutter?

Live scraping from the app would make the prototype brittle, slow, and dependent on website behavior. It would also create avoidable source-rights and request-rate risk. The app should behave like a terminal over curated local datasets first.

## First source targets

The first target should be player identity, because every other player-linked table depends on stable player IDs. The second target should be traditional player-season stats. The third should be team-season stats and standings. After that, the app can add games, awards, draft picks, rosters, transactions, and deeper game logs.

## MVP datasets

The minimum useful NBA statistical prototype needs:

- `player_profiles.json`
- `player_traditional_by_season.json`
- `team_by_season.json`
- `standings_records.json`
- `playoff_series_records.json`

Games, awards, draft history, rosters, and transactions are important but can follow after the first player/team/season/stat loops work.

## Guardrails

No fake records should be used. Missing values should remain blank, not zero. Source metadata should be preserved in every row. Any automated source collection should use request minimization, local caching, and manual review before normalized assets are published.
