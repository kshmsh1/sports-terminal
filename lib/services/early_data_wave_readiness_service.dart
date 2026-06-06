import 'award_record_validator.dart';
import 'draft_pick_validator.dart';
import 'game_record_validator.dart';
import 'nba_asset_repository.dart';
import 'player_identity_validator.dart';
import 'player_season_stat_validator.dart';
import 'playoff_series_validator.dart';
import 'roster_entry_validator.dart';
import 'standings_record_validator.dart';
import 'team_season_stat_validator.dart';
import 'transaction_record_validator.dart';

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
    final standings = await repository.loadStandings();
    final playoffs = await repository.loadPlayoffSeries();
    final awards = await repository.loadAwards();
    final games = await repository.loadGames();
    final rosters = await repository.loadRosters();
    final draft = await repository.loadDraftPicks();
    final transactions = await repository.loadTransactions();

    final identity = const PlayerIdentityValidator().validate(players: players, aliases: aliases);
    final playerStatValidation = const PlayerSeasonStatValidator().validate(stats: playerStats, players: players, seasons: seasons, teams: teams);
    final teamStatValidation = const TeamSeasonStatValidator().validate(stats: teamStats, teams: teams, seasons: seasons);
    final standingsValidation = const StandingsRecordValidator().validate(standings: standings, teams: teams, seasons: seasons);
    final playoffValidation = const PlayoffSeriesValidator().validate(series: playoffs, teams: teams, seasons: seasons);
    final awardValidation = const AwardRecordValidator().validate(awards: awards, players: players, teams: teams, seasons: seasons);
    final gameValidation = const GameRecordValidator().validate(games: games, teams: teams, seasons: seasons);
    final rosterValidation = const RosterEntryValidator().validate(rosters: rosters, players: players, teams: teams, seasons: seasons);
    final draftValidation = const DraftPickValidator().validate(picks: draft, players: players, teams: teams);
    final transactionValidation = const TransactionRecordValidator().validate(transactions: transactions, players: players, teams: teams);

    return EarlyDataWaveReadinessSummary(rows: [
      DataWaveReadinessRow(wave: 'Reference teams', rows: teams.length, blockers: teams.length == 30 ? 0 : 1, warnings: 0, status: teams.length == 30 ? 'Connected' : 'Review', nextStep: 'Keep team directory stable before team stat imports.'),
      DataWaveReadinessRow(wave: 'Reference seasons', rows: seasons.length, blockers: seasons.isNotEmpty ? 0 : 1, warnings: 0, status: seasons.isNotEmpty ? 'Connected' : 'Review', nextStep: 'Keep season catalog stable before stat imports.'),
      DataWaveReadinessRow(wave: 'Player identity', rows: players.length, blockers: identity.blockers, warnings: identity.warnings, status: players.isEmpty ? 'Source pending' : identity.canConnect ? 'Connected' : 'Blocked', nextStep: players.isEmpty ? 'Import CommonAllPlayers identity first.' : 'Route imported players through Search and consumers.'),
      DataWaveReadinessRow(wave: 'Player season stats', rows: playerStats.length, blockers: playerStatValidation.blockers, warnings: playerStatValidation.warnings, status: playerStats.isEmpty ? 'Source pending' : playerStatValidation.canConnect ? 'Connected' : 'Blocked', nextStep: 'Import only after player identity is validated.'),
      DataWaveReadinessRow(wave: 'Team season stats', rows: teamStats.length, blockers: teamStatValidation.blockers, warnings: teamStatValidation.warnings, status: teamStats.isEmpty ? 'Source pending' : teamStatValidation.canConnect ? 'Connected' : 'Blocked', nextStep: 'Import before standings depend on team context.'),
      DataWaveReadinessRow(wave: 'Standings', rows: standings.length, blockers: standingsValidation.blockers, warnings: standingsValidation.warnings, status: standings.isEmpty ? 'Source pending' : standingsValidation.canConnect ? 'Connected' : 'Blocked', nextStep: 'Import after team stats or with validated team-season context.'),
      DataWaveReadinessRow(wave: 'Playoff series', rows: playoffs.length, blockers: playoffValidation.blockers, warnings: playoffValidation.warnings, status: playoffs.isEmpty ? 'Source pending' : playoffValidation.canConnect ? 'Connected' : 'Blocked', nextStep: 'Import after standings/team-season joins are stable.'),
      DataWaveReadinessRow(wave: 'Awards and MVP voting', rows: awards.length, blockers: awardValidation.blockers, warnings: awardValidation.warnings, status: awards.isEmpty ? 'Source pending' : awardValidation.canConnect ? 'Connected' : 'Blocked', nextStep: 'Import after player identity joins are stable.'),
      DataWaveReadinessRow(wave: 'Games', rows: games.length, blockers: gameValidation.blockers, warnings: gameValidation.warnings, status: games.isEmpty ? 'Source pending' : gameValidation.canConnect ? 'Connected' : 'Blocked', nextStep: 'Import after teams, seasons, and schedule source posture are stable.'),
      DataWaveReadinessRow(wave: 'Rosters', rows: rosters.length, blockers: rosterValidation.blockers, warnings: rosterValidation.warnings, status: rosters.isEmpty ? 'Source pending' : rosterValidation.canConnect ? 'Connected' : 'Blocked', nextStep: 'Import after player identity and team-season joins are stable.'),
      DataWaveReadinessRow(wave: 'Draft picks', rows: draft.length, blockers: draftValidation.blockers, warnings: draftValidation.warnings, status: draft.isEmpty ? 'Source pending' : draftValidation.canConnect ? 'Connected' : 'Blocked', nextStep: 'Import after player identity or with documented unjoined player names.'),
      DataWaveReadinessRow(wave: 'Transactions', rows: transactions.length, blockers: transactionValidation.blockers, warnings: transactionValidation.warnings, status: transactions.isEmpty ? 'Source pending' : transactionValidation.canConnect ? 'Connected' : 'Blocked', nextStep: 'Import after player identity and team joins are stable.'),
    ]);
  }
}
