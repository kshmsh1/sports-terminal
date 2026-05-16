class DatasetRegistryItem {
  const DatasetRegistryItem({
    required this.dataset,
    required this.domain,
    required this.storageTarget,
    required this.sourcePreference,
    required this.status,
    required this.refreshMode,
    required this.notes,
  });

  final String dataset;
  final String domain;
  final String storageTarget;
  final String sourcePreference;
  final String status;
  final String refreshMode;
  final String notes;
}

const datasetRegistryItems = <DatasetRegistryItem>[
  DatasetRegistryItem(
    dataset: 'NBA team directory',
    domain: 'Teams',
    storageTarget: 'lib/data/nba_teams.dart now; assets/data/nba/teams.json later',
    sourcePreference: 'Manual verified reference data, official league structure preferred',
    status: 'Connected',
    refreshMode: 'Manual when league structure changes',
    notes: 'Current NBA teams are available in the app. Historical franchise mapping still needs a separate dataset.',
  ),
  DatasetRegistryItem(
    dataset: 'NBA/BAA season catalog',
    domain: 'Seasons',
    storageTarget: 'lib/data/nba_seasons.dart now; assets/data/nba/seasons.json later',
    sourcePreference: 'Manual generated historical season reference',
    status: 'Connected',
    refreshMode: 'Annual manual update',
    notes: 'Season identifiers are available from 1946-47 through 2025-26.',
  ),
  DatasetRegistryItem(
    dataset: 'Player identity index',
    domain: 'Players',
    storageTarget: 'assets/data/nba/players/player_profiles.json',
    sourcePreference: 'Official NBA player index where feasible',
    status: 'Next',
    refreshMode: 'Snapshot import',
    notes: 'This should be the next real data target before player statistics are connected.',
  ),
  DatasetRegistryItem(
    dataset: 'Traditional player season stats',
    domain: 'Statistics',
    storageTarget: 'assets/data/nba/stats/player_traditional_by_season.json',
    sourcePreference: 'NBA.com/stats historical tables where feasible and legally appropriate',
    status: 'Planned',
    refreshMode: 'Historical snapshots',
    notes: 'Start with season-level regular-season production before advanced or game-level data.',
  ),
  DatasetRegistryItem(
    dataset: 'Advanced player season stats',
    domain: 'Statistics',
    storageTarget: 'assets/data/nba/stats/player_advanced_by_season.json',
    sourcePreference: 'Official or provider-backed source with metric definitions',
    status: 'Planned',
    refreshMode: 'Historical snapshots',
    notes: 'Definitions must be stored because advanced statistics can vary across providers.',
  ),
  DatasetRegistryItem(
    dataset: 'Team season stats',
    domain: 'Statistics',
    storageTarget: 'assets/data/nba/stats/team_by_season.json',
    sourcePreference: 'NBA.com/stats or licensed provider',
    status: 'Planned',
    refreshMode: 'Historical snapshots',
    notes: 'Needed to turn Teams and Seasons into analytical pages rather than directories.',
  ),
  DatasetRegistryItem(
    dataset: 'Game schedule and results',
    domain: 'Games',
    storageTarget: 'assets/data/nba/games/game_records.json',
    sourcePreference: 'Official NBA source or licensed provider',
    status: 'Planned',
    refreshMode: 'Historical snapshots first; live later',
    notes: 'Game records unlock box-score tables, player logs, team logs, playoff series context, and matchup analysis.',
  ),
  DatasetRegistryItem(
    dataset: 'Awards and voting',
    domain: 'Awards',
    storageTarget: 'assets/data/nba/awards/award_records.json',
    sourcePreference: 'Official league records or reputable historical datasets with citation',
    status: 'Planned',
    refreshMode: 'Annual snapshot',
    notes: 'High-value historical context that can be added before complex live data.',
  ),
  DatasetRegistryItem(
    dataset: 'Draft history',
    domain: 'Draft',
    storageTarget: 'assets/data/nba/draft/draft_picks.json',
    sourcePreference: 'Official NBA draft records where feasible',
    status: 'Planned',
    refreshMode: 'Annual snapshot',
    notes: 'Connects player profiles, prospect history, team building, and G League development paths.',
  ),
  DatasetRegistryItem(
    dataset: 'Transactions',
    domain: 'Transactions',
    storageTarget: 'assets/data/nba/transactions/transaction_records.json',
    sourcePreference: 'Official transaction logs or licensed/provider-backed source',
    status: 'Source needed',
    refreshMode: 'Snapshot first; live later',
    notes: 'Needs careful source selection because transaction history can be messy and incomplete across public datasets.',
  ),
  DatasetRegistryItem(
    dataset: 'Salary and cap records',
    domain: 'Financial',
    storageTarget: 'assets/data/nba/financial/salary_records.json',
    sourcePreference: 'Lawful third-party or licensed provider',
    status: 'Source needed',
    refreshMode: 'Snapshot import',
    notes: 'Keep separate from official box-score statistics. Do not assume salary data is covered by NBA.com/stats.',
  ),
  DatasetRegistryItem(
    dataset: 'G League affiliate map',
    domain: 'G League',
    storageTarget: 'assets/data/nba/g_league/affiliate_map.json',
    sourcePreference: 'Official team and G League references where feasible',
    status: 'Future',
    refreshMode: 'Manual / snapshot',
    notes: 'Add after NBA core identity and team history layers are stronger.',
  ),
];
