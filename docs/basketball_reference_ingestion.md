# Basketball Reference Ingestion

Sports Terminal includes a first-party local ingestion path for public Basketball Reference tables. The importer uses a descriptive user agent, checks robots.txt by default, waits at least 3.5 seconds between page requests, caches successful HTML responses, and stops on HTTP 403 or 429.

Review the current site terms and access rules before every collection project.

## Core table contract

Basketball Reference is table-oriented, but the links inside the cells are as important as the displayed numbers. Sports Terminal therefore stores both.

Every extracted cell contains:

```json
{
  "text": "Jayson Tatum",
  "value": "Jayson Tatum",
  "links": [
    {
      "text": "Jayson Tatum",
      "href": "https://www.basketball-reference.com/players/t/tatumja01.html",
      "entityType": "player",
      "sourceKey": "basketball-reference:player:tatumja01"
    }
  ]
}
```

Supported source-link classifications include player, team, team-season, season, game, coach, award, and playoff references. These provider keys are preserved before any attempt is made to join them to internal Sports Terminal IDs.

The extractor also preserves `data-stat` column keys, repeated table sections, row classes, captions, nulls, numeric values, and every anchor in a cell. Tables hidden inside HTML comments are expanded before extraction.

## Install

```bash
bash tools/setup_sports_ingestion.sh
source .venv/bin/activate
```

The local environment installs `requests`, `beautifulsoup4`, `lxml`, and `pandas`, then runs the offline parser and link-classification tests.

## Season convention

Basketball Reference league pages use the season-ending year:

```text
2026 = 2025-26 NBA season
2025 = 2024-25 NBA season
```

## Standard season datasets

Inspect available tables first:

```bash
python tools/import_basketball_reference.py --season 2026 --list-tables league
python tools/import_basketball_reference.py --season 2026 --list-tables per_game
python tools/import_basketball_reference.py --season 2026 --list-tables advanced
python tools/import_basketball_reference.py --season 2026 --list-tables schedule
python tools/import_basketball_reference.py --season 2026 --list-tables playoff_per_game
```

The standard importer supports:

```text
player_per_game
player_totals
player_advanced
playoff_player_per_game
playoff_player_totals
playoff_player_advanced
team_per_game
team_opponent_per_game
team_advanced
standings
schedule
```

Example collection:

```bash
python tools/import_basketball_reference.py --season 2026 --dataset player_per_game
python tools/import_basketball_reference.py --season 2026 --dataset player_advanced
python tools/import_basketball_reference.py --season 2026 --dataset team_per_game
python tools/import_basketball_reference.py --season 2026 --dataset team_opponent_per_game
python tools/import_basketball_reference.py --season 2026 --dataset team_advanced
python tools/import_basketball_reference.py --season 2026 --dataset standings
python tools/import_basketball_reference.py --season 2026 --dataset schedule
```

Outputs are written beneath:

```text
raw/basketball_reference/2025-26/
```

Each standard dataset produces:

```text
<dataset>.csv
<dataset>.json
<dataset>.linked.json
<dataset>.manifest.json
```

The flat CSV is convenient for inspection. The linked JSON is the authoritative raw representation because it preserves source entity links and `data-stat` keys.

## Generic page extraction

Practically any table-oriented page can be inspected without adding a new scraper class.

Discover all tables on a page:

```bash
python tools/import_basketball_reference_page.py \
  --url https://www.basketball-reference.com/teams/BOS/2026.html \
  --discover
```

Extract one table after confirming its identifier:

```bash
python tools/import_basketball_reference_page.py \
  --url https://www.basketball-reference.com/teams/BOS/2026.html \
  --table-id per_game
```

Extract several tables from one cached page:

```bash
python tools/import_basketball_reference_page.py \
  --url https://www.basketball-reference.com/teams/BOS/2026.html \
  --table-id per_game \
  --table-id totals \
  --table-id advanced
```

Extract every table on the page:

```bash
python tools/import_basketball_reference_page.py \
  --url https://www.basketball-reference.com/teams/BOS/2026.html \
  --all-tables
```

