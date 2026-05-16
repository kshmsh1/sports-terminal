class GLeagueRoadmapItem {
  const GLeagueRoadmapItem({
    required this.area,
    required this.priority,
    required this.status,
    required this.description,
    required this.nbaConnection,
  });

  final String area;
  final String priority;
  final String status;
  final String description;
  final String nbaConnection;
}

const gLeagueRoadmapItems = <GLeagueRoadmapItem>[
  GLeagueRoadmapItem(
    area: 'Affiliate mapping',
    priority: 'P1',
    status: 'Future',
    description: 'Map NBA franchises to current and historical G League affiliates, including name changes and relocations.',
    nbaConnection: 'Connects player development context directly to NBA team infrastructure.',
  ),
  GLeagueRoadmapItem(
    area: 'G League team directory',
    priority: 'P1',
    status: 'Future',
    description: 'Create a reference directory for G League teams, cities, parent clubs, conference/division structure, and operating history.',
    nbaConnection: 'Extends the current NBA team directory without disrupting the NBA-first architecture.',
  ),
  GLeagueRoadmapItem(
    area: 'Assignments and recalls',
    priority: 'P2',
    status: 'Future',
    description: 'Track NBA players assigned to and recalled from G League teams, including dates and transaction context.',
    nbaConnection: 'Adds developmental and roster-management depth to player profiles.',
  ),
  GLeagueRoadmapItem(
    area: 'Two-way players',
    priority: 'P2',
    status: 'Future',
    description: 'Track two-way contract players, team affiliations, roster status, and NBA/G League movement.',
    nbaConnection: 'Important bridge between NBA contracts, roster construction, and player development.',
  ),
  GLeagueRoadmapItem(
    area: 'Call-ups and signings',
    priority: 'P2',
    status: 'Future',
    description: 'Track players moving from G League rosters into NBA contracts, ten-days, hardship deals, and standard contracts.',
    nbaConnection: 'Useful for prospect discovery, roster evaluation, and development outcomes.',
  ),
  GLeagueRoadmapItem(
    area: 'G League statistics',
    priority: 'P3',
    status: 'Source needed',
    description: 'Add traditional and advanced G League player/team stats when a lawful and reliable historical source is selected.',
    nbaConnection: 'Allows NBA player profiles to include pre-call-up and assignment production.',
  ),
  GLeagueRoadmapItem(
    area: 'Prospect development outcomes',
    priority: 'P3',
    status: 'Future',
    description: 'Connect G League performance, assignments, draft context, NBA outcomes, and long-term career arcs.',
    nbaConnection: 'Turns the terminal into a player-development intelligence platform rather than a stats viewer.',
  ),
];
