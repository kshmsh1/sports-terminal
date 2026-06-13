# Basketball Reference Ingestion

Sports Terminal includes a first-party local ingestion path for selected public Basketball Reference tables. The importer uses a descriptive user agent, checks robots.txt by default, waits at least 3.5 seconds between page requests, caches successful HTML responses, and stops on HTTP 403 or 429.

Review the current site terms and access rules before every collection project.

## Install

```bash
bash tools/setup_sports_ingestion.sh
source .venv/bin/activate
```

The local environment installs `requests`, `beautifulsoup4`, `lxml`, and `pandas`.

## Season convention

Basketball Reference league pages use the season-ending year:

```text
2026 = 2025-26 NBA season
2025 = 2024-25 NBA season
```

## Inspect available tables

```bash
python tools/import_basketball_reference.py \
  --season 2026 \
  --list-tables league
```

The page choices are `league`, `per_game`, `totals`, and `advanced`.

## Fetch raw candidates

```bash
python tools/import_basketball_reference.py --season 2026 --dataset player_per_game
python tools/import_basketball_reference.py --season 2026 --dataset player_totals
python tools/import_basketball_reference.py --season 2026 --dataset player_advanced
python tools/import_basketball_reference.py --season 2026 --dataset team_per_game
python tools/import_basketball_reference.py --season 2026 --dataset standings
```

Outputs are written beneath:

```text
raw/basketball_reference/2025-26/
```

Each dataset produces CSV, JSON, and manifest files. The manifest records the source URL, table identifier, row count, columns, source timestamp, cache state, and SHA-256 hash. Canonical Flutter assets are not modified.

Successful HTML is cached under `.cache/sports_reference/`. Repeating a command uses the cache. Use `--force` only when a fresh snapshot is necessary.

## Optional legacy-package probe

The older PyPI package can be tested independently:

```bash
source .venv/bin/activate
python -m pip install sportsreference==0.5.2
python tools/probe_sportsreference.py --season 2026
```

The first-party importer does not depend on this probe succeeding.

## Before canonical import

Raw rows still need a reviewed transformation layer covering stable player IDs, team abbreviation mapping, regular-season versus playoff typing, traded-player duplicate handling, percentage conversion, null handling, and metric validation.

Start with one completed season and one table at a time. Review the manifest and row shape before collecting another dataset. Do not run concurrent collectors or repeatedly retry blocked responses.
