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
    models: 'Team, FranchiseHistoryEvent',
    description: 'Stores team identity, city, abbreviation, conference, division, and future franchise history events such as renames, relocations, and predecessor clubs.',
  ),
  DataModelDomain(
    domain: 'Seasons and eras',
    priority: 'P0',
    status: 'Connected for NBA/BAA',
    models: 'Season, EraDefinition',
    description: 'Stores NBA and BAA season identifiers plus era definitions for rule changes, expansion periods, play style periods, and historical context.',
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
  DataModelDomain(
    domain: 'Financial and salary data',
    priority: 'P3',
    status: 'Schema ready, source needed',
    models: 'SalaryRecord',
    description: 'Stores player salary and cap-related records when a lawful and reliable source is selected. This remains separate from official box-score statistics.',
  ),
  DataModelDomain(
    domain: 'Injuries and availability',
    priority: 'P3',
    status: 'Schema ready, source needed',
    models: 'InjuryRecord',
    description: 'Stores injury status, dates, body-part labels, return information, and source metadata. This is not treated as historical box-score data.',
  ),
  DataModelDomain(
    domain: 'Media and research assets',
    priority: 'P4',
    status: 'Schema ready',
    models: 'MediaAsset',
    description: 'Stores articles, reports, clips, notes, documents, source links, and research artifacts associated with players, teams, games, seasons, or transactions.',
  ),
];
