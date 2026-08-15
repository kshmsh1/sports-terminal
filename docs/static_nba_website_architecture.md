# Static-first NBA website architecture

Sports Terminal treats completed historical basketball as immutable reference data, not as a runtime database query.

## Runtime boundary

The primary website follows this path:

`nba_history.sqlite -> static compiler -> web/data/nba_static/* -> Flutter website`

Home, Stats, Advanced Stats, player search, player pages, team pages, awards, All-Star history, draft history and historical game metadata do not require FastAPI or runtime SQLite access. Generated static files are same-origin website files and are cached in memory by `WebsiteNbaStaticRepository` after first access.

Dynamic services remain available for account/session state, saved work, organizations, community, mutable front-office edits and the future active-season/live overlay.

## Core corpus

`tools/build_static_nba_website_data_v2.py` materializes the canonical historical warehouse into:

- `manifest.json`
- `seasons.json`
- `players/index.json`
- `teams/index.json`
- `games/index.json`
- `seasons/<season>/regular.json`
- `seasons/<season>/playoffs.json`
- `players/<stable-hash>.json`
- `teams/<stable-hash>.json`
- `history/awards.json`
- `history/all_star.json`
- `history/draft.json`
- `history/coverage.json`

Season shards are generated from the same canonical compatibility projection already used by the tested historical data layer, with player game logs excluded from season-level payloads. Player dossiers carry regular-season and playoff history separately, bounded recent game history, awards, All-Star selections and draft context. Team dossiers carry franchise/season history, bounded recent games and notable player links.

The core compiler fingerprints the warehouse. A subsequent launch skips rebuilding when the warehouse has not changed.

## Historical games and play-by-play

`tools/build_static_nba_game_data.py` materializes historical game detail into one file per canonical game. Each game shard contains canonical game metadata plus sourced team-game and player-game rows.

Play-by-play is a separate optional materialization because the source-backed event corpus can contain millions of rows and is not necessary to render Home, Stats or Advanced Stats. `--materialize-pbp` exports only rows already exposed by the canonical `canon_fact_play_by_play` view, grouped by canonical `game_key` and ordered by period/event number.

This is intentionally source-bounded. Sports Terminal does not claim possession-level PBP for eras or games where the imported sources do not provide it.

## Local launch

Normal launch:

```bash
bash scripts/open_terminal.sh
```

Force the immutable core and historical game detail to rebuild:

```bash
bash scripts/open_terminal.sh --rebuild-static
```

Also perform the potentially long one-time historical PBP materialization:

```bash
bash scripts/open_terminal.sh --rebuild-static --materialize-pbp
```

Generated files live under `web/data/nba_static/` and are ignored by Git because they are build artifacts derived from the canonical warehouse.

## Current-season/live model

The intended production model is static base + live overlay.

During an active season, the last published season snapshot remains a static website artifact while a small live/current-season layer supplies newly completed games, standings changes, player totals and event updates. New snapshots can be published during the season. After the season is complete and reconciled, that season becomes part of the immutable static corpus and the next season becomes the live overlay.

This keeps historical browsing resilient even if dynamic services are degraded.

## Mutable front-office data

Historical player/team facts are static. Contract, cap and draft records can have a static/cached snapshot plus a mutable current overlay. `FrontOfficeRegistryService.load()` is cache-first for product surfaces such as player pages and Trade Machine, then refreshes the mutable registry in the background. Explicit front-office editing/reconciliation remains a dynamic service workflow.

Missing contract/cap data is not fabricated. The Trade Machine can request explicit user-entered salary assumptions when current verified salary data is unavailable.

## Guardrails

CI enforces that the historical website facade does not depend on the old historical HTTP seed route, localhost backend URL or `loadHistoricalSeason()` transport path. A dedicated static repository test confirms season, entity, game and PBP reads use only same-origin `data/nba_static/*` files.
