import '../models/coverage_item.dart';

const coverageItems = <CoverageItem>[
  CoverageItem(dataset: 'Teams', domain: 'Reference', assetPath: 'assets/data/nba/teams/teams.json', recordCount: 30, status: 'Connected', priority: 'P0', nextStep: 'Add historical franchise aliases and IDs.'),
  CoverageItem(dataset: 'Seasons', domain: 'Reference', assetPath: 'assets/data/nba/seasons/seasons.json', recordCount: 80, status: 'Connected', priority: 'P0', nextStep: 'Extend annually and map season phases.'),
  CoverageItem(dataset: 'Player profiles', domain: 'Players', assetPath: 'assets/data/nba/players/player_profiles.json', recordCount: 0, status: 'Source pending', priority: 'P1', nextStep: 'Choose official-source-preferred player identity export.'),
  CoverageItem(dataset: 'Player season stats', domain: 'Statistics', assetPath: 'assets/data/nba/stats/player_traditional_by_season.json', recordCount: 0, status: 'Source pending', priority: 'P1', nextStep: 'Normalize traditional player season rows.'),
  CoverageItem(dataset: 'Team season stats', domain: 'Statistics', assetPath: 'assets/data/nba/stats/team_by_season.json', recordCount: 0, status: 'Source pending', priority: 'P1', nextStep: 'Normalize team season rows and standings joins.'),
  CoverageItem(dataset: 'Games', domain: 'Games', assetPath: 'assets/data/nba/games/game_records.json', recordCount: 0, status: 'Source pending', priority: 'P2', nextStep: 'Add historical schedule and result records.'),
  CoverageItem(dataset: 'Standings', domain: 'Teams', assetPath: 'assets/data/nba/standings/standings_records.json', recordCount: 0, status: 'Source pending', priority: 'P2', nextStep: 'Add team-season records, seeds, and games-back fields.'),
  CoverageItem(dataset: 'Playoff series', domain: 'Playoffs', assetPath: 'assets/data/nba/playoffs/playoff_series_records.json', recordCount: 0, status: 'Source pending', priority: 'P2', nextStep: 'Add series records and bracket relationships.'),
  CoverageItem(dataset: 'Rosters', domain: 'Rosters', assetPath: 'assets/data/nba/rosters/roster_entries.json', recordCount: 0, status: 'Source pending', priority: 'P2', nextStep: 'Add team-season roster snapshots.'),
  CoverageItem(dataset: 'Awards', domain: 'Awards', assetPath: 'assets/data/nba/awards/award_records.json', recordCount: 0, status: 'Source pending', priority: 'P2', nextStep: 'Add award winners and voting records.'),
  CoverageItem(dataset: 'Draft picks', domain: 'Draft', assetPath: 'assets/data/nba/draft/draft_picks.json', recordCount: 0, status: 'Source pending', priority: 'P2', nextStep: 'Add historical draft pick records.'),
  CoverageItem(dataset: 'Transactions', domain: 'Transactions', assetPath: 'assets/data/nba/transactions/transaction_records.json', recordCount: 0, status: 'Source pending', priority: 'P3', nextStep: 'Choose transaction source and normalize movement types.'),
  CoverageItem(dataset: 'Injuries', domain: 'Availability', assetPath: 'assets/data/nba/injuries/injury_records.json', recordCount: 0, status: 'Created, not registered', priority: 'P4', nextStep: 'Register asset only when availability workflow is ready.'),
];
