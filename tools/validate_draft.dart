import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/models/draft_pick.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/draft_pick_validator.dart';

void main() {
  final players = _loadPlayers();
  final teams = _loadTeams();
  final picks = _loadPicks();
  final summary = const DraftPickValidator().validate(picks: picks, players: players, teams: teams);

  print('Draft validation summary');
  print('Players: ${players.length}');
  print('Teams: ${teams.length}');
  print('Draft pick rows: ${picks.length}');
  print('Blockers: ${summary.blockers}');
  print('Warnings: ${summary.warnings}');

  for (final issue in summary.issues) {
    print('- ${issue.severity} ${issue.code} ${issue.rowId ?? 'global'}: ${issue.message}');
  }

  if (!summary.canConnect) throw StateError('Draft assets are blocked and should not be connected.');
  print('Draft assets are connectable.');
}

List<PlayerProfile> _loadPlayers() {
  final decoded = jsonDecode(File('assets/data/nba/players/player_profiles.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['players'] as List<dynamic>).map((row) => PlayerProfile.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<Team> _loadTeams() {
  final decoded = jsonDecode(File('assets/data/nba/teams/teams.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['teams'] as List<dynamic>).map((row) => Team.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<DraftPick> _loadPicks() {
  final decoded = jsonDecode(File('assets/data/nba/draft/draft_picks.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['draftPicks'] as List<dynamic>).map((row) => DraftPick.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}
