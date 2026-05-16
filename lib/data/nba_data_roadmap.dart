class DataRoadmapItem {
  const DataRoadmapItem({
    required this.name,
    required this.category,
    required this.priority,
    required this.status,
    required this.description,
  });

  final String name;
  final String category;
  final String priority;
  final String status;
  final String description;
}

const nbaDataRoadmap = <DataRoadmapItem>[
  DataRoadmapItem(
    name: 'Team directory',
    category: 'Reference',
    priority: 'P0',
    status: 'Connected',
    description: 'All 30 current NBA franchises with abbreviation, city, conference, and division.',
  ),
  DataRoadmapItem(
    name: 'Season catalog',
    category: 'Reference',
    priority: 'P0',
    status: 'Connected',
    description: 'NBA/BAA season records from 1946-47 through the currently configured season.',
  ),
  DataRoadmapItem(
    name: 'Player identity index',
    category: 'Reference',
    priority: 'P0',
    status: 'Planned',
    description: 'Player IDs, names, positions, bios, draft metadata, active status, and historical team affiliations.',
  ),
  DataRoadmapItem(
    name: 'Traditional player stats',
    category: 'Statistics',
    priority: 'P1',
    status: 'Planned',
    description: 'Season-by-season player totals and per-game production by season type.',
  ),
  DataRoadmapItem(
    name: 'Advanced player stats',
    category: 'Statistics',
    priority: 'P1',
    status: 'Planned',
    description: 'Efficiency, usage, possession-normalized metrics, and advanced box score derived indicators.',
  ),
  DataRoadmapItem(
    name: 'Team season stats',
    category: 'Statistics',
    priority: 'P1',
    status: 'Planned',
    description: 'Team records, ratings, pace, and season-level team performance indicators.',
  ),
  DataRoadmapItem(
    name: 'Game logs and box scores',
    category: 'Game Data',
    priority: 'P2',
    status: 'Planned',
    description: 'Game-level player and team production for deeper historical querying.',
  ),
  DataRoadmapItem(
    name: 'Awards and honors',
    category: 'Context',
    priority: 'P2',
    status: 'Planned',
    description: 'MVP, All-NBA, All-Star, Defensive Player of the Year, Rookie of the Year, and similar honors.',
  ),
  DataRoadmapItem(
    name: 'Draft history',
    category: 'Context',
    priority: 'P2',
    status: 'Planned',
    description: 'Draft class, pick number, original franchise, college or country, and draft-night context.',
  ),
  DataRoadmapItem(
    name: 'Transactions',
    category: 'Context',
    priority: 'P3',
    status: 'Planned',
    description: 'Trades, signings, waivers, retirements, and roster movement history.',
  ),
  DataRoadmapItem(
    name: 'Contracts and salary',
    category: 'Financial',
    priority: 'P3',
    status: 'Source needed',
    description: 'Contract values, cap figures, guarantees, extensions, options, and salary cap context.',
  ),
];
