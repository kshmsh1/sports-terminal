class SearchIndexItem {
  const SearchIndexItem({
    required this.title,
    required this.category,
    required this.target,
    required this.status,
    required this.description,
  });

  final String title;
  final String category;
  final String target;
  final String status;
  final String description;
}

const terminalSearchItems = <SearchIndexItem>[
  SearchIndexItem(title: 'NBA Command Center', category: 'Workspace', target: 'Dashboard', status: 'Live', description: 'Top-level workspace for the NBA-first historical terminal build.'),
  SearchIndexItem(title: 'Core MVP Completion', category: 'MVP Gate', target: 'NBA MVP Completion', status: 'Target', description: 'Exit criteria for the first working local NBA prototype.'),
  SearchIndexItem(title: 'Core MVP Gaps', category: 'MVP Gate', target: 'Core MVP Gaps', status: 'Live', description: 'Open gaps between the current prototype and useful NBA MVP.'),
  SearchIndexItem(title: 'Player Identity Import', category: 'MVP Gate', target: 'Player Identity Import', status: 'Next', description: 'Execution plan for publishing real source-backed player profiles.'),
  SearchIndexItem(title: 'Season Command Plan', category: 'MVP Gate', target: 'Season Command Plan', status: 'In progress', description: 'Plan for turning each season into a central command object.'),
  SearchIndexItem(title: 'Players command center', category: 'Core module', target: 'Players', status: 'Source pending', description: 'Player identity, selected-player detail, stats attachments, awards, rosters, draft links, and transactions.'),
  SearchIndexItem(title: 'Stats command center', category: 'Core module', target: 'Stats', status: 'Source pending', description: 'Player-season and team-season statistics workspace with joins, filters, readiness, and dependency checks.'),
  SearchIndexItem(title: 'Teams command center', category: 'Core module', target: 'Teams', status: 'Reference data connected', description: 'Current NBA teams, conferences, divisions, selected team context, and future attachments.'),
  SearchIndexItem(title: 'Seasons command center', category: 'Core module', target: 'Seasons', status: 'Reference data connected', description: 'Historical NBA/BAA season catalog with selected-season data availability.'),
  SearchIndexItem(title: 'Boston Celtics', category: 'Team', target: 'Teams', status: 'Reference data connected', description: 'Current NBA team record in the team directory.'),
  SearchIndexItem(title: 'Los Angeles Lakers', category: 'Team', target: 'Teams', status: 'Reference data connected', description: 'Current NBA team record in the team directory.'),
  SearchIndexItem(title: 'Chicago Bulls', category: 'Team', target: 'Teams', status: 'Reference data connected', description: 'Current NBA team record in the team directory.'),
  SearchIndexItem(title: '2025-26', category: 'Season', target: 'Seasons', status: 'Reference data connected', description: 'Configured NBA season key in the historical season catalog.'),
  SearchIndexItem(title: '1946-47', category: 'Season', target: 'Seasons', status: 'Reference data connected', description: 'Earliest configured BAA/NBA season in the historical season catalog.'),
  SearchIndexItem(title: 'Games workspace', category: 'Core module', target: 'Games', status: 'Schema ready', description: 'Future game center for schedules, results, box scores, game logs, and playoff series.'),
  SearchIndexItem(title: 'Rosters workspace', category: 'Core module', target: 'Rosters', status: 'Schema ready', description: 'Future roster graph for team-season rosters, active windows, assignments, recalls, and two-way players.'),
  SearchIndexItem(title: 'Awards workspace', category: 'Core module', target: 'Awards', status: 'Schema ready', description: 'Future awards library for MVP, All-NBA, All-Star, voting shares, and historical honors.'),
  SearchIndexItem(title: 'Draft workspace', category: 'Core module', target: 'Draft', status: 'Schema ready', description: 'Future draft intelligence workspace for picks, classes, prospects, outcomes, and development paths.'),
  SearchIndexItem(title: 'Transactions workspace', category: 'Core module', target: 'Transactions', status: 'Schema ready', description: 'Future movement graph for trades, signings, waivers, assignments, recalls, and contract events.'),
  SearchIndexItem(title: 'Compare workspace', category: 'Core module', target: 'Compare', status: 'Template ready', description: 'Comparison templates for players, teams, seasons, drafts, transactions, and development paths.'),
  SearchIndexItem(title: 'Reports library', category: 'Core module', target: 'Reports', status: 'Template ready', description: 'Reusable report templates for player, team, draft, awards, franchise, transaction, and development workflows.'),
  SearchIndexItem(title: 'Saved views', category: 'Core module', target: 'Saved Views', status: 'Design', description: 'Future reusable workspace presets for filtered terminal views.'),
  SearchIndexItem(title: 'Alerts', category: 'Core module', target: 'Alerts', status: 'Design', description: 'Future alert-rule library for data changes, player updates, source risk, and data health failures.'),
  SearchIndexItem(title: 'Data Health', category: 'Operations', target: 'Data Health', status: 'Started', description: 'Operational registry for asset checks, source metadata checks, broken joins, null/zero handling, and rights clearance.'),
  SearchIndexItem(title: 'Player identity layer', category: 'Data model', target: 'Player Schema', status: 'Schema ready', description: 'Player profile and stat-line schema for future sourced player records.'),
  SearchIndexItem(title: 'Historical player statistics', category: 'Data roadmap', target: 'Data Roadmap', status: 'Planned', description: 'Future official-source-preferred player statistics layer.'),
  SearchIndexItem(title: 'Stat Dictionary', category: 'Data model', target: 'Stat Dictionary', status: 'Live', description: 'Core metric definitions and formulas for traditional and future stats.'),
  SearchIndexItem(title: 'Metric Packages', category: 'Data model', target: 'Metric Packages', status: 'Live', description: 'Build order for traditional stats, efficiency, availability, awards, and development metrics.'),
  SearchIndexItem(title: 'Table Templates', category: 'UI system', target: 'Table Templates', status: 'Live', description: 'Reusable table types for directories, registries, stats, timelines, comparisons, and source decisions.'),
  SearchIndexItem(title: 'Column Library', category: 'UI system', target: 'Column Library', status: 'Live', description: 'Standard identity, source, availability, production, team context, workflow, and report columns.'),
  SearchIndexItem(title: 'Null versus zero policy', category: 'Quality control', target: 'Quality Controls', status: 'Started', description: 'Missing values display as blank; zero only means a true recorded zero.'),
  SearchIndexItem(title: 'Source policy', category: 'Governance', target: 'Source Policy', status: 'Live', description: 'Internal guardrails for official, public, manual, licensed, and modeled data.'),
  SearchIndexItem(title: 'Research Sources', category: 'Governance', target: 'Research Sources', status: 'Live', description: 'Registry for official NBA stats, team sites, public references, media guides, CBA documents, and licensed data.'),
  SearchIndexItem(title: 'Data Lineage', category: 'Governance', target: 'Data Lineage', status: 'Live', description: 'Path from raw source reference to snapshot, normalization, validation, local asset, and screen usage.'),
  SearchIndexItem(title: 'Ingestion pipeline', category: 'Operations', target: 'Ingestion Pipeline', status: 'Planned', description: 'Source to raw file to normalized data to validation to app-ready JSON.'),
  SearchIndexItem(title: 'G League assignments', category: 'Development layer', target: 'G League Roadmap', status: 'Future', description: 'Future NBA/G League movement, two-way player, and development-path tracking.'),
  SearchIndexItem(title: 'Franchise relocations and renames', category: 'Franchise history', target: 'Franchise History', status: 'Planned', description: 'Future historical mapping for team identity changes and franchise continuity.'),
];
