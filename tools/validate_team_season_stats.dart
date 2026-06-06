import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/models/team_season_stat.dart';
import 'package:sports_terminal/services/team_season_stat_validator.dart';

void main() {
  final teams = _loadTeams();
  final seasons = _loadSeasons();
  final stats = _loadStats();
  final summary = const TeamSeasonStatValidator().validate(stats: stats, teams: teams, seasons: seasons);

  print('Team season stat validation summary');
  print('Teams: ${teams.length}');
  print('Seasons: ${seasons.length}');
  print('Team stat rows: ${stats.length}');
  print('Blockers: ${summary.blockers}');
  print('Warnings: ${summary.warnings}');

  for (final issue in summary.issues) {
    print('- ${issue.severity} ${issue.code} ${issue.rowId ?? 'global'}: ${issue.message}');
  }

  if (!summary.canConnect) {
    throw StateError('Team season stat assets are blocked and should not be connected.');
  }

  print('Team season stat assets are connectable.');
}

List<Team> _loadTeams() {
  final decoded = jsonDecode(File('assets/data/nba/teams/teams.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['teams'] as List<dynamic>).map((row) => Team.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<Season> _loadSeasons() {
  final decoded = jsonDecode(File('assets/data/nba/seasons/seasons.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['seasons'] as List<dynamic>).map((row) => Season.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<TeamSeasonStat> _loadStats() {
  final decoded = jsonDecode(File('assets/data/nba/stats/team_by_season.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['teamSeasonStats'] as List<dynamic>).map((row) => TeamSeasonStat.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}
