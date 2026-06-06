import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/player_season_stat.dart';
import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/player_season_stat_validator.dart';

void main() {
  final players = _loadPlayers();
  final seasons = _loadSeasons();
  final teams = _loadTeams();
  final stats = _loadStats();
  final summary = const PlayerSeasonStatValidator().validate(stats: stats, players: players, seasons: seasons, teams: teams);

  print('Player season stat validation summary');
  print('Players: ${players.length}');
  print('Seasons: ${seasons.length}');
  print('Teams: ${teams.length}');
  print('Player stat rows: ${stats.length}');
  print('Blockers: ${summary.blockers}');
  print('Warnings: ${summary.warnings}');

  for (final issue in summary.issues) {
    print('- ${issue.severity} ${issue.code} ${issue.rowId ?? 'global'}: ${issue.message}');
  }

  if (!summary.canConnect) {
    throw StateError('Player season stat assets are blocked and should not be connected.');
  }

  print('Player season stat assets are connectable.');
}

List<PlayerProfile> _loadPlayers() {
  final decoded = jsonDecode(File('assets/data/nba/players/player_profiles.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['players'] as List<dynamic>).map((row) => PlayerProfile.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<Season> _loadSeasons() {
  final decoded = jsonDecode(File('assets/data/nba/seasons/seasons.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['seasons'] as List<dynamic>).map((row) => Season.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<Team> _loadTeams() {
  final decoded = jsonDecode(File('assets/data/nba/teams/teams.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['teams'] as List<dynamic>).map((row) => Team.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<PlayerSeasonStat> _loadStats() {
  final decoded = jsonDecode(File('assets/data/nba/stats/player_traditional_by_season.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['playerSeasonStats'] as List<dynamic>).map((row) => PlayerSeasonStat.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}
