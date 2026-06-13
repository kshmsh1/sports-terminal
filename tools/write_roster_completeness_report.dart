import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/roster_entry.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/roster_completeness_service.dart';
import 'package:sports_terminal/services/roster_directory_service.dart';

void main() {
  final players = _loadPlayers();
  final teams = _loadTeams();
  final rosters = _loadRosters();
  final rows = const RosterDirectoryService().join(
    rosters: rosters,
    players: players,
    teams: teams,
  );
  final summary = const RosterCompletenessService().analyze(rows);
  final output = File('raw/roster_completeness_report.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      'snapshotLabel': '2025-26 final roster snapshot',
      'totalRows': summary.totalRows,
      'teamsCovered': summary.teamsCovered,
      'identityCompleteRows': summary.identityCompleteRows,
      'fullyPopulatedRows': summary.fullyPopulatedRows,
      'identityCompletionRate': summary.identityCompletionRate,
      'fullCompletionRate': summary.fullCompletionRate,
      'missingFrom': summary.missingFrom,
      'missingJersey': summary.missingJersey,
      'missingSalary': summary.missingSalary,
      'missingPosition': summary.missingPosition,
      'invalidHeight': summary.invalidHeight,
      'invalidWeight': summary.invalidWeight,
      'missingPlayerJoins': summary.missingPlayerJoins,
      'missingTeamJoins': summary.missingTeamJoins,
      'knownPayrollUsd': summary.knownPayrollUsd,
      'teams': [
        for (final team in summary.teams)
          {
            'teamId': team.teamId,
            'teamName': team.teamName,
            'rows': team.rows,
            'identityCompleteRows': team.identityCompleteRows,
            'fullyPopulatedRows': team.fullyPopulatedRows,
            'identityCompletionRate': team.identityCompletionRate,
            'fullCompletionRate': team.fullCompletionRate,
            'issueCount': team.issueCount,
            'knownPayrollUsd': team.knownPayrollUsd,
          },
      ],
      'issues': [
        for (final issue in summary.issues)
          {
            'playerId': issue.playerId,
            'playerName': issue.playerName,
            'teamId': issue.teamId,
            'teamName': issue.teamName,
            'field': issue.field,
            'message': issue.message,
          },
      ],
    })}\n',
  );

  print('Roster completeness report');
  print('Rows: ${summary.totalRows}');
  print('Teams: ${summary.teamsCovered}');
  print('Identity complete: ${summary.identityCompleteRows} (${(summary.identityCompletionRate * 100).toStringAsFixed(1)}%)');
  print('Fully populated: ${summary.fullyPopulatedRows} (${(summary.fullCompletionRate * 100).toStringAsFixed(1)}%)');
  print('Missing From: ${summary.missingFrom}');
  print('Missing jersey: ${summary.missingJersey}');
  print('Missing salary: ${summary.missingSalary}');
  print('Broken joins: ${summary.missingPlayerJoins + summary.missingTeamJoins}');
  print('Written to ${output.path}');
}

List<PlayerProfile> _loadPlayers() {
  final decoded = jsonDecode(File('assets/data/nba/players/player_profiles.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['players'] as List<dynamic>)
      .map((row) => PlayerProfile.fromJson(row as Map<String, dynamic>))
      .toList(growable: false);
}

List<Team> _loadTeams() {
  final decoded = jsonDecode(File('assets/data/nba/teams/teams.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['teams'] as List<dynamic>)
      .map((row) => Team.fromJson(row as Map<String, dynamic>))
      .toList(growable: false);
}

List<RosterEntry> _loadRosters() {
  final decoded = jsonDecode(File('assets/data/nba/rosters/roster_entries.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['rosters'] as List<dynamic>)
      .map((row) => RosterEntry.fromJson(row as Map<String, dynamic>))
      .toList(growable: false);
}
