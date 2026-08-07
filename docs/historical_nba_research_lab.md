# Historical NBA Research Lab

The Historical NBA Research Lab is the product layer above the canonical historical warehouse. It is intentionally separate from both the season-oriented Historical Stats Workstation and the Certified Current Release workstation.

## Research desks

### Career

Search the canonical player identity graph across NBA, ABA, and BAA history. The desk combines:

- complete canonical player identity and source crosswalk context
- regular-season, playoff, or combined career season rows
- era-relative z-score and percentile series for the active metric/basis
- draft history, awards, and All-Star selections
- canonical player-game logs where game-level coverage exists
- a six-player cross-era comparison basket

### All-Time

All-time rankings operate on player-unique canonical season rows. Traded-player seasons use the same rules as Historical Stats: an explicit multi-team total is preferred; otherwise Sports Terminal synthesizes one after canonicalization and before qualification filters.

Modes:

- **Career** — aggregates the entire qualifying career window.
- **Peak Season** — ranks the best qualifying season for each player.
- **Best N Seasons** — aggregates the best N qualifying seasons for each player.

Supported bases are totals, per game, per 36, per 48, per 75 estimated possessions, and per 100 estimated possessions.

### Games + PBP

The game desk exposes canonical games and joins the selected game to:

- team-game facts
- player-game facts
- the canonical zero-copy Wyatt play-by-play view

Play-by-play identity joins are protected against crosswalk fan-out by the canonical platform contract.

### Franchises

Franchise research is anchored on `canon_dim_franchise`, not the current team name alone. The desk exposes historical team identities and canonical team-season rows so relocations and renames can remain part of one franchise lineage.

### Coverage

Coverage is a first-class research object rather than hidden ETL metadata. The desk exposes:

- raw-source registry and licenses
- canonical coverage by domain/league/season range
- field-provenance row count
- material source-conflict count
- canonical player/game/player-game counts
- highest-conflict entity fields

## API

Deep-research endpoints are under `/v2/nba/history`:

- `GET /research/summary`
- `GET /players/{player_key}/games`
- `GET /all-time`
- `GET /compare`
- `GET /franchises`
- `GET /franchises/{franchise_key}`

The lab also consumes canonical-platform endpoints for seasons, player identity/career, era-adjusted series, games, game detail, and play-by-play.

## Product placement

Stats Center has three peer modes:

1. Historical Stats
2. Historical Research Lab
3. Certified Current Release

This keeps deep historical research prominent while preserving the stricter certified-current release path.

## Local prerequisite

The raw 22.77M-row warehouse is local/generated and is not committed. After pulling a release that contains this feature, build canonical tables locally before using the lab:

```bash
bash scripts/build_historical_nba_canonical.sh
```

Then start the launch backend normally. `GET /v2/nba/history/status` should report `canonical_ready: true`.
