import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/models/game_record.dart';
import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/game_record_validator.dart';

void main() {
  final teams = _loadTeams();
  final seasons = _loadSeasons();
  final games = _loadGames();
  final summary = const GameRecordValidator().validate(games: games, teams: teams, seasons: seasons);

  print('Games validation summary');
  print('Teams: ${teams.length}');
  print('Seasons: ${seasons.length}');
  print('Game rows: ${games.length}');
  print('Blockers: ${summary.blockers}');
  print('Warnings: ${summary.warnings}');

  for (final issue in summary.issues) {
    print('- ${issue.severity} ${issue.code} ${issue.rowId ?? 'global'}: ${issue.message}');
  }

  if (!summary.canConnect) throw StateError('Game assets are blocked and should not be connected.');
  print('Game assets are connectable.');
}

List<Team> _loadTeams() {
  final decoded = jsonDecode(File('assets/data/nba/teams/teams.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['teams'] as List<dynamic>).map((row) => Team.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<Season> _loadSeasons() {
  final decoded = jsonDecode(File('assets/data/nba/seasons/seasons.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['seasons'] as List<dynamic>).map((row) => Season.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<GameRecord> _loadGames() {
  final decoded = jsonDecode(File('assets/data/nba/games/game_records.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['games'] as List<dynamic>).map((row) => GameRecord.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}
