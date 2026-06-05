import '../data/import_acceptance_gate_items.dart';
import '../data/player_identity_contract_items.dart';
import '../data/player_identity_schema_gate_items.dart';
import '../data/pre_data_readiness_items.dart';
import '../models/registry_item.dart';
import 'nba_asset_repository.dart';

class PreDataSmokeTestResult {
  const PreDataSmokeTestResult({
    required this.name,
    required this.category,
    required this.status,
    required this.detail,
    required this.nextStep,
  });

  final String name;
  final String category;
  final String status;
  final String detail;
  final String nextStep;

  bool get passed => status == 'Pass';
  bool get warning => status == 'Warn';
  bool get failed => status == 'Fail';
}

class PreDataSmokeTestSummary {
  const PreDataSmokeTestSummary({required this.results});
  final List<PreDataSmokeTestResult> results;

  int get total => results.length;
  int get passed => results.where((item) => item.passed).length;
  int get warnings => results.where((item) => item.warning).length;
  int get failed => results.where((item) => item.failed).length;
  int get completion => total == 0 ? 0 : (passed / total * 100).round();
  bool get canAttemptPlayerIdentityImport => failed == 0 && warnings <= 4;
}

class PreDataSmokeTestService {
  const PreDataSmokeTestService({this.repository = const NbaAssetRepository()});

  final NbaAssetRepository repository;

  Future<PreDataSmokeTestSummary> run() async {
    final teams = await repository.loadTeams();
    final seasons = await repository.loadSeasons();
    final players = await repository.loadPlayerProfiles();
    final playerStats = await repository.loadPlayerSeasonStats();
    final teamStats = await repository.loadTeamSeasonStats();
    final games = await repository.loadGames();
    final rosters = await repository.loadRosters();
    final awards = await repository.loadAwards();
    final draft = await repository.loadDraftPicks();
    final transactions = await repository.loadTransactions();
    final standings = await repository.loadStandings();
    final playoffs = await repository.loadPlayoffSeries();
    final manifest = await repository.loadDatasetManifest();

    final routeDone = _countStatus(preDataReadinessItems, 'Done');
    final routeRemaining = preDataReadinessItems.where((item) => item.category == 'Consumer Wiring' && item.status != 'Done').length;
    final schemaLocked = _countStatus(playerIdentityContractItems, 'Locked');
    final schemaRequired = playerIdentitySchemaGateItems.where((item) => item.priority == 'P0').length;
    final importRequired = importAcceptanceGateItems.where((item) => item.priority == 'P0').length;

    return PreDataSmokeTestSummary(results: [
      _expect('Team directory connected', 'Reference Assets', teams.length == 30, '${teams.length} teams loaded', 'Keep teams.json stable as the first team reference spine.'),
      _expect('Season catalog connected', 'Reference Assets', seasons.length >= 75, '${seasons.length} seasons loaded', 'Keep seasons.json stable as the first historical time spine.'),
      _expect('Dataset manifest readable', 'Reference Assets', manifest.isNotEmpty, '${manifest.keys.length} manifest keys loaded', 'Use the manifest as the source of truth for local asset coverage.'),
      _expect('Player identity intentionally empty', 'Connected Empty Assets', players.isEmpty, '${players.length} player rows loaded', 'Stay empty until the source path and validation gates are locked.'),
      _expect('Player stats intentionally empty', 'Connected Empty Assets', playerStats.isEmpty, '${playerStats.length} player-stat rows loaded', 'Do not import stats before player identity joins are safe.'),
      _expect('Team stats intentionally empty', 'Connected Empty Assets', teamStats.isEmpty, '${teamStats.length} team-stat rows loaded', 'Load after identity and before standings context.'),
      _expect('Games intentionally empty', 'Connected Empty Assets', games.isEmpty, '${games.length} games loaded', 'Keep empty until schedule/result source posture is clear.'),
      _expect('Rosters intentionally empty', 'Connected Empty Assets', rosters.isEmpty, '${rosters.length} roster rows loaded', 'Keep empty until roster windows and player joins are defined.'),
      _expect('Awards intentionally empty', 'Connected Empty Assets', awards.isEmpty, '${awards.length} award rows loaded', 'Import MVP voting only after player identity and stats exist.'),
      _expect('Draft intentionally empty', 'Connected Empty Assets', draft.isEmpty, '${draft.length} draft rows loaded', 'Import after player identity and draft source posture are defined.'),
      _expect('Transactions intentionally empty', 'Connected Empty Assets', transactions.isEmpty, '${transactions.length} transaction rows loaded', 'Import only after transaction taxonomy and roster windows are defined.'),
      _expect('Standings intentionally empty', 'Connected Empty Assets', standings.isEmpty, '${standings.length} standings rows loaded', 'Import after team stats and season/team joins are stable.'),
      _expect('Playoffs intentionally empty', 'Connected Empty Assets', playoffs.isEmpty, '${playoffs.length} playoff-series rows loaded', 'Import after standings and team/season joins are stable.'),
      _expect('Route consumer gates mostly done', 'Route Layer', routeRemaining <= 1, '$routeDone readiness gates done; $routeRemaining consumer gates remaining', 'Close the last registry-status gap and run local UI smoke tests.'),
      _expect('Player identity contract locked', 'Player Identity', schemaLocked == playerIdentityContractItems.length, '$schemaLocked/${playerIdentityContractItems.length} contract rows locked', 'Keep PlayerAlias and canonical playerId policy stable.'),
      _expect('Player schema gates specified', 'Player Identity', schemaRequired >= 8, '$schemaRequired P0 schema gates specified', 'Convert required gates into validation checks before import.'),
      _expect('Import acceptance gates specified', 'Import Controls', importRequired >= 8, '$importRequired P0 import gates specified', 'Turn acceptance gates into validator output for player identity.'),
    ]);
  }

  int _countStatus(List<RegistryItem> items, String status) => items.where((item) => item.status == status).length;

  PreDataSmokeTestResult _expect(String name, String category, bool condition, String detail, String nextStep) {
    return PreDataSmokeTestResult(name: name, category: category, status: condition ? 'Pass' : 'Fail', detail: detail, nextStep: nextStep);
  }
}
