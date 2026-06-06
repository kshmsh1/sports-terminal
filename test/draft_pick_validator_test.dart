import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/draft_pick.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/draft_pick_validator.dart';

void main() {
  const players = [PlayerProfile(id: 'nba-2544', displayName: 'LeBron James', sourceId: 'source', asOf: '2026-06-05')];
  const teams = [Team(id: 'cle', name: 'Cavaliers', abbreviation: 'CLE', city: 'Cleveland', conference: 'East', division: 'Central')];

  group('DraftPickValidator', () {
    test('passes clean joined rows', () {
      final summary = const DraftPickValidator().validate(
        players: players,
        teams: teams,
        picks: const [DraftPick(id: 'draft-2003-1', draftYear: 2003, round: 1, pickNumber: 1, teamId: 'cle', playerId: 'nba-2544', playerName: 'LeBron James', sourceId: 'source', asOf: '2026-06-05')],
      );
      expect(summary.blockers, 0);
      expect(summary.canConnect, isTrue);
    });

    test('blocks missing joins and source metadata', () {
      final summary = const DraftPickValidator().validate(
        players: players,
        teams: teams,
        picks: const [DraftPick(id: 'bad-pick', draftYear: 2003, teamId: 'missing-team', playerId: 'missing-player')],
      );
      expect(summary.issues.where((issue) => issue.code == 'team-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'player-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-source-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-as-of'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });

    test('blocks duplicates and invalid pick numbers', () {
      final summary = const DraftPickValidator().validate(
        players: players,
        teams: teams,
        picks: const [
          DraftPick(id: 'dup-pick', draftYear: 2003, round: 0, pickNumber: 0, teamId: 'cle', sourceId: 'source', asOf: '2026-06-05'),
          DraftPick(id: 'dup-pick', draftYear: 2003, round: 0, pickNumber: 0, teamId: 'cle', sourceId: 'source', asOf: '2026-06-05'),
        ],
      );
      expect(summary.issues.where((issue) => issue.code == 'duplicate-row-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'duplicate-natural-key'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'round-range'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'pick-range'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });
  });
}
