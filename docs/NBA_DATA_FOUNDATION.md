# NBA data foundation

Sports Terminal's NBA website is deliberately local-first. Historical pages should render from immutable, versioned static artifacts built around one canonical entity graph. Acquisition is a separate workflow from browsing.

This document defines the source roles introduced by `tools/nba_data_foundation.py`.

## Runtime rule

The browser does **not** call NBA.com, Basketball-Reference, SportsDataverse, or pbpstats to render completed historical pages.

Acquisition tools may download or capture source data explicitly. Once those files are stored locally, the static compiler materializes them into `web/data/nba_static`. The dynamic Sports Terminal API remains useful for accounts, saved work, community, front-office edits and other mutable features, but historical statistics do not depend on it.

A rebuild writes:

- `web/data/nba_static/manifest.json`
- `web/data/nba_static/data_foundation.json`

The Data Coverage page reads the latter and shows which registered providers are actually present on disk.

## Source roles and precedence

### 1. Canonical Sports Terminal warehouse

Role: canonical identity and historical backbone.

Use it for canonical players, teams/franchises, seasons, games, player-season rows, team-season rows and stable cross-era links. Flutter reads compiled JSON, not SQLite.

### 2. NBA.com Stats captures

Role: official enrichment.

The existing `raw/nba_com_stats` capture/materialization system is the preferred source for official modern player and team metrics when those captures exist. Confirmed families include traditional, advanced, misc, scoring, usage, defense, violations, estimated advanced, defense dashboard, hustle, game logs and lineups.

Captures are materialized by `tools/nba_com_static_enrichment.py`; historical page rendering never performs an NBA.com request.

### 3. SportsDataverse / hoopR release datasets

Role: bulk historical data acquisition without repeatedly scraping source websites.

The SportsDataverse release loaders provide prebuilt season files for NBA play-by-play, schedules, box scores, rosters, standings and season statistics. Recent releases also expose stats.nba.com-derived datasets such as possessions, lineups, shots, game logs, league-dash tables, officials, coaches and draft data.

Use:

```bash
python3 tools/import_sportsdataverse_nba.py --list

python3 tools/import_sportsdataverse_nba.py \
  --seasons 2020:2026 \
  --all-defaults

python3 tools/import_sportsdataverse_nba.py \
  --seasons 1997:2026 \
  --dataset stats_possessions \
  --dataset stats_lineups \
  --dataset stats_game_logs
```

The importer intentionally lazy-loads the optional `sportsdataverse` package. It is not a web-app dependency.

Season values are end years: `2024` means `2023-24`.

### 4. pbpstats cache

Role: possession/event enrichment.

pbpstats is useful because it can attach lineups to every event, split games into possessions and expose start/end state and shot-zone context. It is especially valuable as a *file cache*: store/download once, then operate locally.

Sports Terminal does not invoke pbpstats on the web path. Inventory an already-downloaded cache with:

```bash
python3 tools/inventory_pbpstats_cache.py /path/to/pbpstats_data \
  --output raw/pbpstats/inventory.json
```

Expected directories are `schedule`, `game_details`, `pbp` and optional `overrides`.

### 5. Basketball-Reference

Role: historical backfill and cross-check.

The repository already contains Basketball-Reference crawl/import tools plus `tools/build_source_index.py`, which resolves Basketball-Reference source keys to canonical Sports Terminal entities. Continue using that existing mapping layer rather than creating a second identity system.

The `basketball_reference_web_scraper` project is useful for explicit acquisition of:

- player/team daily box scores
- season schedules
- player basic and advanced season totals
- play-by-play
- regular-season and playoff player game logs
- standings
- shooting statistics
- team rosters
- current contracts

Data should be saved into local raw storage and then ingested/canonicalized; it should not become a runtime dependency.

### 6. Curated awards supplement

Role: historical honors backfill.

`tools/nba_awards_static_supplement.py` merges curated rows into `history/awards.json` and player dossiers. The supplement should complement canonical data and preserve award tier/team distinctions rather than collapsing everything into generic "All-NBA" labels.

## Source precedence by grain

The generated `data_foundation.json` declares precedence explicitly:

- identity: canonical warehouse -> Basketball-Reference mapping/backfill
- traditional player-season: canonical -> NBA.com -> Basketball-Reference
- advanced player-season: NBA.com -> canonical -> Basketball-Reference
- team-season: canonical -> NBA.com -> SportsDataverse
- games/box scores: canonical -> SportsDataverse -> NBA.com -> Basketball-Reference
- play-by-play: canonical -> SportsDataverse -> pbpstats -> Basketball-Reference
- possessions/lineups: SportsDataverse -> pbpstats -> NBA.com
- awards: canonical -> curated supplement

"Precedence" does not mean silently overwriting a metric from a different definition. Source lineage remains metric-specific. For example, offensive 3P% and defended 3P% are different fields and must never substitute for one another.

## Product architecture

Every provider must resolve into the same Player, Team, Franchise, Season, Game, Possession and Event objects. Source-specific IDs belong in crosswalks and provenance, not in separate parallel product universes.

That rule is what allows the same player link to work across Stats, Advanced Stats, awards, game logs, contracts, research, trade scenarios and future workflow surfaces.

## Live seasons

Historical data is immutable once certified. A current in-progress season can use an explicit live overlay, but live rows should be snapshotted/materialized and promoted into the historical static corpus when the season closes. This keeps the browser path predictable while still allowing timely current-season data.

## What not to do

- Do not put direct NBA.com calls back into Flutter historical screens.
- Do not make SportsDataverse, pbpstats or Basketball-Reference libraries runtime dependencies of the website.
- Do not fabricate values when a source family is unavailable.
- Do not merge similarly named metrics with different definitions.
- Do not create a second Player/Team identity graph per provider.
- Do not force every dataset into SQLite if a sharded static format is a better serving layer.

The target is an authoritative local data substrate that can feed a simple traditional website today and deeper research/workflow/network products later.
