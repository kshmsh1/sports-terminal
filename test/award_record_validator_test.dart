import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/award_record.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/award_record_validator.dart';

void main() {
  const players = [PlayerProfile(id: 'nba-2544', displayName: 'LeBron James', sourceId: 'source', asOf: '2026-06-05')];
  const teams = [Team(id: 'lal', name: 'Lakers', abbreviation: 'LAL', city: 'Los Angeles', conference: 'West', division: 'Pacific')];
  const seasons = [Season(id: 'season-2025', label: '2024-25', startYear: 2024, endYear: 2025, league: 'NBA')];

  group('AwardRecordValidator', () {
    test('passes clean player award rows', () {
      final summary = const AwardRecordValidator().validate(
        players: players,
        teams: teams,
        seasons: seasons,
        awards: const [
          AwardRecord(id: 'mvp-2025-1', awardName: 'Most Valuable Player', seasonId: 'season-2025', playerId: 'nba-2544', rank: 1, votesFirstPlace: 80, points: 900, share: 0.92, sourceId: 'source', asOf: '2026-06-05'),
        ],
      );

      expect(summary.blockers, 0);
      expect(summary.canConnect, isTrue);
    });

    test('blocks missing joins and source metadata', () {
      final summary = const AwardRecordValidator().validate(
        players: players,
        teams: teams,
        seasons: seasons,
        awards: const [
          AwardRecord(id: 'bad-row', awardName: 'Most Valuable Player', seasonId: 'season-1900', playerId: 'missing-player', teamId: 'missing-team'),
        ],
      );

      expect(summary.issues.where((issue) => issue.code == 'season-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'player-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'team-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-source-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-as-of'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });

    test('blocks duplicate rows, negative values, and invalid ranks', () {
      final summary = const AwardRecordValidator().validate(
        players: players,
        teams: teams,
        seasons: seasons,
        awards: const [
          AwardRecord(id: 'dup-row', awardName: 'Most Valuable Player', seasonId: 'season-2025', playerId: 'nba-2544', rank: 0, points: -1, sourceId: 'source', asOf: '2026-06-05'),
          AwardRecord(id: 'dup-row', awardName: 'Most Valuable Player', seasonId: 'season-2025', playerId: 'nba-2544', rank: 0, points: -1, sourceId: 'source', asOf: '2026-06-05'),
        ],
      );

      expect(summary.issues.where((issue) => issue.code == 'duplicate-row-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'duplicate-natural-key'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'rank-range'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'negative-points'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });
  });
}
