# NBA.com Stats historical capture — Part 1

Part 1 is a capture-driven historical acquisition layer for the NBA.com Stats request contracts supplied through browser DevTools. It deliberately separates one-time data acquisition from the Sports Terminal runtime.

## Scope

The plan in `assets/data/nba/metadata/nba_com_capture_plan_part1.json` expands the supplied request contracts into **84 distinct variants** across **80 NBA seasons (1946-47 through 2025-26)** and **Regular Season + Playoffs**, for **13,440 auditable scopes** before endpoint availability is considered.

Covered families:

- player traditional box scores (`leaguegamelog`)
- player shot locations (Base and Opponent; 5-foot, 8-foot and zone views)
- player clutch (Base, Advanced, Misc, Scoring, Usage)
- Synergy play types (11 play types × offensive/defensive)
- player tracking (12 measure types)
- player defense dashboard (6 distance/category views)
- player shot dashboard (General, Shot Clock, Dribbles, Touch Time, Closest Defender, Closest Defender 10+)
- player game logs (Base, Advanced, Misc, Scoring, Usage)
- player hustle

The collector does **not** impose guessed historical start seasons. It probes the configured 1946-47→2025-26 range and records empty/unavailable scopes instead of fabricating data.

## Full acquisition

```bash
bash scripts/fetch_nba_com_historical_stats.sh
```

This is intentionally resumable. Valid existing captures are skipped. To reacquire them:

```bash
bash scripts/fetch_nba_com_historical_stats.sh --force
```

Useful smaller probes:

```bash
bash scripts/fetch_nba_com_historical_stats.sh --plan-summary
bash scripts/fetch_nba_com_historical_stats.sh --surface players_tracking --season 2025-26 --probe-only
bash scripts/fetch_nba_com_historical_stats.sh --surface players_synergy --start 2015-16 --end 2025-26
```

The acquisition layer rate-limits requests, retries transient failures, records unsupported historical scopes as unavailable, stops after repeated transport rejection, validates result-set names and user-supplied row ceilings, and writes an incremental `raw/nba_com_stats/coverage.json` so interrupted runs can resume safely.

## Local capture layout

Each scope is stored under:

```text
raw/nba_com_stats/<surface>/<variant>/<season>/<regular|playoffs>/
  source.json
  normalized.json
  metadata.json
```

`source.json` is the untouched response. `normalized.json` converts each result-set row to a named-field object, including correct flattening of NBA.com's grouped shot-location headers. `metadata.json` records request URL, source hash, schema hash, row count, row ceiling and validation state.

The large capture directory is intentionally excluded from Git. It is source data, not application source code.

## Static Sports Terminal materialization

The normal Sports Terminal launcher remains network-free. During the local static build it:

1. builds the canonical historical corpus;
2. materializes installed Part 1 captures to `web/data/nba_static/nba_com/`;
3. joins player-season capture rows into the regular/playoff season shards;
4. rebuilds dashboards from the enriched static shards.

The static NBA.com layer retains every captured surface/variant and also produces lossless per-player game-log files. Game-log fields from Traditional/Base/Advanced/Misc/Scoring/Usage stay nested by source so same-named fields cannot overwrite one another.

Stats and Advanced Stats continue to read `seasons/<season>/<regular|playoffs>.json`. The Part 1 enrichment pass also materializes source-backed Advanced Stats keys such as clutch production, tracked passing/touches, contested rebounding, movement, Synergy PPP, defense dashboard percentages and selected shot-profile metrics when those captures exist for the chosen season.

No runtime NBA.com API call is required or permitted by this pipeline.

## Validation

The offline contract test exercises the plan expansion, 1946-47 request rendering, `Season` vs `SeasonYear`, grouped-header flattening, row ceilings, raw capture writing, static surface materialization, per-player game-log partitioning and season-level Advanced Stats enrichment:

```bash
python backend/scripts/nba_com_historical_collection_contract_test.py
```

CI tests the collector and materializer with fixtures only. CI never downloads NBA.com statistics.


## Network execution note

A GitHub-hosted Actions probe was attempted on 2026-09-26 using the same Chrome-like transport. NBA.com returned no bytes and the request timed out after 10 seconds from GitHub's hosted runner egress. The repository therefore does not pretend that Actions has collected data it could not reach, and it does not add a proxy or other bypass.

Run the acquisition command from a machine/network on which the supplied NBA.com DevTools cURL requests are reachable:

```bash
bash scripts/fetch_nba_com_historical_stats.sh
bash scripts/open_terminal.sh --rebuild-static
```

The first command resumes until all configured scopes have been attempted. The second command materializes the installed captures into Sports Terminal's same-origin static corpus and enriches the Stats / Advanced Stats season shards. Unsupported historical endpoint/season combinations remain explicitly empty or unavailable rather than being synthesized.
