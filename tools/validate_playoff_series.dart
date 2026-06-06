import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/models/playoff_series_record.dart';
import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/playoff_series_validator.dart';

void main() {
  final teams = _loadTeams();
  final seasons = _loadSeasons();
  final series = _loadSeries();
  final summary = const PlayoffSeriesValidator().validate(series: series, teams: teams, seasons: seasons);

  print('Playoff series validation summary');
  print('Teams: ${teams.length}');
  print('Seasons: ${seasons.length}');
  print('Playoff series rows: ${series.length}');
  print('Blockers: ${summary.blockers}');
  print('Warnings: ${summary.warnings}');

  for (final issue in summary.issues) {
    print('- ${issue.severity} ${issue.code} ${issue.rowId ?? 'global'}: ${issue.message}');
  }

  if (!summary.canConnect) {
    throw StateError('Playoff series assets are blocked and should not be connected.');
  }

  print('Playoff series assets are connectable.');
}

List<Team> _loadTeams() {
  final decoded = jsonDecode(File('assets/data/nba/teams/teams.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['teams'] as List<dynamic>).map((row) => Team.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<Season> _loadSeasons() {
  final decoded = jsonDecode(File('assets/data/nba/seasons/seasons.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['seasons'] as List<dynamic>).map((row) => Season.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<PlayoffSeriesRecord> _loadSeries() {
  final decoded = jsonDecode(File('assets/data/nba/playoffs/playoff_series_records.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['playoffSeries'] as List<dynamic>).map((row) => PlayoffSeriesRecord.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}
