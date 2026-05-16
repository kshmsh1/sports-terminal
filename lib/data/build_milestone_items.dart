class BuildMilestoneItem {
  const BuildMilestoneItem({
    required this.milestone,
    required this.phase,
    required this.status,
    required this.description,
    required this.successCriteria,
  });

  final String milestone;
  final String phase;
  final String status;
  final String description;
  final String successCriteria;
}

const buildMilestoneItems = <BuildMilestoneItem>[
  BuildMilestoneItem(
    milestone: 'NBA reference foundation',
    phase: 'Phase 0',
    status: 'In progress',
    description: 'Build stable league, team, season, franchise, era, and data-governance foundations before loading complex statistics.',
    successCriteria: 'Current NBA teams, season catalog, data model, source policy, quality controls, and planning screens are navigable and coherent.',
  ),
  BuildMilestoneItem(
    milestone: 'Player identity layer',
    phase: 'Phase 1',
    status: 'Next',
    description: 'Add a real player identity layer before player stat tables so every stat line can attach to a durable player profile.',
    successCriteria: 'PlayerProfile records can display names, bio fields, draft fields, team context, source metadata, and blanks for unavailable values.',
  ),
  BuildMilestoneItem(
    milestone: 'Historical player statistics',
    phase: 'Phase 2',
    status: 'Planned',
    description: 'Add sourced historical player stat snapshots, starting with traditional season-level production before advanced or game-level data.',
    successCriteria: 'A player stats table loads normalized local data, includes source/as-of metadata, and never confuses missing values with zeros.',
  ),
  BuildMilestoneItem(
    milestone: 'Team and season intelligence',
    phase: 'Phase 3',
    status: 'Planned',
    description: 'Turn teams and seasons from directories into analytical hubs with records, leaders, awards, playoff context, roster context, and era overlays.',
    successCriteria: 'A team or season page can summarize historical context and link to players, games, awards, rosters, and source-backed statistics.',
  ),
  BuildMilestoneItem(
    milestone: 'Game, roster, and transaction graph',
    phase: 'Phase 4',
    status: 'Planned',
    description: 'Connect players, teams, seasons, rosters, games, transactions, and awards into a richer historical graph.',
    successCriteria: 'A user can move from a player to team history, roster history, transaction history, game records, and awards without breaking entity links.',
  ),
  BuildMilestoneItem(
    milestone: 'G League and development layer',
    phase: 'Phase 5',
    status: 'Future',
    description: 'Add G League affiliates, assignments, two-way players, call-ups, and development outcomes after NBA core data is stable.',
    successCriteria: 'G League context enriches NBA player and franchise profiles without distracting from the NBA-first product.',
  ),
];
