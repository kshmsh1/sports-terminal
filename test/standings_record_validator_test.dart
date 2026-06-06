import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/standings_record.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/standings_record_validator.dart';

void main() {
  const teams = [Team(id: 'bos', name: 'Celtics', abbreviation: 'BOS', city: 'Boston', conference: 'East', division: 'Atlantic')];
  const seasons = [Season(id: 'season-2025', label: '2024-25', startYear: 2024, endYear: 2025, league: 'NBA')];

  group('StandingsRecordValidator', () {
    test('passes clean joined rows', () {
      final summary = const StandingsRecordValidator().validate(
        teams: teams,
        seasons: seasons,
        standings: const [
          StandingsRecord(id: 'bos-2025-east', teamId: 'bos', seasonId: 'season-2025', conference: 'East', seed: 1, wins: 61, losses: 21, winPercentage: 0.744, gamesBack: 0, sourceId: 'source', asOf: '2026-06-05'),
        ],
      );

      expect(summary.blockers, 0);
      expect(summary.canConnect, isTrue);
    });

    test('blocks missing joins and source metadata', () {
      final summary = const StandingsRecordValidator().validate(
        teams: teams,
        seasons: seasons,
        standings: const [
          StandingsRecord(id: 'bad-row', teamId: 'missing-team', seasonId: 'season-1900'),
        ],
      );

      expect(summary.issues.where((issue) => issue.code == 'team-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'season-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-source-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-as-of'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });

    test('blocks duplicates and negative values', () {
      final summary = const StandingsRecordValidator().validate(
        teams: teams,
        seasons: seasons,
        standings: const [
          StandingsRecord(id: 'dup-row', teamId: 'bos', seasonId: 'season-2025', conference: 'East', wins: -1, sourceId: 'source', asOf: '2026-06-05'),
          StandingsRecord(id: 'dup-row', teamId: 'bos', seasonId: 'season-2025', conference: 'East', sourceId: 'source', asOf: '2026-06-05'),
        ],
      );

      expect(summary.issues.where((issue) => issue.code == 'duplicate-row-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'duplicate-natural-key'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'negative-wins'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });
  });
}
