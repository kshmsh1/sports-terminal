# Arcside

> **Source availability:** This repository is publicly viewable, but the source is not open-source. Reuse, redistribution, derivative products, or commercial deployment are not permitted except as described in the repository license. Local/raw datasets and generated warehouses are intentionally excluded from version control.


Arcside is a multi-sport web product with an NBA-first data platform. After login, users land on a league-selection home. NBA is the first fully enabled league; NFL, NHL, MLB, MLS, F1, Premier League, WNBA, ATP, WTA, PGA and IPL remain explicit future league surfaces until source-backed datasets are added.

**Architecture status:** staged React-first development has been selected. [Phase 3 closeout and Phase 4 implementation roadmap](docs/architecture/phase4_react_product_roadmap_2026_11_24.md) records the known validation gaps and follow-up work. Flutter remains a working reference and fallback.

## NBA website

The original Flutter NBA experience includes the modules listed below. The new React-first development shell currently exposes source-backed pilot implementations of many of them, not yet feature-complete replacements:

- NBA Home with season switching, player search, league leaders and team cards;
- Stats with the original sortable player statistics table;
- Advanced Stats with the original category-driven advanced table and glossary;
- canonical Player pages with separate Regular Season and Playoff careers, awards, All-Star/draft context, recent games, team history and registered contract information when available;
- canonical Team pages with franchise/season history, player navigation and recent games;
- global player/team search in the website header;
- the 2026-27 Trade Machine;
- Front Office, Research and Community;
- standalone Python Lab and Excel Workspace, available from Arcside navigation and in dedicated full-screen tabs. NBA data connections remain intentionally deferred.

## Static-first historical data

Completed NBA history is immutable product data. It does not need a runtime basketball API call every time a user opens Home, Stats, Advanced Stats, a player page or a team page.

The primary historical path is:

```text
nba_history.sqlite
  -> static compiler
  -> web/data/nba_static/*
  -> React-first web shell (Flutter reference retained)
```

`WebsiteNbaStaticRepository` reads same-origin static JSON. The compatibility class `WebsiteNbaApiService` delegates to that static repository; it is not a historical HTTP API transport.

The static corpus includes season indexes and shards, player/team indexes, canonical player/team dossiers, awards, All-Star and draft context, historical games, dashboard leader data and a published read-only Front Office snapshot when local contract/cap/draft records exist. Missing source-backed metrics remain unavailable rather than being filled with invented values.

Optional already-normalized NBA.com captures can enrich static seasons with source-backed fields such as deflections. `tools/nba_com_static_enrichment.py` performs no network requests. When those local captures do not exist, NBA.com-only metrics stay unavailable.

The intended active-season model is **static historical base + live current-season overlay**. When 2026-27 begins, a live layer can populate the active season without changing completed historical seasons. At season end, that season can be frozen into the static corpus.

## Launch the integrated Python Lab and Excel Workspace

The new local launcher starts both Labs plus the private CPython and
collaboration services with one command. It does not require an NBA dataset
in standalone preview mode:

```bash
bash scripts/launch_arcside.sh --labs
```

For the React-first Arcside development website (requires your existing
`data/warehouse/nba_history.sqlite` and a Flutter SDK):

```bash
bash scripts/launch_arcside.sh --platform
```

The launcher prints separate connection keys for the Python IDE and the
live workbook sharing service. Inside Sheets use **Share workbook** to
create/join permission-scoped rooms, or **My workbooks** to save independent
local workbooks. Use **Open full workspace** in Flutter to open either Lab
outside the embedded frame.

See [Labs launch, collaboration and compatibility guide](docs/arcside_labs_collaboration_launch.md).

## Local launch

Use the repository launcher so the canonical NBA static corpus exists before the React-first frontend starts:

```bash
bash scripts/open_terminal.sh
```

The default `open_terminal.sh` frontend is now **React/Vite**, retaining the same verified local NBA v5 source data. The original Flutter website remains available, unchanged, as a one-command fallback:

```bash
bash scripts/open_terminal.sh --flutter
```

For fast day-to-day access when the original NBA v5 data and dependencies are already present:

```bash
bash scripts/launch_arcside.sh --platform --fast
```

This is a **React-first developer beta**, not a declaration that full trade-CBA, player profiles, Labs native security, physical accessibility, and GPU/long-tail latency are certified. No production deployment is switched by the local launch preference. See [React-first beta migration and rollback](docs/architecture/react_first_beta_migration_2026_11_23.md).

Force a static rebuild:

```bash
bash scripts/open_terminal.sh --rebuild-static
```

The launcher searches for the canonical historical warehouse at:

```text
data/warehouse/nba_history.sqlite
nba_history.sqlite
```

It also checks the same locations in the immediately previous repository directory so an existing local historical warehouse can be reused. You can point to a specific warehouse with:

```bash
SPORTS_TERMINAL_NBA_HISTORY_DB=/path/to/nba_history.sqlite \
  bash scripts/open_terminal.sh
```

The launcher deliberately does not scrape or download sports data. It compiles/fingerprint-checks the local warehouse, applies any already-authorized local static enrichment, publishes the read-only Front Office snapshot, validates the required files, runs `flutter pub get`, and opens Chrome.

If `web/data/nba_static/` has already been built, direct Flutter launch also works:

```bash
flutter pub get
flutter run -d chrome
```

Generated static files under `web/data/nba_static/` are ignored by Git because they are build artifacts derived from the canonical local warehouse.

## Dynamic application services

The historical basketball website does not require the FastAPI backend. Mutable workflows such as account/session state, collaboration, explicit Front Office edits and other application operations may still use it when needed:

```bash
bash scripts/dev_backend.sh
```

The read path remains static-first. Mutable Front Office state can be published into static read-only website files while explicit edits continue to use the backend workflow.

## Data policy

Arcside does not add fake production data to make screens appear complete.

- Source-backed data may be shown.
- Missing values remain null or visibly unavailable rather than invented zeroes.
- Regular Season and Playoff statistics remain separate where the source distinguishes them.
- Historical facts are compiled once and reused across every website surface.
- Current-season live data is layered over, not substituted for, completed historical data.
- Commercial data rights and attribution remain external launch requirements and are never represented as complete without approval.

## External launch requirements

Public launch still requires the external items code cannot create on its own, including approved commercial data rights where applicable, production hosting/storage, authentication, monitoring, payment infrastructure if used, secrets, backups and operating processes.