class TerminalModuleItem {
  const TerminalModuleItem({
    required this.module,
    required this.domain,
    required this.priority,
    required this.status,
    required this.description,
  });

  final String module;
  final String domain;
  final String priority;
  final String status;
  final String description;
}

const terminalModuleItems = <TerminalModuleItem>[
  TerminalModuleItem(
    module: 'Command Dashboard',
    domain: 'Navigation',
    priority: 'P0',
    status: 'Started',
    description: 'Top-level workspace showing scope, connected datasets, source posture, and build priorities.',
  ),
  TerminalModuleItem(
    module: 'Team Directory',
    domain: 'Reference',
    priority: 'P0',
    status: 'Started',
    description: 'NBA franchise directory with conference and division structure. Future: franchise histories, arenas, ownership, front office, G League affiliates.',
  ),
  TerminalModuleItem(
    module: 'Season Directory',
    domain: 'Reference',
    priority: 'P0',
    status: 'Started',
    description: 'Historical season catalog for NBA/BAA. Future: season types, playoffs, lockouts, rule eras, expansion eras, schedule formats.',
  ),
  TerminalModuleItem(
    module: 'Player Directory',
    domain: 'Reference',
    priority: 'P0',
    status: 'Schema ready',
    description: 'Player identity, bio, draft, career, team affiliation, active status, and source metadata.',
  ),
  TerminalModuleItem(
    module: 'Historical Stats',
    domain: 'Statistics',
    priority: 'P1',
    status: 'Planned',
    description: 'Traditional, advanced, team, player, season, playoff, and game-level statistics from official or approved sources.',
  ),
  TerminalModuleItem(
    module: 'Roster History',
    domain: 'Transactions',
    priority: 'P1',
    status: 'Planned',
    description: 'Team-season rosters, active windows, assignments, call-ups, two-way players, and player movement context.',
  ),
  TerminalModuleItem(
    module: 'Awards and Honors',
    domain: 'Context',
    priority: 'P2',
    status: 'Planned',
    description: 'MVP, All-NBA, All-Star, All-Defense, Rookie of the Year, DPOY, Sixth Man, Finals MVP, voting shares, and historical recognition.',
  ),
  TerminalModuleItem(
    module: 'Draft and Prospect Layer',
    domain: 'Context',
    priority: 'P2',
    status: 'Planned',
    description: 'Draft history, combine measurements, pre-NBA pathways, international context, G League Ignite history, and prospect development.',
  ),
  TerminalModuleItem(
    module: 'Game Center',
    domain: 'Game Data',
    priority: 'P2',
    status: 'Planned',
    description: 'Schedules, box scores, game logs, playoff series, matchup data, and historical game details.',
  ),
  TerminalModuleItem(
    module: 'Contracts and Cap',
    domain: 'Financial',
    priority: 'P3',
    status: 'Source needed',
    description: 'Salaries, cap hits, guarantees, options, extensions, apron/tax context, and team payroll views from a lawful source.',
  ),
  TerminalModuleItem(
    module: 'News, Reports, and Notes',
    domain: 'Research',
    priority: 'P4',
    status: 'Future',
    description: 'Internal research notes, source links, injury writeups, scouting reports, transaction narratives, and media/document organization.',
  ),
  TerminalModuleItem(
    module: 'Comparison Engine',
    domain: 'Analysis',
    priority: 'P4',
    status: 'Shell started',
    description: 'Player, team, season, era, franchise, and cohort comparisons after data layers are connected.',
  ),
];
