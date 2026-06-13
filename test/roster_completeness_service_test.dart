import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/roster_entry.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/roster_completeness_service.dart';
import 'package:sports_terminal/services/roster_directory_service.dart';

void main() {
  const player = PlayerProfile(
    id: 'player-1',
    displayName: 'Complete Player',
    height: '6\' 6"',
    weightPounds: 210,
  );
  const team = Team(
    id: 'team-1',
    name: 'Complete Team',
    abbreviation: 'CMP',
    city: 'Complete City',
    conference: 'East',
    division: 'Atlantic',
  );

  test('counts complete rows and known payroll', () {
    final rows = const RosterDirectoryService().join(
      players: const [player],
      teams: const [team],
      rosters: const [
        RosterEntry(
          playerId: 'player-1',
          teamId: 'team-1',
          seasonId: '2025-26',
          jerseyNumber: '1',
          position: 'SG',
          age: 25,
          height: '6\' 6"',
          weightPounds: 210,
          from: 'Complete University',
          salaryUsd: 10000000,
        ),
      ],
    );

    final summary = const RosterCompletenessService().analyze(rows);

    expect(summary.totalRows, 1);
    expect(summary.teamsCovered, 1);
    expect(summary.identityCompleteRows, 1);
    expect(summary.fullyPopulatedRows, 1);
    expect(summary.identityIssueCount, 0);
    expect(summary.knownPayrollUsd, 10000000);
    expect(summary.issues, isEmpty);
  });

  test('surfaces missing fields without hiding connected rows', () {
    final rows = const RosterDirectoryService().join(
      players: const [player],
      teams: const [team],
      rosters: const [
        RosterEntry(
          playerId: 'player-1',
          teamId: 'team-1',
          seasonId: '2025-26',
          position: 'SG',
          age: 25,
          height: '6\' 6"',
          weightPounds: 210,
        ),
      ],
    );

    final summary = const RosterCompletenessService().analyze(rows);

    expect(summary.totalRows, 1);
    expect(summary.identityCompleteRows, 0);
    expect(summary.missingJersey, 1);
    expect(summary.missingFrom, 1);
    expect(summary.missingSalary, 1);
    expect(summary.issues.map((issue) => issue.field), containsAll(['Jersey', 'From', 'Salary']));
    expect(summary.teams.single.issueCount, 3);
  });

  test('reports missing player and team joins', () {
    final rows = const RosterDirectoryService().join(
      players: const [],
      teams: const [],
      rosters: const [
        RosterEntry(
          playerId: 'missing-player',
          teamId: 'missing-team',
          seasonId: '2025-26',
          jerseyNumber: '9',
          position: 'PG',
          age: 24,
          height: '6\' 2"',
          weightPounds: 185,
          from: 'Test University',
          salaryUsd: 1000000,
        ),
      ],
    );

    final summary = const RosterCompletenessService().analyze(rows);

    expect(summary.missingPlayerJoins, 1);
    expect(summary.missingTeamJoins, 1);
    expect(summary.identityIssueCount, 2);
  });
}
