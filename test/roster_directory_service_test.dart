import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/roster_entry.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/roster_directory_service.dart';

void main() {
  test('joins roster rows to player and team references', () {
    const players = [
      PlayerProfile(
        id: 'player-1',
        displayName: 'Test Player',
        primaryTeamAbbreviation: 'TST',
      ),
    ];
    const teams = [
      Team(
        id: 'test-team',
        name: 'Test Team',
        abbreviation: 'TST',
        city: 'Test City',
        conference: 'East',
        division: 'Atlantic',
      ),
    ];
    const rosters = [
      RosterEntry(
        playerId: 'player-1',
        teamId: 'test-team',
        seasonId: '2025-26',
        position: 'PG',
        college: 'Test University',
      ),
    ];

    final rows = const RosterDirectoryService().join(
      rosters: rosters,
      players: players,
      teams: teams,
    );

    expect(rows, hasLength(1));
    expect(rows.single.playerName, 'Test Player');
    expect(rows.single.teamName, 'Test Team');
    expect(rows.single.position, 'PG');
    expect(rows.single.from, 'Test University');
  });

  test('preserves missing joins for visible quality reporting', () {
    const rosters = [
      RosterEntry(
        playerId: 'missing-player',
        teamId: 'missing-team',
        seasonId: '2025-26',
      ),
    ];

    final rows = const RosterDirectoryService().join(
      rosters: rosters,
      players: const [],
      teams: const [],
    );

    expect(rows.single.player, isNull);
    expect(rows.single.team, isNull);
    expect(rows.single.playerName, 'missing-player');
    expect(rows.single.teamName, 'missing-team');
  });
}
