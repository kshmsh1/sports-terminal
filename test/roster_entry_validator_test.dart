import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/roster_entry.dart';
import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/roster_entry_validator.dart';

void main() {
  const players = [PlayerProfile(id: 'nba-2544', displayName: 'LeBron James', sourceId: 'source', asOf: '2026-06-05')];
  const teams = [Team(id: 'lal', name: 'Lakers', abbreviation: 'LAL', city: 'Los Angeles', conference: 'West', division: 'Pacific')];
  const seasons = [Season(id: 'season-2025', label: '2024-25', startYear: 2024, endYear: 2025, league: 'NBA')];

  group('RosterEntryValidator', () {
    test('passes clean joined rows', () {
      final summary = const RosterEntryValidator().validate(
        players: players,
        teams: teams,
        seasons: seasons,
        rosters: const [RosterEntry(playerId: 'nba-2544', teamId: 'lal', seasonId: 'season-2025', rosterStatus: 'Active', sourceId: 'source', asOf: '2026-06-05')],
      );
      expect(summary.blockers, 0);
      expect(summary.canConnect, isTrue);
    });

    test('blocks missing joins and source metadata', () {
      final summary = const RosterEntryValidator().validate(
        players: players,
        teams: teams,
        seasons: seasons,
        rosters: const [RosterEntry(playerId: 'missing-player', teamId: 'missing-team', seasonId: 'season-1900')],
      );
      expect(summary.issues.where((issue) => issue.code == 'player-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'team-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'season-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-source-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-as-of'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });

    test('blocks duplicate natural keys and warns on date order', () {
      final summary = const RosterEntryValidator().validate(
        players: players,
        teams: teams,
        seasons: seasons,
        rosters: const [
          RosterEntry(playerId: 'nba-2544', teamId: 'lal', seasonId: 'season-2025', startDate: '2025-02-01', endDate: '2025-01-01', sourceId: 'source', asOf: '2026-06-05'),
          RosterEntry(playerId: 'nba-2544', teamId: 'lal', seasonId: 'season-2025', startDate: '2025-02-01', endDate: '2025-01-01', sourceId: 'source', asOf: '2026-06-05'),
        ],
      );
      expect(summary.issues.where((issue) => issue.code == 'duplicate-natural-key'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'date-window-order'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });
  });
}
