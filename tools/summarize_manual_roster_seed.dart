import 'dart:convert';
import 'dart:io';

void main() {
  final reportFile = File('raw/manual_roster_seed_report.json');
  if (!reportFile.existsSync()) {
    throw StateError('Manual roster seed report not found. Run tools/apply_manual_roster_seed.dart first.');
  }

  final report = jsonDecode(reportFile.readAsStringSync()) as Map<String, dynamic>;
  final teamsFile = File('assets/data/nba/teams/teams.json');
  final teamsJson = jsonDecode(teamsFile.readAsStringSync()) as Map<String, dynamic>;
  final canonicalTeamIds = (teamsJson['teams'] as List<dynamic>).map((row) => (row as Map<String, dynamic>)['id'] as String).toSet();
  final importedTeams = ((report['teams'] as List<dynamic>? ?? const [])).map((row) => (row as Map<String, dynamic>)['teamId'] as String).toSet();
  final missing = canonicalTeamIds.difference(importedTeams).toList()..sort();
  final duplicateRows = report['skippedDuplicatePlayerRows'] as List<dynamic>? ?? const [];

  print('Manual roster seed coverage');
  print('Snapshot: ${report['snapshotLabel'] ?? '2025-26 final roster snapshot'}');
  print('Teams imported: ${report['teamCount']} / ${canonicalTeamIds.length}');
  print('Player rows: ${report['playerRows']}');
  print('Roster rows: ${report['rosterRows']}');
  print('Seed files: ${(report['seedFiles'] as List<dynamic>? ?? const []).length}');
  print('Skipped duplicate player rows: ${duplicateRows.length}');

  if (missing.isEmpty) {
    print('All canonical NBA teams have manual roster rows.');
  } else {
    print('Missing team IDs: ${missing.join(', ')}');
    if (Platform.environment['ALLOW_PARTIAL_ROSTER_SEED'] != '1') {
      throw StateError('Manual roster seed coverage is incomplete. Missing ${missing.length} NBA teams.');
    }
  }
}
