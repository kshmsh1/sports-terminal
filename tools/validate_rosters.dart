import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/roster_entry.dart';
import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/roster_entry_validator.dart';

void main() {
  final players = _loadPlayers();
  final teams = _loadTeams();
  final seasons = _loadSeasons();
  final rosters = _loadRosters();
  final enforceFinalSnapshot = rosters.isNotEmpty;
  final summary = const RosterEntryValidator().validate(
    rosters: rosters,
    players: players,
    teams: teams,
    seasons: seasons,
    requireFinalRosterSnapshot: enforceFinalSnapshot,
  );

  print('Roster validation summary');
  print('Players: ${players.length}');
  print('Teams: ${teams.length}');
  print('Seasons: ${seasons.length}');
  print('Roster rows: ${rosters.length}');
  print('Final snapshot contract: ${enforceFinalSnapshot ? 'enforced' : 'source pending'}');
  print('Blockers: ${summary.blockers}');
  print('Warnings: ${summary.warnings}');

  for (final issue in summary.issues) {
    print('- ${issue.severity} ${issue.code} ${issue.rowId ?? 'global'}: ${issue.message}');
  }

  if (!summary.canConnect) throw StateError('Roster assets are blocked and should not be connected.');
  print('Roster assets are connectable.');
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

List<RosterEntry> _loadRosters() {
  final decoded = jsonDecode(File('assets/data/nba/rosters/roster_entries.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['rosters'] as List<dynamic>).map((row) => RosterEntry.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}
