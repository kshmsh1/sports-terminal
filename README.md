# Sports Terminal

Sports Terminal is an NBA-first Flutter web app for building a serious sports research and workflow terminal. The current build is local-first and uses normalized JSON assets, source-aware empty states, Build Lab governance screens, and reusable workflow contracts before any heavier backend work.

## Current product shape

The app is organized around Core Terminal, Workspace, and Network layers.

Core Terminal covers dashboard, search, players, teams, seasons, stats, standings, playoffs, games, rosters, awards, draft, transactions, contracts, compare, reports, saved views, alerts, and action routing.

Workspace covers table templates, column packages, metric packages, formula recipes, join recipes, report blocks, export previews, saved views, and source-backed workflow payloads.

Network covers fantasy, community, creator analysis, shared spaces, and future collaboration surfaces. These are designed now but gated behind the core NBA data model and future account architecture.

## Data policy

No fake sports records should be added to make the UI look full. Connected data can be shown. Source-pending data should stay blank, empty, or clearly labeled. The terminal should preserve source state, missing-data behavior, field provenance, and route blockers.

The strongest connected surfaces today are Teams and Seasons. Many other modules are connected-empty or source-pending by design while player identity, stat imports, game records, standings, playoffs, awards, rosters, draft, transactions, and contract paths are hardened.

## Recent build expansion

Recent build turns expanded shared registry screens into operational command boards with metrics, filtered execution queues, category concentration, and status distribution. Platform Endgame now captures terminal objects, command routing, workspace-first workflows, source-backed reporting, saved views, alerts, chart objects, and field-level provenance. Terminal Operating Layer now includes object, route payload, selection, formula, join, chart, report, persistence, import orchestration, validation, privacy, and packaging layers. Action Center now includes object rails, source drawers, release readiness reports, join recipes, column packages, comparison-to-report routes, and source snapshots.

## MVP exit condition

The NBA MVP is ready when a user can search real NBA entities, inspect linked detail pages, route selected objects into actions, manipulate data in workspaces, compare entities, generate basic reports, save views, preview alerts, export source-aware outputs, and understand source status without fake data.

## Running locally

```bash
flutter pub get
flutter run -d chrome
```

## Build priorities

1. Harden selected-row and terminal-object contracts on connected Team and Season tables.
2. Create first non-empty Workspace Studio payloads from Team Directory and Season Catalog.
3. Build first report, export, saved-view, compare, and action payloads from connected rows and operational registries.
4. Start the player identity import path before high-volume stat, award, roster, draft, transaction, fantasy, or scouting workflows.
5. Preserve source trust, null policy, and validation behavior as first-class product surfaces.
