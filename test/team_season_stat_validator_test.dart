import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/models/team_season_stat.dart';
import 'package:sports_terminal/services/team_season_stat_validator.dart';

void main() {
  const teams = [Team(id: 'bos', name: 'Celtics', abbreviation: 'BOS', city: 'Boston', conference: 'East', division: 'Atlantic')];
  const seasons = [Season(id: 'season-2025', label: '2024-25', startYear: 2024, endYear: 2025, league: 'NBA')];

  group('TeamSeasonStatValidator', () {
    test('passes clean joined rows', () {
      final summary = const TeamSeasonStatValidator().validate(
        teams: teams,
        seasons: seasons,
        stats: const [
          TeamSeasonStat(id: 'bos-2025-regular', teamId: 'bos', seasonId: 'season-2025', seasonType: 'Regular Season', wins: 61, losses: 21, winPercentage: 0.744, pointsPerGame: 116.3, fieldGoalPercentage: 0.48, sourceId: 'source', asOf: '2026-06-05'),
        ],
      );

      expect(summary.blockers, 0);
      expect(summary.canConnect, isTrue);
    });

    test('blocks missing team and season joins', () {
      final summary = const TeamSeasonStatValidator().validate(
        teams: teams,
        seasons: seasons,
        stats: const [
          TeamSeasonStat(id: 'bad-row', teamId: 'missing-team', seasonId: 'season-1900', sourceId: 'source', asOf: '2026-06-05'),
        ],
      );

      expect(summary.issues.where((issue) => issue.code == 'team-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'season-join-missing'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });

    test('blocks missing source metadata', () {
      final summary = const TeamSeasonStatValidator().validate(
        teams: teams,
        seasons: seasons,
        stats: const [
          TeamSeasonStat(id: 'bad-row', teamId: 'bos', seasonId: 'season-2025'),
        ],
      );

      expect(summary.issues.where((issue) => issue.code == 'missing-source-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-as-of'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });

    test('blocks duplicate row IDs and duplicate natural keys', () {
      final summary = const TeamSeasonStatValidator().validate(
        teams: teams,
        seasons: seasons,
        stats: const [
          TeamSeasonStat(id: 'dup-row', teamId: 'bos', seasonId: 'season-2025', seasonType: 'Regular Season', sourceId: 'source', asOf: '2026-06-05'),
          TeamSeasonStat(id: 'dup-row', teamId: 'bos', seasonId: 'season-2025', seasonType: 'Regular Season', sourceId: 'source', asOf: '2026-06-05'),
        ],
      );

      expect(summary.issues.where((issue) => issue.code == 'duplicate-row-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'duplicate-natural-key'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });

    test('blocks negative values and warns on odd percentages', () {
      final summary = const TeamSeasonStatValidator().validate(
        teams: teams,
        seasons: seasons,
        stats: const [
          TeamSeasonStat(id: 'bad-values', teamId: 'bos', seasonId: 'season-2025', seasonType: 'Regular Season', wins: -1, winPercentage: 2.0, sourceId: 'source', asOf: '2026-06-05'),
        ],
      );

      expect(summary.issues.where((issue) => issue.code == 'negative-wins'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'percent-range-winPercentage'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });
  });
}
