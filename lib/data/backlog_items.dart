import '../models/backlog_item.dart';

final backlogItems = <BacklogItem>[
  for (final module in _terminalModules)
    for (final stage in _moduleStages)
      BacklogItem(
        id: '${module.id}-${stage.id}',
        title: '${module.name}: ${stage.title}',
        area: module.area,
        priority: stage.priority,
        status: stage.status,
        whyItMatters: '${module.purpose} ${stage.whyItMatters}',
        acceptanceCriteria: '${stage.acceptanceCriteria} The output must keep source metadata, blank values for unknowns, and links into ${module.primaryLinks}.',
      ),
];

class _BacklogModule {
  const _BacklogModule(this.id, this.name, this.area, this.purpose, this.primaryLinks);
  final String id;
  final String name;
  final String area;
  final String purpose;
  final String primaryLinks;
}

class _BacklogStage {
  const _BacklogStage(this.id, this.title, this.priority, this.status, this.whyItMatters, this.acceptanceCriteria);
  final String id;
  final String title;
  final String priority;
  final String status;
  final String whyItMatters;
  final String acceptanceCriteria;
}

const _terminalModules = <_BacklogModule>[
  _BacklogModule('navigation', 'Navigation', 'Navigation', 'Navigation keeps the terminal usable as the module count grows.', 'Core Terminal, Build Lab, workflows, and entity routes'),
  _BacklogModule('search', 'Search', 'Search', 'Search is the command layer across every NBA workspace.', 'players, teams, seasons, games, reports, saved views, sources, and operations'),
  _BacklogModule('players', 'Players', 'Core Product', 'Players become the highest-value entity layer once player identity is sourced.', 'stats, rosters, awards, draft, transactions, compare, and reports'),
  _BacklogModule('teams', 'Teams', 'Core Product', 'Teams are franchise command centers and core join targets.', 'seasons, standings, playoffs, rosters, games, transactions, and reports'),
  _BacklogModule('seasons', 'Seasons', 'Core Product', 'Seasons are the time spine for historical NBA analysis.', 'teams, standings, playoffs, awards, leaders, draft, games, and reports'),
  _BacklogModule('games', 'Games', 'Core Product', 'Games are the event layer between season summaries and granular performance.', 'teams, players, box scores, playoffs, game logs, charts, and reports'),
  _BacklogModule('rosters', 'Rosters', 'Core Product', 'Rosters connect player identity to team context over time.', 'players, teams, seasons, transactions, games, contracts, and G League movement'),
  _BacklogModule('awards', 'Awards', 'Recognition', 'Awards should preserve full race context rather than only winner records.', 'players, teams, seasons, stats, standings, compare, and reports'),
  _BacklogModule('draft', 'Draft', 'Talent Pipeline', 'Draft history connects prospect acquisition to NBA outcomes.', 'players, teams, seasons, scouting, G League, awards, and reports'),
  _BacklogModule('transactions', 'Transactions', 'Movement Graph', 'Transactions explain how teams and player careers change over time.', 'players, teams, rosters, contracts, draft picks, G League, and reports'),
  _BacklogModule('contracts', 'Contracts', 'Front Office', 'Contracts eventually make the terminal useful for roster construction and cap workflows.', 'players, teams, transactions, reports, and source governance'),
  _BacklogModule('stats', 'Stats', 'Performance', 'Stats are the analytical engine but must stay organized into clear families.', 'players, teams, games, seasons, playoffs, compare, reports, charts, and alerts'),
  _BacklogModule('standings', 'Standings', 'Postseason Context', 'Standings connect records, seeds, teams, seasons, and playoff qualification.', 'teams, seasons, playoffs, team stats, compare, and reports'),
  _BacklogModule('playoffs', 'Playoffs', 'Postseason Context', 'Playoffs explain postseason paths, series results, and franchise outcomes.', 'teams, seasons, standings, games, awards, compare, and reports'),
  _BacklogModule('compare', 'Compare', 'Workflow', 'Compare turns terminal data into decision-ready side-by-side analysis.', 'players, teams, seasons, stats, awards, draft, transactions, and reports'),
  _BacklogModule('reports', 'Reports', 'Workflow', 'Reports turn terminal data into reusable written and tabular outputs.', 'entities, stats, comparisons, sources, saved views, and exports'),
  _BacklogModule('saved-views', 'Saved Views', 'Workflow', 'Saved views preserve repeatable research workflows.', 'search, filters, tables, charts, reports, compare, and alerts'),
  _BacklogModule('alerts', 'Alerts', 'Workflow', 'Alerts become the monitoring layer for source changes and data events.', 'saved views, imports, players, teams, stats, rosters, and data health'),
  _BacklogModule('operations', 'Source Operations', 'Operations', 'Source operations protect trust, rights posture, lineage, and repeatability.', 'source registry, import jobs, data lineage, QA, data health, and app assets'),
  _BacklogModule('gleague', 'G League Development', 'Development', 'G League context preserves the future player-development layer while NBA remains first.', 'players, rosters, transactions, draft, scouting, games, and reports'),
];

const _moduleStages = <_BacklogStage>[
  _BacklogStage('schema', 'Stabilize source-aware schema', 'P0', 'Next', 'A stable schema prevents rework when real data arrives.', 'Define required IDs, optional fields, sourceId, asOf, and nullable values for the module.'),
  _BacklogStage('loader', 'Connect local asset loader', 'P0', 'Next', 'The UI must run on local normalized assets before live feeds exist.', 'Repository loader returns a typed list and the screen handles empty arrays without crashing.'),
  _BacklogStage('table', 'Add searchable table surface', 'P1', 'Planned', 'Users need to inspect rows directly before advanced workflows exist.', 'Screen supports text search, source status, key filters, row counts, and source-pending empty states.'),
  _BacklogStage('detail', 'Add selected record detail panel', 'P1', 'Planned', 'A terminal should let users inspect one entity or row deeply.', 'Selecting a row shows joined identity, source metadata, attached row counts, and next actions.'),
  _BacklogStage('joins', 'Attach cross-module relationships', 'P1', 'Planned', 'The platform becomes valuable when modules connect instead of sitting alone.', 'Screen shows joins into adjacent modules and flags broken or source-pending relationships.'),
  _BacklogStage('workflow', 'Add report and compare hooks', 'P2', 'Planned', 'Users should move from exploration into output and decision workflows.', 'Screen exposes report, compare, save view, and source audit hooks where the module supports them.'),
  _BacklogStage('timeline', 'Add chart or timeline readiness', 'P3', 'Future', 'Historical sports analysis needs trend and timeline views after rows exist.', 'Define chart or timeline keys, date fields, entity keys, metric keys, and range controls.'),
  _BacklogStage('qa', 'Add QA and data health checks', 'P2', 'Planned', 'Users need to trust loaded data before relying on analysis.', 'Validation checks IDs, joins, duplicate keys, source metadata, row counts, null handling, and display behavior.'),
];
