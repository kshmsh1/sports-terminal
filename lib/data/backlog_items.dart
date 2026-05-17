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
  _BacklogModule('dashboard', 'Dashboard', 'Command', 'Dashboard must become the executive launch page for the whole terminal rather than a static landing screen.', 'search, saved views, alerts, reports, source health, and pinned workspaces'),
  _BacklogModule('navigation', 'Navigation', 'Navigation', 'Navigation keeps the terminal usable as the module count grows.', 'Core Terminal, Build Lab, workflows, and entity routes'),
  _BacklogModule('search', 'Search', 'Search', 'Search is the command layer across every NBA workspace.', 'players, teams, seasons, games, reports, saved views, sources, and operations'),
  _BacklogModule('action-center', 'Action Center', 'Command', 'Action Center turns the terminal from a lookup app into a workflow engine.', 'workspace, compare, report, export, save view, alert, source audit, fantasy, and community'),
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
  _BacklogModule('nba-stats-import', 'NBA Stats Import', 'Data Acquisition', 'NBA.com/stats is the near-term public data target and needs a disciplined import path before stats can become real.', 'source registry, import jobs, raw snapshots, normalized stats, QA, and lineage'),
  _BacklogModule('standings', 'Standings', 'Postseason Context', 'Standings connect records, seeds, teams, seasons, and playoff qualification.', 'teams, seasons, playoffs, team stats, compare, and reports'),
  _BacklogModule('playoffs', 'Playoffs', 'Postseason Context', 'Playoffs explain postseason paths, series results, and franchise outcomes.', 'teams, seasons, standings, games, awards, compare, and reports'),
  _BacklogModule('context-assets', 'Context Assets', 'Context Layer', 'Context Assets keep games, rosters, awards, draft, and transactions aligned as reusable evidence objects.', 'games, rosters, awards, draft, transactions, reports, search, and source audit'),
  _BacklogModule('entity-pages', 'Entity Detail Pages', 'Core Product', 'Entity detail pages are the durable destination for player, team, season, game, award, draft, and transaction objects.', 'search, stats, context assets, reports, compare, saved views, and source audit'),
  _BacklogModule('workspace-studio', 'Workspace Studio', 'Workflow', 'Workspace Studio is the Excel-like surface that prevents the terminal from becoming a read-only database.', 'datasets, columns, formulas, joins, charts, saved views, reports, and exports'),
  _BacklogModule('compare', 'Compare', 'Workflow', 'Compare turns terminal data into decision-ready side-by-side analysis.', 'players, teams, seasons, stats, awards, draft, transactions, and reports'),
  _BacklogModule('reports', 'Reports', 'Workflow', 'Reports turn terminal data into reusable written and tabular outputs.', 'entities, stats, comparisons, sources, saved views, and exports'),
  _BacklogModule('saved-views', 'Saved Views', 'Workflow', 'Saved views preserve repeatable research workflows.', 'search, filters, tables, charts, reports, compare, and alerts'),
  _BacklogModule('alerts', 'Alerts', 'Workflow', 'Alerts become the monitoring layer for source changes and data events.', 'saved views, imports, players, teams, stats, rosters, and data health'),
  _BacklogModule('export-center', 'Export Center', 'Workflow', 'Export Center makes terminal outputs portable while preserving source and rights notes.', 'tables, reports, saved views, workspaces, source audit, and governance'),
  _BacklogModule('charts', 'Charts and Trend Lab', 'Visualization', 'Charts turn historical stats, game logs, team trends, and award cases into finance-style analytical views.', 'stats, games, seasons, players, teams, compare, workspace, and reports'),
  _BacklogModule('fantasy', 'Fantasy Terminal', 'Network Product', 'Fantasy Terminal makes the product useful for consumer workflows without compromising the professional terminal core.', 'players, stats, games, rosters, alerts, saved views, and community'),
  _BacklogModule('community', 'Community Hub', 'Network Product', 'Community Hub gives the terminal a publishing and discussion layer tied to real data objects.', 'entities, charts, reports, rooms, moderation, saved views, and creator workflows'),
  _BacklogModule('scouting', 'Scouting', 'Evaluation', 'Scouting provides a qualitative evaluation layer on top of stats, draft, roster, and media context.', 'players, teams, draft, G League, media, reports, and compare'),
  _BacklogModule('media-research', 'Media and Research', 'Research', 'Media and research context prevent the terminal from being only numerical data.', 'players, teams, games, transactions, reports, source registry, and community'),
  _BacklogModule('operations', 'Source Operations', 'Operations', 'Source operations protect trust, rights posture, lineage, and repeatability.', 'source registry, import jobs, data lineage, QA, data health, and app assets'),
  _BacklogModule('source-registry', 'Source Registry', 'Source Governance', 'Source Registry is the trust layer for every dataset, screenshot, manual upload, licensed feed, and future scraper.', 'source policy, import jobs, data lineage, QA, exports, and reports'),
  _BacklogModule('data-lineage', 'Data Lineage', 'Source Governance', 'Data Lineage explains how raw source records become normalized terminal objects.', 'raw snapshots, normalized assets, source registry, import jobs, QA, and reports'),
  _BacklogModule('data-health', 'Data Health', 'Operations', 'Data Health keeps the app honest about coverage, freshness, validation failures, and source-pending gaps.', 'QA Console, source registry, import jobs, datasets, and dashboard'),
  _BacklogModule('qa-console', 'QA Console', 'Operations', 'QA Console is the stabilization layer that prevents aggressive buildout from breaking the prototype.', 'analyzer checks, smoke tests, data validation, source rules, and release readiness'),
  _BacklogModule('privacy-permissions', 'Privacy and Permissions', 'Governance', 'Privacy and permissions become necessary once workspaces, saved views, alerts, fantasy, and community objects exist.', 'accounts, saved views, reports, community, fantasy leagues, and private workspaces'),
  _BacklogModule('performance-budget', 'Performance Budget', 'Governance', 'Performance budgets protect the terminal from becoming slow as tables, charts, and registries grow.', 'navigation, tables, charts, imports, data caches, and browser runtime'),
  _BacklogModule('gleague', 'G League Development', 'Development', 'G League context preserves the future player-development layer while NBA remains first.', 'players, rosters, transactions, draft, scouting, games, and reports'),
];

