# Historical NBA Parity Integration

## Objective

Historical NBA data should behave like a first-class Sports Terminal data source, not a side database. The original 2024-25 terminal seed established a browser-facing contract consumed by the Stats Workstation, Analytics Suite, player dashboards, team comparison, rankings, recent-game analysis, shot profile, lineup builder, tiering, coverage, search, and other NBA surfaces. Historical parity means canonical history can satisfy that same contract while preserving its own deeper historical APIs.

## Data layers

Sports Terminal now separates NBA data into four layers:

1. **Lossless historical source warehouse** — the 22.77M-row SQLite warehouse containing namespaced Wyatt/nbadb, Sumitro and Gonzalo source tables.
2. **Canonical historical warehouse** — reproducible `canon_*` dimensions, facts, source crosswalks, field provenance, conflicts and coverage built by `scripts/build_historical_nba_canonical.sh`.
3. **Historical query/research API** — `/v2/nba/history/...` endpoints for seasons, players, careers, leaderboards, era adjustment, games, play-by-play, franchises, all-time research, coverage and provenance.
4. **Original-seed compatibility projection** — `/v2/nba/history/seed/{season}` projects a canonical historical season into the same `NbaTerminalSeedSnapshot` shape used by the original NBA product.

Raw source tables remain immutable evidence. Canonical tables can be rebuilt. The compatibility projection is generated on demand and does not duplicate the 22.77M-row warehouse into Flutter assets.

## Shared terminal contract

`NbaTerminalSeedRepository` can now load either:

- the certified/current asset release and validated development fallback; or
- a canonical historical season from the backend.

The historical projection includes the same major documents the original seed exposed:

- manifest and validation metadata;
- teams and players;
- games;
- team records and team game logs;
- player season totals;
- player leaders and game highs;
- player game logs;
- search index;
- data dictionary;
- standings;
- release/source metadata.

Historical payloads explicitly identify themselves as `historical-canonical`; they are never represented as a certified current release.

## Product integration

### Stats Center

Stats Center keeps three peer modes:

- Historical Stats — canonical season workstation;
- Historical Research Lab — careers, all-time records, games/PBP, franchises and data governance;
- Certified Current Release — current validated/fallback asset workstation.

Switching to the current-release mode explicitly restores current data scope so historical context cannot leak into a surface labeled as certified/current.

### Analytics Suite

Advanced NBA Tools now has a persistent data-scope bar. Analysts can run the original Analytics Suite against either current release data or a selected canonical NBA/ABA/BAA historical season and segment. The same Player Dashboard, Player Compare, Team Compare, Rankings, Last X Games, Shot Profile, Lineup Builder, Tier List and Data Coverage code is reused.

Historical Stats queries persist their active season/league/segment into the shared NBA data context. Existing seed-backed modules therefore inherit the historical context instead of requiring a separate selection everywhere.

### Deep historical research

The compatibility layer does not replace the richer canonical endpoints. Career histories, source conflicts, field provenance, cross-era normalization, all-time rankings, franchise lineage and play-by-play remain available through dedicated historical research APIs and the Historical Research Lab.

## Source and methodology boundaries

- Multi-team player seasons prefer explicit source aggregate rows; otherwise the canonical API synthesizes one transparent aggregate from canonical stints.
- Material disagreements remain in `canon_conflicts`; losing source values are retained as evidence.
- Field-level provenance remains in `canon_field_provenance` even when a compatibility payload exposes a simplified seed-style row.
- Per-75/per-100 rates use the documented possession estimate where direct possessions are unavailable.
- Historical coverage varies by era and domain. Missing fields remain missing; the projection does not fabricate tracking, matchup, shot-quality or lineup data.

## Local build order

```bash
bash scripts/import_historical_nba_sources.sh --replace   # only when raw sources need rebuilding
bash scripts/build_historical_nba_canonical.sh            # materialize/rebuild canonical history
bash scripts/dev_backend.sh
```

The large raw downloads and SQLite warehouse remain local/ignored. GitHub stores the ingestion, canonicalization, query and product code—not the multi-gigabyte datasets.

## Validation

CI now covers:

- lossless historical import;
- canonical build and cross-source identity resolution;
- traded-player leaderboard semantics;
- historical-to-original-seed compatibility projection;
- deep historical research routes;
- Flutter parsing of the compatibility snapshot through `NbaTerminalSeedSnapshot`;
- reuse of the existing `NbaStatsWorkstationEngine` against historical data;
- the existing backend contracts, Flutter analyzer, Flutter test suite and release web build.
