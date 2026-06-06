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

class NbaAssetValidationRow {
  const NbaAssetValidationRow({required this.dataset, required this.rows, required this.blockers, required this.warnings});

  final String dataset;
  final int rows;
  final int blockers;
  final int warnings;

  bool get canConnect => blockers == 0;
}

class NbaAssetValidationSummary {
  const NbaAssetValidationSummary({required this.rows});

  final List<NbaAssetValidationRow> rows;

  int get totalRows => rows.fold(0, (sum, row) => sum + row.rows);
  int get totalBlockers => rows.fold(0, (sum, row) => sum + row.blockers);
  int get totalWarnings => rows.fold(0, (sum, row) => sum + row.warnings);
  bool get canConnectAll => totalBlockers == 0;
}

class NbaAssetValidationService {
  const NbaAssetValidationService({this.repository = const NbaAssetRepository()});

  final NbaAssetRepository repository;

  Future<NbaAssetValidationSummary> validateAll() async {
    final teams = await repository.loadTeams();
    final seasons = await repository.loadSeasons();
    final players = await repository.loadPlayerProfiles();
    final aliases = await repository.loadPlayerAliases();
    final playerStats = await repository.loadPlayerSeasonStats();
    final teamStats = await repository.loadTeamSeasonStats();
    final standings = await repository.loadStandings();
    final playoffSeries = await repository.loadPlayoffSeries();
    final awards = await repository.loadAwards();
    final games = await repository.loadGames();
    final rosters = await repository.loadRosters();
    final draft = await repository.loadDraftPicks();
    final transactions = await repository.loadTransactions();

    final identity = const PlayerIdentityValidator().validate(players: players, aliases: aliases);
    final playerStat = const PlayerSeasonStatValidator().validate(stats: playerStats, players: players, seasons: seasons, teams: teams);
    final teamStat = const TeamSeasonStatValidator().validate(stats: teamStats, teams: teams, seasons: seasons);
    final standing = const StandingsRecordValidator().validate(standings: standings, teams: teams, seasons: seasons);
    final playoffs = const PlayoffSeriesValidator().validate(series: playoffSeries, teams: teams, seasons: seasons);
    final award = const AwardRecordValidator().validate(awards: awards, players: players, teams: teams, seasons: seasons);
    final game = const GameRecordValidator().validate(games: games, teams: teams, seasons: seasons);
    final roster = const RosterEntryValidator().validate(rosters: rosters, players: players, teams: teams, seasons: seasons);
    final draftValidation = const DraftPickValidator().validate(picks: draft, players: players, teams: teams);
    final transaction = const TransactionRecordValidator().validate(transactions: transactions, players: players, teams: teams);

    return NbaAssetValidationSummary(rows: [
      NbaAssetValidationRow(dataset: 'Player Identity', rows: players.length + aliases.length, blockers: identity.blockers, warnings: identity.warnings),
      NbaAssetValidationRow(dataset: 'Player Season Stats', rows: playerStats.length, blockers: playerStat.blockers, warnings: playerStat.warnings),
      NbaAssetValidationRow(dataset: 'Team Season Stats', rows: teamStats.length, blockers: teamStat.blockers, warnings: teamStat.warnings),
      NbaAssetValidationRow(dataset: 'Standings', rows: standings.length, blockers: standing.blockers, warnings: standing.warnings),
      NbaAssetValidationRow(dataset: 'Playoff Series', rows: playoffSeries.length, blockers: playoffs.blockers, warnings: playoffs.warnings),
      NbaAssetValidationRow(dataset: 'Awards', rows: awards.length, blockers: award.blockers, warnings: award.warnings),
      NbaAssetValidationRow(dataset: 'Games', rows: games.length, blockers: game.blockers, warnings: game.warnings),
      NbaAssetValidationRow(dataset: 'Rosters', rows: rosters.length, blockers: roster.blockers, warnings: roster.warnings),
      NbaAssetValidationRow(dataset: 'Draft Picks', rows: draft.length, blockers: draftValidation.blockers, warnings: draftValidation.warnings),
      NbaAssetValidationRow(dataset: 'Transactions', rows: transactions.length, blockers: transaction.blockers, warnings: transaction.warnings),
    ]);
  }
}