const _moduleStages = <_BacklogStage>[
  _BacklogStage('schema', 'Stabilize source-aware schema', 'P0', 'Next', 'A stable schema prevents rework when real data arrives.', 'Define required IDs, optional fields, sourceId, asOf, and nullable values for the module.'),
  _BacklogStage('loader', 'Connect local asset loader', 'P0', 'Next', 'The UI must run on local normalized assets before live feeds exist.', 'Repository loader returns a typed list and the screen handles empty arrays without crashing.'),
  _BacklogStage('table', 'Add searchable table surface', 'P1', 'Planned', 'Users need to inspect rows directly before advanced workflows exist.', 'Screen supports text search, source status, key filters, row counts, and source-pending empty states.'),
  _BacklogStage('detail', 'Add selected record detail panel', 'P1', 'Planned', 'A terminal should let users inspect one entity or row deeply.', 'Selecting a row shows joined identity, source metadata, attached row counts, and next actions.'),
  _BacklogStage('joins', 'Attach cross-module relationships', 'P1', 'Planned', 'The platform becomes valuable when modules connect instead of sitting alone.', 'Screen shows joins into adjacent modules and flags broken or source-pending relationships.'),
  _BacklogStage('actions', 'Expose Action Center verbs', 'P1', 'Planned', 'Users should not have to remember where to send an object next.', 'The module exposes open, compare, workspace, report, save view, export, alert, and source audit routes where relevant.'),
  _BacklogStage('workspace', 'Route into Workspace Studio', 'P1', 'Planned', 'The terminal needs an Excel-like workflow surface to become more than a sports encyclopedia.', 'Selected records or filtered tables can define a workspace payload with columns, joins, filters, formulas, and source snapshot.'),
  _BacklogStage('reporting', 'Generate report-ready blocks', 'P2', 'Planned', 'Professional users need outputs, not just screens.', 'The module can send selected rows, summary facts, source notes, and charts later into a reusable report template.'),
  _BacklogStage('compare', 'Support compare-ready payloads', 'P2', 'Planned', 'Side-by-side analysis is one of the most important terminal workflows.', 'The module defines entity slots, metric packages, context fields, and blockers for Compare.'),
  _BacklogStage('export', 'Add governed export pathway', 'P2', 'Planned', 'Analysts need to move terminal outputs into external materials without losing trust context.', 'Export payload includes selected rows, columns, filters, source notes, missing-data flags, and rights posture.'),
  _BacklogStage('source-audit', 'Expose source audit state', 'P1', 'Planned', 'Users need to see where data came from and whether it can be trusted.', 'The screen shows sourceId, asOf, lineage status, validation status, and rights posture when available.'),
  _BacklogStage('charts', 'Add chart or timeline readiness', 'P3', 'Future', 'Historical sports analysis needs trend and timeline views after rows exist.', 'Define chart or timeline keys, date fields, entity keys, metric keys, and range controls.'),
  _BacklogStage('alerts', 'Define alert hooks', 'P3', 'Future', 'The terminal should monitor changes once saved views and data refresh exist.', 'Define what field, source, status, row count, ranking, threshold, or event should trigger an alert.'),
  _BacklogStage('persistence', 'Persist user state', 'P3', 'Future', 'The product becomes stickier when users can resume work exactly where they left off.', 'Define saved state for filters, selected rows, column sets, view modes, routes, pins, and notes.'),
  _BacklogStage('qa', 'Add QA and data health checks', 'P2', 'Planned', 'Users need to trust loaded data before relying on analysis.', 'Validation checks IDs, joins, duplicate keys, source metadata, row counts, null handling, and display behavior.'),
  _BacklogStage('smoke-test', 'Add screen-level smoke test path', 'P2', 'Planned', 'Aggressive buildout needs repeatable screen checks so Chrome launch stays reliable.', 'Define the minimum screen render check, expected empty state, and expected row count behavior.'),
];
