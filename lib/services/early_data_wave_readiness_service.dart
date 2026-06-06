import 'nba_asset_repository.dart';
import 'player_identity_validator.dart';
import 'player_season_stat_validator.dart';
import 'team_season_stat_validator.dart';

class DataWaveReadinessRow {
  const DataWaveReadinessRow({required this.wave, required this.rows, required this.blockers, required this.warnings, required this.status, required this.nextStep});

  final String wave;
  final int rows;
  final int blockers;
  final int warnings;
  final String status;
  final String nextStep;
}

class EarlyDataWaveReadinessSummary {
  const EarlyDataWaveReadinessSummary({required this.rows});

  final List<DataWaveReadinessRow> rows;

  int get totalRows => rows.fold(0, (total, row) => total + row.rows);
  int get totalBlockers => rows.fold(0, (total, row) => total + row.blockers);
  int get totalWarnings => rows.fold(0, (total, row) => total + row.warnings);
  bool get canContinue => totalBlockers == 0;
}

class EarlyDataWaveReadinessService {
  const EarlyDataWaveReadinessService({this.repository = const NbaAssetRepository()});

  final NbaAssetRepository repository;

  Future<EarlyDataWaveReadinessSummary> evaluate() async {
    final teams = await repository.loadTeams();
    final seasons = await repository.loadSeasons();
    final players = await repository.loadPlayerProfiles();
    final aliases = await repository.loadPlayerAliases();
    final playerStats = await repository.loadPlayerSeasonStats();
    final teamStats = await repository.loadTeamSeasonStats();

    final identity = const PlayerIdentityValidator().validate(players: players, aliases: aliases);
    final playerStatValidation = const PlayerSeasonStatValidator().validate(stats: playerStats, players: players, seasons: seasons, teams: teams);
    final teamStatValidation = const TeamSeasonStatValidator().validate(stats: teamStats, teams: teams, seasons: seasons);

    return EarlyDataWaveReadinessSummary(rows: [
      DataWaveReadinessRow(wave: 'Reference teams', rows: teams.length, blockers: teams.length == 30 ? 0 : 1, warnings: 0, status: teams.length == 30 ? 'Connected' : 'Review', nextStep: 'Keep team directory stable before team stat imports.'),
      DataWaveReadinessRow(wave: 'Reference seasons', rows: seasons.length, blockers: seasons.isNotEmpty ? 0 : 1, warnings: 0, status: seasons.isNotEmpty ? 'Connected' : 'Review', nextStep: 'Keep season catalog stable before stat imports.'),
      DataWaveReadinessRow(wave: 'Player identity', rows: players.length, blockers: identity.blockers, warnings: identity.warnings, status: players.isEmpty ? 'Source pending' : identity.canConnect ? 'Connected' : 'Blocked', nextStep: players.isEmpty ? 'Import CommonAllPlayers identity first.' : 'Route imported players through Search and consumers.'),
      DataWaveReadinessRow(wave: 'Player season stats', rows: playerStats.length, blockers: playerStatValidation.blockers, warnings: playerStatValidation.warnings, status: playerStats.isEmpty ? 'Source pending' : playerStatValidation.canConnect ? 'Connected' : 'Blocked', nextStep: 'Import only after player identity is validated.'),
      DataWaveReadinessRow(wave: 'Team season stats', rows: teamStats.length, blockers: teamStatValidation.blockers, warnings: teamStatValidation.warnings, status: teamStats.isEmpty ? 'Source pending' : teamStatValidation.canConnect ? 'Connected' : 'Blocked', nextStep: 'Import after player stats or alongside controlled team context.'),
    ]);
  }
}
