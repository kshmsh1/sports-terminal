# Core Terminal Module Expansion Plan

This plan keeps the build broad across the NBA terminal instead of over-indexing on statistics. The target remains a full NBA-first sports terminal with data, entity workspaces, workflow tools, reports, and operational guardrails.

## Core product surfaces

The core product should continue developing across Search, Players, Teams, Seasons, Games, Rosters, Awards, Draft, Transactions, Contracts, Stats, Standings, Playoffs, Compare, Reports, Saved Views, Alerts, Media and Research, and Scouting.

## Near-term build direction

Games should become the event bridge between team seasons and granular player or team performance. Rosters should become the player-team graph. Awards should become full award-race boards, not only winner tables. Draft should connect talent acquisition to long-term outcomes. Transactions should become the movement graph for how teams are built. Teams should become franchise command centers. Seasons should become era command centers. Stats should stay split into fundamental, efficiency, advanced, defensive, tracking, and third-party families.

## End-platform checkpoint

The local NBA MVP is successful when a user can search a player, team, season, game, award race, draft class, or transaction; inspect linked detail; understand source status; compare entities; build a report; save a view; and trust that blank values mean source-pending rather than zero.

## Data posture

The app should continue loading normalized local JSON assets through the repository layer. Any NBA.com/stats or official-source collection should happen through a separate approved ingestion process that creates raw snapshots, normalized rows, validation output, and lineage records before the Flutter app consumes the data.
