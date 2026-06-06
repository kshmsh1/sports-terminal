import 'package:sports_terminal/services/nba_asset_repository.dart';
import 'package:sports_terminal/services/player_season_stat_validator.dart';

Future<void> main() async {
  final repository = const NbaAssetRepository();
  final players = await repository.loadPlayerProfiles();
  final seasons = await repository.loadSeasons();
  final teams = await repository.loadTeams();
  final stats = await repository.loadPlayerSeasonStats();
  final summary = const PlayerSeasonStatValidator().validate(stats: stats, players: players, seasons: seasons, teams: teams);

  print('Player season stat validation summary');
  print('Players: ${players.length}');
  print('Seasons: ${seasons.length}');
  print('Teams: ${teams.length}');
  print('Player stat rows: ${stats.length}');
  print('Blockers: ${summary.blockers}');
  print('Warnings: ${summary.warnings}');

  if (summary.issues.isNotEmpty) {
    print('Issues:');
    for (final issue in summary.issues) {
      print('- ${issue.severity} ${issue.code} ${issue.rowId ?? 'global'}: ${issue.message}');
    }
  }

  if (!summary.canConnect) {
    throw StateError('Player season stat assets are blocked and should not be connected.');
  }

  print('Player season stat assets are connectable.');
}
