# NBA static data architecture

Sports Terminal treats historical NBA information as a compiled data product, not as a set of browser-time API calls.

## Core rule

Historical pages must render from versioned local/static artifacts. The browser must not need NBA.com, Basketball-Reference, SportsDataverse, ESPN or pbpstats to answer a historical query after the data has been acquired and materialized.

The intended flow is:

`source capture/release -> raw immutable landing zone -> normalization -> canonical entity graph -> static website shards -> Flutter website`

Dynamic services remain useful for accounts, saved work, community, mutable front-office workflows and future live-season ingestion, but they are not required to render completed historical seasons.

## Source roles

### Canonical warehouse

The canonical SQLite warehouse remains the identity and historical backbone for players, teams, seasons, games and season-level facts. Every supplement should resolve to canonical entity identifiers before it is allowed to influence website output.

### NBA.com Stats

NBA.com is the preferred official source for modern league-dash, advanced, tracking-adjacent, lineup, hustle and defended-shooting datasets. Existing authorized response imports are normalized and materialized locally by `tools/nba_com_static_enrichment.py`.

Historical captures should be kept immutable and fingerprinted. Do not make a browser-time NBA.com request to fill a dash on the Advanced Stats page.

### SportsDataverse / hoopR

SportsDataverse release datasets are the preferred bulk acquisition path where equivalent historical datasets are published. The release loaders are especially valuable for play-by-play, possessions, lineups, shots, rosters, box scores, game logs, league-dash datasets, standings, officials, coaches and draft data.

Use `tools/import_sportsdataverse_nba.py` for explicit acquisition. The imported files are source material, not a runtime dependency.

### Basketball-Reference

Basketball-Reference is a historical reference and supplemental source for season totals, advanced statistics, schedules, standings, shooting splits, player game logs and other historical surfaces. `tools/import_basketball_reference_web_scraper.py` provides an explicit acquisition adapter for the documented `basketball_reference_web_scraper` client. Existing direct/crawler tooling remains useful for tables not covered by that client.

Basketball-Reference data should be canonicalized before use. Never let provider-specific player/team strings become a second identity graph.

### pbpstats

pbpstats is primarily an event/possession processing layer. Its local-data-directory design is a good match for Sports Terminal: download/capture once, persist the raw responses, apply known event-order fixes/overrides, derive enhanced play-by-play and possessions, then publish static shards.

Use `tools/inventory_pbpstats_cache.py` to inventory a local cache. A future materializer can map enhanced events/possessions onto canonical Game, Event, Possession, Player and Team objects without introducing runtime calls.

## Missing-data policy

A missing metric is not a reason to remove the metric from the product. Advanced Stats should preserve the requested column and render `—` when the selected season/source combination cannot support it.

Every metric should eventually carry four pieces of metadata:

- canonical key
- human definition
- source/provenance
- coverage window / derivation policy

That makes a stat glossary also function as a data-lineage surface.

## Rate conversion policy

Counting statistics should have one stable canonical base. Per-game output should be derived from totals and games where possible; Per 36/48 from minutes; Per 75/100 from possessions; totals should never be reconstructed by multiplying an already rate-adjusted value by an unrelated denominator.

Percentages, ratios and ratings must not be multiplied when rate mode changes unless the definition explicitly requires a different calculation.

## Source coverage manifest

Run:

```bash
python3 tools/build_nba_source_coverage_manifest.py
```

This writes `web/data/nba_static/source_coverage.json`, summarizing which static raw-source families are present locally and what each is intended to power. It deliberately performs no network requests.

The launch path may regenerate this manifest after historical materialization so the website can expose source health/coverage without contacting upstream providers.

## Acquisition examples

SportsDataverse release datasets:

```bash
python3 tools/import_sportsdataverse_nba.py --list
```

Basketball-Reference documented client adapter:

```bash
python3 tools/import_basketball_reference_web_scraper.py --list
python3 tools/import_basketball_reference_web_scraper.py \
  --seasons 2022:2026 \
  --dataset player_totals \
  --dataset player_advanced \
  --dataset schedule \
  --dataset standings \
  --dataset shooting
```

These are acquisition commands. They should not be run from page rendering code.

## Product architecture

The NBA implementation should enforce one canonical object graph. A player link from Stats, Advanced Stats, an award, a game, a lineup or a contract must resolve to the same Player object. The same rule applies to Team, Season, Game, Possession, Event, Contract, Award and Transaction objects.

This keeps the data layer compatible with the larger Sports Terminal design: information -> intelligence -> workflow -> network, all sharing canonical entities rather than duplicating provider-specific models.
