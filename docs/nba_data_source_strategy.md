# NBA Data Source Strategy

Sports Terminal's NBA product should be **local-first and static-first for historical data**. Runtime website pages should not depend on stats.nba.com, Basketball-Reference, hoopR, sportsdataverse-py, pbpstats, or another external data source in order to render historical seasons.

The acquisition pipeline may use multiple providers, but every imported record should resolve into Sports Terminal's canonical entity graph and then be compiled into immutable website artifacts under `web/data/nba_static`.

## Core principles

1. **One canonical identity graph.** Player, Team, Franchise, Season, Game, Possession, Event, Contract, Award and related objects should have stable Sports Terminal identifiers. Provider-specific IDs are aliases, not product identities.
2. **Historical data is immutable at runtime.** Once a season is finalized, the website should read local static artifacts only. New seasons may use a live overlay while active and are promoted into the static corpus after completion.
3. **Preserve source lineage.** Imported rows retain provider, source key, provider IDs, capture/import time, release version where available, and transformation notes.
4. **Do not silently substitute metrics.** If a requested metric is not supported by the available source, render it as unavailable rather than replacing it with a similarly named value.
5. **Prefer prebuilt releases when possible.** Release datasets reduce fragile scraping and are ideal for large historical ingestion jobs.
6. **Keep raw and normalized layers.** Preserve raw provider captures separately from normalized canonical rows so transformations remain reproducible.

## Provider roles

### Sports Terminal canonical warehouse

Primary canonical source for identities, historical seasons, games, traditional player/team season statistics and cross-era entity relationships. The browser must never query this SQLite database directly; the build step compiles it into static JSON.

### NBA.com / Stats NBA captures

Official enrichment source for player/team base and advanced aggregates, hustle, defended shooting, usage/scoring/miscellaneous dashboards, game logs and lineups. Captures should be acquired outside the browser, normalized, stored locally and materialized into the static corpus.

### SportsDataverse / hoopR release datasets

Preferred bulk acquisition layer for NBA play-by-play, possessions, lineups, shots, schedules, box scores, rosters, standings, season statistics, officials, coaches and draft-oriented datasets when a released dataset exists. These are acquisition-time dependencies only.

### pbpstats

Possession/event enrichment layer. Use a local pbpstats cache to provide enhanced play-by-play, corrected event order where available, lineups on floor, possession boundaries and shot-zone context. The data directory should be persisted so repeated builds do not make the same source requests.

### Basketball-Reference

Historical backfill and independent cross-check layer. Useful targets include season totals, advanced season totals, schedules, standings, player game logs, shooting splits, rosters and contracts where available. Provider identities must resolve to canonical Sports Terminal entities before publication.

A practical Python acquisition option is `basketball_reference_web_scraper`. Its client should be wrapped as a provider adapter and should write raw/normalized local files rather than being called by Flutter at runtime.

### Curated awards

Awards and honors are a separate static history layer. Structured rows should be normalized before build time, especially team honors such as First/Second/Third-Team All-NBA, First/Second-Team All-Defense and First/Second-Team All-Rookie, where tier fidelity matters.

## Target local directory layout

```text
raw/
  basketball_reference/
    manifest.json
    player_season_totals/
    player_advanced/
    schedules/
    standings/
    player_game_logs/
    shooting_splits/
    rosters/
    contracts/
  sportsdataverse/nba/
    manifest.json
    ... downloaded release datasets ...
  pbpstats/
    inventory.json
    game_details/
    pbp/
    schedule/
    overrides/
  nba_com_stats/
    ... normalized endpoint captures ...
  curated/
    nba_awards.json
```

## Canonical import contract

Every provider adapter should produce or expose these fields when available:

- `provider`
- `dataset`
- `source_key`
- provider player/team/game IDs
- canonical player/team/game key after reconciliation
- `season_id` in `YYYY-YY` form
- normalized `season_type` (`regular` or `playoffs`)
- raw source path or source URL
- capture/import timestamp
- upstream release/version metadata
- source row payload or normalized metrics
- reconciliation status and conflicts

The canonical layer should prefer stable IDs, then provider crosswalks, then normalized names plus contextual checks. Name-only matching should be a last resort and unresolved rows must remain explicit.

## Source precedence

Recommended precedence by dataset family:

- identity: canonical warehouse → Basketball-Reference cross-check
- traditional player season: canonical warehouse → NBA.com → Basketball-Reference
- advanced player season: NBA.com → canonical warehouse → Basketball-Reference
- team season: canonical warehouse → NBA.com → SportsDataverse
- games/box scores: canonical warehouse → SportsDataverse → NBA.com → Basketball-Reference
- play-by-play: SportsDataverse → pbpstats → canonical warehouse → Basketball-Reference
- possessions/lineups: SportsDataverse → pbpstats → NBA.com
- shots: SportsDataverse → NBA.com → pbpstats → Basketball-Reference
- awards: canonical warehouse + curated award supplement

Conflicts should be recorded, not hidden. Sports Terminal may select one value for a product surface while retaining all competing source values in provenance/audit data.

## Product boundary

The browser-facing website should load historical NBA information from `web/data/nba_static`. Provider libraries belong in ingestion tooling, not in Flutter. This keeps Home, Stats, Advanced Stats, player pages, team pages, game pages, awards, draft and historical research usable without an external network dependency.
