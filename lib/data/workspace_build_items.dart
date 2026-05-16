class WorkspaceBuildItem {
  const WorkspaceBuildItem({
    required this.area,
    required this.priority,
    required this.status,
    required this.description,
    required this.firstDataNeed,
  });

  final String area;
  final String priority;
  final String status;
  final String description;
  final String firstDataNeed;
}

const gameWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(
    area: 'Game records',
    priority: 'P1',
    status: 'Schema ready',
    description: 'Game identity, date, season, season type, teams, scores, location, and source metadata.',
    firstDataNeed: 'Historical schedule and result snapshots.',
  ),
  WorkspaceBuildItem(
    area: 'Team box scores',
    priority: 'P2',
    status: 'Planned',
    description: 'Team-level production for each game, including points, pace, efficiency, possessions, and shooting splits.',
    firstDataNeed: 'Official or licensed box-score source.',
  ),
  WorkspaceBuildItem(
    area: 'Player box scores',
    priority: 'P2',
    status: 'Planned',
    description: 'Player-level game production with minutes, usage, shooting, counting stats, and availability context.',
    firstDataNeed: 'Historical player game-log data.',
  ),
  WorkspaceBuildItem(
    area: 'Playoff series',
    priority: 'P3',
    status: 'Future',
    description: 'Series-level matchup context, seeds, round, home-court status, game-by-game results, and advancement.',
    firstDataNeed: 'Playoff bracket and series records.',
  ),
];

const rosterWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(
    area: 'Team-season rosters',
    priority: 'P1',
    status: 'Schema ready',
    description: 'Player-to-team-to-season relationships with position, jersey number, and roster status.',
    firstDataNeed: 'Historical roster snapshots by team and season.',
  ),
  WorkspaceBuildItem(
    area: 'Active windows',
    priority: 'P2',
    status: 'Planned',
    description: 'Dates when players were active, inactive, assigned, recalled, signed, waived, or traded.',
    firstDataNeed: 'Transaction and roster status history.',
  ),
  WorkspaceBuildItem(
    area: 'Two-way players',
    priority: 'P2',
    status: 'Future',
    description: 'Two-way contract status and NBA/G League movement.',
    firstDataNeed: 'Contract and assignment source.',
  ),
  WorkspaceBuildItem(
    area: 'Lineup context',
    priority: 'P4',
    status: 'Future',
    description: 'Player combinations, minutes overlap, lineup performance, and role changes.',
    firstDataNeed: 'Lineup or play-by-play data.',
  ),
];

const awardWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(
    area: 'Major awards',
    priority: 'P1',
    status: 'Schema ready',
    description: 'MVP, Finals MVP, Rookie of the Year, Defensive Player of the Year, Sixth Man, Most Improved, and Coach of the Year.',
    firstDataNeed: 'Historical award winner list.',
  ),
  WorkspaceBuildItem(
    area: 'All-NBA and All-Defense',
    priority: 'P1',
    status: 'Planned',
    description: 'Team selections, positions, vote totals, and season-level recognition.',
    firstDataNeed: 'Historical team selections and voting records.',
  ),
  WorkspaceBuildItem(
    area: 'All-Star context',
    priority: 'P2',
    status: 'Planned',
    description: 'All-Star selections, starters, reserves, replacements, captains, and game participation.',
    firstDataNeed: 'Historical All-Star data.',
  ),
  WorkspaceBuildItem(
    area: 'Voting shares',
    priority: 'P3',
    status: 'Future',
    description: 'Vote shares, ranks, points, first-place votes, and voting body context.',
    firstDataNeed: 'Detailed voting tables.',
  ),
];

const draftWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(
    area: 'Draft picks',
    priority: 'P1',
    status: 'Schema ready',
    description: 'Draft year, round, pick number, team, player, school or club, country, and source metadata.',
    firstDataNeed: 'Historical NBA draft records.',
  ),
  WorkspaceBuildItem(
    area: 'Draft classes',
    priority: 'P2',
    status: 'Planned',
    description: 'Class-level summaries, lottery context, pick distributions, outcomes, and team-level draft histories.',
    firstDataNeed: 'Draft pick records plus player identity links.',
  ),
  WorkspaceBuildItem(
    area: 'Prospect context',
    priority: 'P3',
    status: 'Future',
    description: 'College, international, G League, Ignite, combine, and pre-draft pathway context.',
    firstDataNeed: 'Prospect and combine sources.',
  ),
  WorkspaceBuildItem(
    area: 'Draft rights and trades',
    priority: 'P4',
    status: 'Future',
    description: 'Pick trades, draft rights, swaps, protections, and transaction context.',
    firstDataNeed: 'Transaction and cap/legal source.',
  ),
];

const transactionWorkspaceItems = <WorkspaceBuildItem>[
  WorkspaceBuildItem(
    area: 'Trades',
    priority: 'P1',
    status: 'Schema ready',
    description: 'Player movement between teams, dates, descriptions, and future asset context.',
    firstDataNeed: 'Historical transaction logs.',
  ),
  WorkspaceBuildItem(
    area: 'Signings and waivers',
    priority: 'P2',
    status: 'Planned',
    description: 'Free-agent signings, waivers, releases, hardship deals, ten-days, and roster conversions.',
    firstDataNeed: 'Transaction source with event type detail.',
  ),
  WorkspaceBuildItem(
    area: 'Assignments and recalls',
    priority: 'P2',
    status: 'Future',
    description: 'NBA/G League movement through assignments, recalls, and two-way player activity.',
    firstDataNeed: 'G League and NBA assignment source.',
  ),
  WorkspaceBuildItem(
    area: 'Contract events',
    priority: 'P3',
    status: 'Source needed',
    description: 'Extensions, options, guarantees, conversions, buyouts, and salary/cap effects.',
    firstDataNeed: 'Lawful contract and salary source.',
  ),
];
