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
  SearchIndexItem(
    title: 'NBA Command Center',
    category: 'Workspace',
    target: 'Dashboard',
    status: 'Live',
    description: 'Top-level workspace for the NBA-first historical terminal build.',
  ),
  SearchIndexItem(
    title: 'Boston Celtics',
    category: 'Team',
    target: 'Teams',
    status: 'Reference data connected',
    description: 'Current NBA team record in the team directory.',
  ),
  SearchIndexItem(
    title: 'Los Angeles Lakers',
    category: 'Team',
    target: 'Teams',
    status: 'Reference data connected',
    description: 'Current NBA team record in the team directory.',
  ),
  SearchIndexItem(
    title: 'Chicago Bulls',
    category: 'Team',
    target: 'Teams',
    status: 'Reference data connected',
    description: 'Current NBA team record in the team directory.',
  ),
  SearchIndexItem(
    title: '2025-26',
    category: 'Season',
    target: 'Seasons',
    status: 'Reference data connected',
    description: 'Configured NBA season key in the historical season catalog.',
  ),
  SearchIndexItem(
    title: '1946-47',
    category: 'Season',
    target: 'Seasons',
    status: 'Reference data connected',
    description: 'Earliest configured BAA/NBA season in the historical season catalog.',
  ),
  SearchIndexItem(
    title: 'Player identity layer',
    category: 'Data model',
    target: 'Player Schema',
    status: 'Schema ready',
    description: 'Player profile and stat-line schema for future sourced player records.',
  ),
  SearchIndexItem(
    title: 'Historical player statistics',
    category: 'Data roadmap',
    target: 'Data Roadmap',
    status: 'Planned',
    description: 'Future official-source-preferred player statistics layer.',
  ),
  SearchIndexItem(
    title: 'G League assignments',
    category: 'Development layer',
    target: 'G League Roadmap',
    status: 'Future',
    description: 'Future NBA/G League movement, two-way player, and development-path tracking.',
  ),
  SearchIndexItem(
    title: 'Franchise relocations and renames',
    category: 'Franchise history',
    target: 'Franchise History',
    status: 'Planned',
    description: 'Future historical mapping for team identity changes and franchise continuity.',
  ),
  SearchIndexItem(
    title: 'Null versus zero policy',
    category: 'Quality control',
    target: 'Quality Controls',
    status: 'Started',
    description: 'Missing values display as blank; zero only means a true recorded zero.',
  ),
  SearchIndexItem(
    title: 'Source policy',
    category: 'Governance',
    target: 'Source Policy',
    status: 'Live',
    description: 'Internal guardrails for official, public, manual, licensed, and modeled data.',
  ),
  SearchIndexItem(
    title: 'Ingestion pipeline',
    category: 'Operations',
    target: 'Ingestion Pipeline',
    status: 'Planned',
    description: 'Source to raw file to normalized data to validation to app-ready JSON.',
  ),
];
