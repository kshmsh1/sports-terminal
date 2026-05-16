class InformationArchitectureItem {
  const InformationArchitectureItem({
    required this.area,
    required this.scope,
    required this.priority,
    required this.status,
    required this.examples,
    required this.notes,
  });

  final String area;
  final String scope;
  final String priority;
  final String status;
  final String examples;
  final String notes;
}

const informationArchitectureItems = <InformationArchitectureItem>[
  InformationArchitectureItem(
    area: 'League directory',
    scope: 'NBA first, G League later',
    priority: 'P0',
    status: 'In progress',
    examples: 'NBA, G League, Summer League, Draft Combine',
    notes: 'Defines the basketball ecosystem that Sports Terminal will organize before expanding into other sports.',
  ),
  InformationArchitectureItem(
    area: 'Team directory',
    scope: 'Franchise and affiliate identity',
    priority: 'P0',
    status: 'Connected for NBA',
    examples: 'Teams, abbreviations, cities, conferences, divisions, future affiliate links',
    notes: 'G League affiliate mapping should be added after NBA team identity and historical franchise structure are more mature.',
  ),
  InformationArchitectureItem(
    area: 'Season directory',
    scope: 'Historical seasons and competition periods',
    priority: 'P0',
    status: 'Connected for NBA/BAA',
    examples: '1946-47 through configured current season, regular season, playoffs, play-in, preseason',
    notes: 'Current catalog tracks NBA/BAA seasons. Later it should distinguish season type and competition stage.',
  ),
  InformationArchitectureItem(
    area: 'Player identity',
    scope: 'All NBA player identities and future G League-linked profiles',
    priority: 'P0',
    status: 'Schema ready',
    examples: 'Names, IDs, position, bio, height, weight, draft profile, career status',
    notes: 'This is the next major data layer. It should be sourced before player statistics become useful.',
  ),
  InformationArchitectureItem(
    area: 'Roster history',
    scope: 'Team-season and transaction-aware roster context',
    priority: 'P1',
    status: 'Planned',
    examples: 'Roster by season, active dates, two-way contracts, assignments, call-ups',
    notes: 'Roster history is essential for connecting NBA and G League movement.',
  ),
  InformationArchitectureItem(
    area: 'Traditional statistics',
    scope: 'Player and team box score production',
    priority: 'P1',
    status: 'Planned',
    examples: 'Games, minutes, points, rebounds, assists, steals, blocks, turnovers, shooting splits',
    notes: 'Official historical NBA stats are preferred. Null fields remain blank until a source is connected.',
  ),
  InformationArchitectureItem(
    area: 'Advanced statistics',
    scope: 'Efficiency and possession-normalized indicators',
    priority: 'P1',
    status: 'Planned',
    examples: 'Usage, true shooting, effective field goal percentage, net rating, pace, plus-minus variants',
    notes: 'Definitions must be tracked by source because advanced stat formulas vary across providers.',
  ),
  InformationArchitectureItem(
    area: 'Games and box scores',
    scope: 'Game-level data model',
    priority: 'P2',
    status: 'Planned',
    examples: 'Schedules, results, box scores, player game logs, team game logs, playoffs',
    notes: 'This unlocks historical querying beyond season summaries.',
  ),
  InformationArchitectureItem(
    area: 'Awards and honors',
    scope: 'Historical recognition and voting context',
    priority: 'P2',
    status: 'Planned',
    examples: 'MVP, All-NBA, All-Defense, All-Star, Rookie of the Year, DPOY, Sixth Man',
    notes: 'Awards are high-value contextual data and easier to display before live data is solved.',
  ),
  InformationArchitectureItem(
    area: 'Draft and prospects',
    scope: 'Draft history and pre-NBA evaluation context',
    priority: 'P2',
    status: 'Planned',
    examples: 'Draft year, pick, team, college, country, combine, scouting context',
    notes: 'Draft and G League data should eventually connect through player development paths.',
  ),
  InformationArchitectureItem(
    area: 'Transactions',
    scope: 'Movement, rights, roster decisions, and development pathways',
    priority: 'P3',
    status: 'Planned',
    examples: 'Trades, signings, waivers, assignments, recalls, two-way conversions, hardship signings',
    notes: 'This becomes important for NBA/G League integration.',
  ),
  InformationArchitectureItem(
    area: 'Contracts and salary',
    scope: 'Financial and cap-context layer',
    priority: 'P3',
    status: 'Source needed',
    examples: 'Salary, cap hit, guarantees, options, extensions, tax apron context',
    notes: 'Likely requires separate lawful source strategy. Do not assume official NBA stats covers it.',
  ),
  InformationArchitectureItem(
    area: 'Media and documents',
    scope: 'Reports, notes, video, news, and internal research',
    priority: 'P4',
    status: 'Future',
    examples: 'Scouting notes, injury reports, game notes, transaction writeups, clips, articles',
    notes: 'This is where the terminal can become more than a stats table.',
  ),
];
