class DataModelDomain {
  const DataModelDomain({
    required this.domain,
    required this.priority,
    required this.status,
    required this.models,
    required this.description,
  });

  final String domain;
  final String priority;
  final String status;
  final String models;
  final String description;
}

const dataModelDomains = <DataModelDomain>[
  DataModelDomain(
    domain: 'League and ecosystem',
    priority: 'P0',
    status: 'Started',
    models: 'LeagueProfile',
    description: 'Defines NBA, G League, Summer League, Draft Combine, and future basketball layers.',
  ),
  DataModelDomain(
    domain: 'Teams',
    priority: 'P0',
    status: 'Connected for NBA',
    models: 'Team',
    description: 'Stores team identity, city, abbreviation, conference, and division. Future: franchise history, arenas, ownership, front office, and affiliate links.',
  ),
  DataModelDomain(
    domain: 'Seasons',
    priority: 'P0',
    status: 'Connected for NBA/BAA',
    models: 'Season',
    description: 'Stores NBA and BAA season identifiers. Future: competition stages, schedule format, rule eras, lockout markers, and playoff bracket metadata.',
  ),
  DataModelDomain(
    domain: 'Players',
    priority: 'P0',
    status: 'Schema ready',
    models: 'PlayerProfile, PlayerStatLine',
    description: 'Stores player identity, bio, draft context, career status, and nullable statistics.',
  ),
  DataModelDomain(
    domain: 'Rosters',
    priority: 'P1',
    status: 'Schema ready',
    models: 'RosterEntry',
    description: 'Connects players to teams and seasons. Future: active windows, two-way contracts, G League assignments, call-ups, and historical roster movement.',
  ),
  DataModelDomain(
    domain: 'Games',
    priority: 'P2',
    status: 'Schema ready',
    models: 'GameRecord',
    description: 'Stores game identity and scoreboard context. Future: box scores, game logs, lineups, matchup data, playoff series, and live updates.',
  ),
  DataModelDomain(
    domain: 'Awards',
    priority: 'P2',
    status: 'Schema ready',
    models: 'AwardRecord',
    description: 'Stores awards, voting, ranks, shares, and honors. Useful as high-value historical context before live feeds are solved.',
  ),
  DataModelDomain(
    domain: 'Draft',
    priority: 'P2',
    status: 'Schema ready',
    models: 'DraftPick',
    description: 'Stores draft year, round, pick, team, player, school/club, and country. Future: combine and scouting context.',
  ),
  DataModelDomain(
    domain: 'Transactions',
    priority: 'P3',
    status: 'Schema ready',
    models: 'TransactionRecord',
    description: 'Stores player movement, trades, signings, waivers, assignments, recalls, and future contract events.',
  ),
];
