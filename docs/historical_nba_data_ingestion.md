# Historical NBA Data Ingestion

Sports Terminal now has a lossless-first historical ingestion path designed to expand the NBA warehouse from a single-season development seed into a multi-source historical research database.

## Source strategy

The source registry lives at `assets/data/nba/metadata/historical_source_registry.json` and records acquisition URLs, provenance, license notes, source priority and intended role.

| Source | Historical role | Coverage / strength | License handling |
| --- | --- | --- | --- |
| Wyatt Walsh NBA Database / `nbadb` | Primary game/event/official-endpoint warehouse | 1946-47 to present where upstream endpoints exist; game, box-score, play-by-play, shot/tracking and other NBA Stats surfaces | Dataset is CC BY-SA 4.0; preserve attribution/share-alike obligations. `nbadb` client code is MIT. NBA.com data use remains subject to NBA.com terms. |
| Sumitro Datta NBA/ABA/BAA Stats | Primary long-run season/award/draft backbone | BAA 1947-49, NBA 1950-present, ABA 1968-76; player/team season tables, awards, voting, draft, shooting/PBP-era splits | CC0/public domain. Prefer this source for canonical historical season facts when equivalent fields exist. |
| Gonzalo Gigena NBA All Time Stats | Cross-check and playoff/game-history supplement | 1947-present regular season and playoffs; game results, box scores, all-time stats and rookies | Published as MIT by dataset author; retain provenance. |
| `swar/nba_api` | Targeted refresh/backfill/enrichment | Endpoint-dependent official NBA Stats access | MIT client code only; NBA.com data remains subject to NBA.com terms. |

The acquisition workflow intentionally uses the Wyatt Kaggle/`nbadb` output instead of immediately re-scraping every `nba_api` endpoint. `nbadb` already maintains a historical extraction/backfill pipeline around `nba_api`, while direct NBA.com extraction can be rate-limited, blocked or unavailable for some endpoint/season combinations.

## One-command acquisition and import

From the repository root:

```bash
bash scripts/import_historical_nba_sources.sh --replace
```

The script creates an isolated `.historical-venv`, installs `kagglehub`, downloads every Kaggle dataset registered in the source registry, copies the packages into ignored `raw/historical/<source-key>/` directories, and runs the lossless importer.

If Kaggle requires authentication on a machine, configure Kaggle credentials and rerun. Downloaded packages are local raw inputs and are never committed automatically.

## Warehouse output

The consolidated database is:

```text
data/warehouse/nba_history.sqlite
```

The import report is:

```text
data/warehouse/nba_history_import_report.json
```

Both are ignored by Git because the historical datasets can be very large.

### Lossless source tables

Every imported source table is copied into a namespaced warehouse table. Example shapes:

```text
src_wyatt_nbadb__nba__<source_table>
src_sumitro_bref_history__<csv_file>
src_gonzalo_all_time__<csv_file>
```

SQLite is preferred when a package also includes CSV exports. This prevents duplicate copies of the same 10M+ row source material while preserving the full database surface. Pass `--include-csv-with-sqlite` only when format-level comparison is explicitly needed.

### Provenance/control tables

The warehouse creates:

- `historical_import_runs` — run status, counts and warnings.
- `historical_source_registry` — source URL, origin, license, priority, coverage and imported totals.
- `historical_source_files` — every imported file with byte size and SHA-256.
- `historical_table_inventory` — source table, warehouse table, semantic domain, grain, row/column counts and detected season bounds.
- `historical_source_coverage` — aggregated source/domain/grain coverage view.

The importer classifies tables into research domains such as player season, team season, game, box score, play-by-play, shot chart, tracking, lineup/rotation, matchup, awards, draft, standings and all-star data. Classification is metadata only; source columns remain intact.

## Why this is separate from the existing launch seed

The current launch data pipeline is optimized around a validated single-season Basketball-Reference warehouse and a compact Flutter seed. Historical sources contain tens of millions of rows and many schemas that do not fit that asset model.

The historical warehouse therefore remains a server/query-layer dataset. The next canonicalization phase should create stable dimensions and facts across sources, then expose historical queries through the backend and Stats Workstation without embedding the entire database in the Flutter bundle.

Recommended canonical layers:

1. Player/team/franchise identity and alias crosswalks across Basketball-Reference IDs, NBA IDs and source-specific identifiers.
2. Seasons, leagues and competition types (`NBA`, `BAA`, `ABA`; regular season, playoffs, play-in, all-star where available).
3. Games, team game stats and player game stats.
4. Player/team season totals, rates and advanced metrics.
5. Play-by-play, shots, lineups/rotations, tracking and matchup facts where source availability supports them.
6. Draft, awards, voting and all-star history.
7. Source-priority reconciliation and field-level provenance for overlapping facts.

## Validation

CI runs `backend/scripts/historical_import_contract_test.py`. The contract builds a synthetic SQLite + CSV source package, imports it through the same production importer, and verifies source registration, row/table counts, domain/grain classification and season coverage.

Manual inventory query:

```bash
sqlite3 data/warehouse/nba_history.sqlite \
  "SELECT source_key, domain, grain, table_count, row_count, min_season, max_season FROM historical_source_coverage ORDER BY source_key, row_count DESC;"
```

## Data-rights boundary

Historical ingestion and public redistribution are separate decisions. Sports Terminal should keep provenance attached to every imported source and should not infer that an open-source client license grants rights to redistribute the underlying upstream data. The source registry is designed so later release/certification gates can explicitly allow, restrict or exclude source-derived fields before public distribution.
