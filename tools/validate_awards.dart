import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/models/award_record.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/award_record_validator.dart';

void main() {
  final players = _loadPlayers();
  final teams = _loadTeams();
  final seasons = _loadSeasons();
  final awards = _loadAwards();
  final summary = const AwardRecordValidator().validate(awards: awards, players: players, teams: teams, seasons: seasons);

  print('Awards validation summary');
  print('Players: ${players.length}');
  print('Teams: ${teams.length}');
  print('Seasons: ${seasons.length}');
  print('Award rows: ${awards.length}');
  print('Blockers: ${summary.blockers}');
  print('Warnings: ${summary.warnings}');

  for (final issue in summary.issues) {
    print('- ${issue.severity} ${issue.code} ${issue.rowId ?? 'global'}: ${issue.message}');
  }

  if (!summary.canConnect) {
    throw StateError('Award assets are blocked and should not be connected.');
  }

  print('Award assets are connectable.');
}

List<PlayerProfile> _loadPlayers() {
  final decoded = jsonDecode(File('assets/data/nba/players/player_profiles.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['players'] as List<dynamic>).map((row) => PlayerProfile.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<Team> _loadTeams() {
  final decoded = jsonDecode(File('assets/data/nba/teams/teams.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['teams'] as List<dynamic>).map((row) => Team.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<Season> _loadSeasons() {
  final decoded = jsonDecode(File('assets/data/nba/seasons/seasons.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['seasons'] as List<dynamic>).map((row) => Season.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<AwardRecord> _loadAwards() {
  final decoded = jsonDecode(File('assets/data/nba/awards/award_records.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['awards'] as List<dynamic>).map((row) => AwardRecord.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}
