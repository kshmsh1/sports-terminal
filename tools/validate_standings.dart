import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/standings_record.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/standings_record_validator.dart';

void main() {
  final teams = _loadTeams();
  final seasons = _loadSeasons();
  final standings = _loadStandings();
  final summary = const StandingsRecordValidator().validate(standings: standings, teams: teams, seasons: seasons);

  print('Standings validation summary');
  print('Teams: ${teams.length}');
  print('Seasons: ${seasons.length}');
  print('Standings rows: ${standings.length}');
  print('Blockers: ${summary.blockers}');
  print('Warnings: ${summary.warnings}');

  for (final issue in summary.issues) {
    print('- ${issue.severity} ${issue.code} ${issue.rowId ?? 'global'}: ${issue.message}');
  }

  if (!summary.canConnect) {
    throw StateError('Standings assets are blocked and should not be connected.');
  }

  print('Standings assets are connectable.');
}

List<Team> _loadTeams() {
  final decoded = jsonDecode(File('assets/data/nba/teams/teams.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['teams'] as List<dynamic>).map((row) => Team.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<Season> _loadSeasons() {
  final decoded = jsonDecode(File('assets/data/nba/seasons/seasons.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['seasons'] as List<dynamic>).map((row) => Season.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<StandingsRecord> _loadStandings() {
  final decoded = jsonDecode(File('assets/data/nba/standings/standings_records.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['standings'] as List<dynamic>).map((row) => StandingsRecord.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}
