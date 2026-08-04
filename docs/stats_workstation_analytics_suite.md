# Stats Workstation and Analytics Suite

This phase promotes the NBA Stats page into a dense professional research workstation and expands the Advanced destination into a connected analytics suite.

## Stats Workstation

The workstation supports regular-season, playoff and combined data segments when those rows exist in the active release. Rate bases include per game, per 36 minutes, per 48 minutes, per 75 estimated or sourced possessions, per 100 estimated or sourced possessions, and totals.

Built-in views cover profile, counting, shooting, efficiency, impact, defense and advanced fields. Users can create persistent custom views, reorder columns, favorite players, build comparison groups, filter numerically, inspect metric definitions, export TSV, and launch scatter or game-trend charts.

Desktop hotkeys include `F` for filters, `G` for the glossary, `C` to add the selected player to comparison, `Z` to open comparison, `W` and `E` to change density, and `Esc` to clear the active selection state. Compact layouts preserve the desktop workstation through horizontal scrolling instead of replacing the research table with a lower-information card view.

Possession-based values use direct source possessions when present. When they are absent, the workstation uses the visible estimate `FGA + 0.44 × FTA − OREB + TOV`; if the box-score components are also unavailable, it uses a clearly marked minutes-based fallback. Estimated values are never represented as sourced tracking data.

## Analytics Suite

Data-backed tools include:

- Player Dashboard
- Player Compare
- Team Compare
- Rankings
- Last X Games
- Shot Profile
- Lineup Builder
- Tier List
- Offensive Rating Sandbox
- Data Coverage

WOWY lineups, matchup tracking, RAPM decomposition, shot-quality decomposition and draft research remain source-gated. Their modules explain the required normalized source tables and methodology rather than publishing synthetic outputs.

## Shared engine

`NbaStatsWorkstationEngine` owns source alias resolution, basis conversion, filtering, sorting, position extraction, derived efficiency metrics and direction-aware percentiles. Stats and Analytics consume the same engine so values do not drift between pages.
