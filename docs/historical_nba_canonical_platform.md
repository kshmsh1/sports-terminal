# Historical NBA Canonical Platform

Sports Terminal separates historical NBA data into two layers:

1. a lossless source warehouse (`data/warehouse/nba_history.sqlite`) containing namespaced Wyatt Walsh/nbadb, Sumitro Datta and Gonzalo Gigena source tables; and
2. a reproducible `canon_*` analytical model built over those raw tables.

The raw layer is evidence. The canonical layer is the query contract used by backend and product surfaces. Rebuilding the canonical model never mutates or deletes the namespaced source tables.

## Build

After historical source ingestion completes:

```bash
bash scripts/build_historical_nba_canonical.sh
```

The command runs `tools/build_historical_nba_canonical.py`, writes `data/warehouse/nba_canonical_build_report.json`, prints warehouse/canonical coverage, and reports `/v2/nba/history/status` when the launch backend is already running.

The canonicalizer is intentionally standard-library only. The generated canonical tables remain inside the ignored local historical SQLite warehouse rather than being committed as application assets.

## Canonical objects

Dimensions and identity:

- `canon_dim_league`
- `canon_dim_season`
- `canon_dim_franchise`
- `canon_dim_team`
- `canon_team_source_xref`
- `canon_dim_player`
- `canon_player_source_xref`
- `canon_dim_game`
- `canon_game_source_xref`

Facts:

- `canon_fact_player_season`
- `canon_fact_team_season`
- `canon_fact_team_game`
- `canon_fact_player_game`
- `canon_fact_award`
- `canon_fact_all_star`
- `canon_fact_draft`
- `canon_fact_play_by_play` (zero-copy view over the Wyatt play-by-play source table)

Governance and observability:

- `canon_source_priority`
- `canon_field_provenance`
- `canon_conflicts`
- `canon_coverage`
- `canon_build_manifest`

## Identity resolution

Player identity resolution preserves source identifiers and builds a canonical crosswalk using, in descending confidence:

1. stable NBA person IDs;
2. Basketball-Reference IDs when exposed by the source;
3. normalized full name plus birth year/date; and
4. a unique normalized-name fallback when no ambiguity exists.

Every source identity remains in `canon_player_source_xref` with match method, confidence and evidence. Ambiguous records are not silently forced into a high-confidence identity.

Team identity uses stable NBA team IDs where available, historical league/abbreviation identity, names, and an explicit franchise lineage alias policy. Team seasons can retain historical team identity while `franchise_key` connects relocations/rebrands into franchise lineages.

## Seasons and leagues

Canonical seasons use `YYYY-YY`. NBA Stats five-digit `SEASON_ID` values are decoded rather than interpreted as years: leading `1` is preseason, `2` regular season, `3`/`5` All-Star, and `4` playoffs. Basketball-Reference-style four-digit season values are interpreted as season end years for the relevant source families.

League identity is explicit: `NBA`, `BAA`, and `ABA` are preserved rather than collapsed into one historical namespace.

## Source precedence and conflicts

Source precedence is domain-specific and versioned in `assets/data/nba/metadata/historical_canonical_policy.json`.

Current defaults:

- identity: Wyatt/nbadb → Sumitro → Gonzalo
- game and play-by-play: Wyatt/nbadb → Gonzalo → Sumitro
- player game: Gonzalo → Wyatt/nbadb → Sumitro
- player/team season: Sumitro → Gonzalo → Wyatt/nbadb
- awards, draft and All-Star: Sumitro → Wyatt/nbadb → Gonzalo

Canonicalization does not discard material disagreements. The selected value follows domain precedence while alternate values are retained in `canon_conflicts`. Selected field lineage is retained in `canon_field_provenance` and fact-level provenance maps.

## Historical API

The launch backend exposes canonical history under `/v2/nba/history`.

Major surfaces include status, metrics, coverage, seasons/leagues, player search/detail/career, historical leaderboards, era-adjusted player series, teams/franchise history, games, game play-by-play, conflicts and field provenance.

Historical leaderboards support totals, per-game, per-36, per-48, per-75-possession and per-100-possession bases. When direct possessions are absent, possession-rate bases use the transparent estimate `FGA + 0.44*FTA - ORB + TOV`, consistent with the workstation's existing methodology disclosure.

Era-adjusted series calculate a player's season value against qualified league-season peers and return peer mean, standard deviation, z-score, percentile and rank. They are descriptive normalization tools, not claims that cross-era basketball environments are fully equivalent.

## Product integration

Stats Center now has two explicit modes:

- **Historical · 1946–Present** — server-backed canonical multi-source history
- **Certified Current Release** — the existing validated release-asset workstation

The historical workstation exposes league, season, segment, rate basis and metric controls; historical rankings; search; up-to-six-player comparison; career history; era-adjusted trend; field provenance/conflicts; and source/coverage indicators. Keeping current-release mode separate prevents historical modeling from weakening the certified-current data contract.

## Validation

`backend/scripts/historical_canonical_contract_test.py` creates overlapping synthetic Wyatt/Sumitro/Gonzalo source tables, builds the canonical model, verifies cross-source identity, source precedence, conflict retention, season-ID decoding, games/team-games, player-game materialization, play-by-play identity linkage, and calls the historical API against the resulting database.

The Flutter quality workflow runs both the raw historical ingestion contract and the canonical platform contract before the normal backend contracts, Flutter analyzer, full test suite and release web build.