The generic importer writes one `.linked.json` and one `.flat.csv` per table, plus a page manifest.

## Pages represented by the current screenshots

League team per-game table:

```bash
python tools/import_basketball_reference.py --season 2026 --dataset team_per_game
```

A team season page with a linked roster and team player statistics:

```bash
python tools/import_basketball_reference_page.py \
  --url https://www.basketball-reference.com/teams/BOS/2026.html \
  --discover
```

A player page containing regular-season, playoff, and playoff-series tables:

```bash
python tools/import_basketball_reference_page.py \
  --url https://www.basketball-reference.com/players/t/tatumja01.html \
  --discover
```

A franchise-history page containing many team seasons:

```bash
python tools/import_basketball_reference_page.py \
  --url https://www.basketball-reference.com/teams/BOS/ \
  --discover
```

Table IDs should always be discovered from the current page rather than assumed from screenshots.

## Build an internal source-entity index

Once one or more linked tables have been extracted, provider links can be matched to current Sports Terminal entities:

```bash
python tools/build_source_index.py \
  --input raw/basketball_reference/2025-26/player_per_game.linked.json \
  --input raw/basketball_reference/2025-26/team_per_game.linked.json
```

This writes resolved mappings and a separate held queue. Players are joined only on an exact normalized name match. Teams use the provider abbreviation embedded in the source link. Seasons use the provider season-ending year. Coaches, games, awards, and other entity types remain held until those internal identity models are connected.

## Prepare player-stat candidates

After collecting per-game and advanced player tables:

```bash
python tools/prepare_player_stats.py \
  --input raw/basketball_reference/2025-26/player_per_game.linked.json \
  --advanced-input raw/basketball_reference/2025-26/player_advanced.linked.json \
  --season-id 2025-26
```

The normalizer:

- resolves provider player links to current internal player IDs;
- prefers a provider `TOT` row for traded players;
- otherwise selects the single row or the row with the most games;
- resolves provider team links to internal team IDs;
- maps per-game and advanced metrics into the canonical player-season contract;
- writes a player source-index candidate;
- holds every ambiguous or unmatched player instead of guessing.

It writes candidates only. To apply, every held row must be resolved and the minimum-row threshold must be met:

```bash
python tools/prepare_player_stats.py \
  --input raw/basketball_reference/2025-26/player_per_game.linked.json \
  --advanced-input raw/basketball_reference/2025-26/player_advanced.linked.json \
  --season-id 2025-26 \
  --apply

dart run tools/validate_player_season_stats.dart
```

## Prepare team-stat candidates

After collecting the team and opponent per-game tables:

```bash
python tools/normalize_team_table.py \
  --input raw/basketball_reference/2025-26/team_per_game.linked.json \
  --opponent-input raw/basketball_reference/2025-26/team_opponent_per_game.linked.json \
  --season-id 2025-26
```

The team normalizer resolves teams through provider links first, falls back to exact normalized team names, maps team metrics, and requires the expected 30-team coverage before `--apply` is allowed.

```bash
python tools/normalize_team_table.py \
  --input raw/basketball_reference/2025-26/team_per_game.linked.json \
  --opponent-input raw/basketball_reference/2025-26/team_opponent_per_game.linked.json \
  --season-id 2025-26 \
  --apply

dart run tools/validate_team_season_stats.dart
```

## Cache and collection behavior

Successful HTML is cached under:

```text
.cache/sports_reference/
```

Repeating a command uses the cache and does not request the page again. Use `--force` only when a new source snapshot is genuinely required.

Run one page at a time while the pipeline is new. Do not run concurrent collectors, rotate identities, or repeatedly retry an access-denied response.

## Optional legacy-package probe

The older PyPI package can be tested independently:

```bash
source .venv/bin/activate
python -m pip install sportsreference==0.5.2
python tools/probe_sportsreference.py --season 2026
```

The first-party importer does not depend on this probe succeeding.

## Canonical import rule

Raw source collection, provider identity resolution, candidate normalization, held-row review, and canonical application are separate steps. A successful page fetch alone is never sufficient to modify the Flutter assets.
