import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/playoff_series_record.dart';
import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/playoff_series_validator.dart';

void main() {
  const teams = [
    Team(id: 'bos', name: 'Celtics', abbreviation: 'BOS', city: 'Boston', conference: 'East', division: 'Atlantic'),
    Team(id: 'nyk', name: 'Knicks', abbreviation: 'NYK', city: 'New York', conference: 'East', division: 'Atlantic'),
  ];
  const seasons = [Season(id: 'season-2025', label: '2024-25', startYear: 2024, endYear: 2025, league: 'NBA')];

  group('PlayoffSeriesValidator', () {
    test('passes clean joined rows', () {
      final summary = const PlayoffSeriesValidator().validate(
        teams: teams,
        seasons: seasons,
        series: const [
          PlayoffSeriesRecord(id: 'bos-nyk-2025-ecf', seasonId: 'season-2025', round: 'Conference Finals', winningTeamId: 'bos', losingTeamId: 'nyk', gamesPlayed: 6, winnerWins: 4, loserWins: 2, sourceId: 'source', asOf: '2026-06-05'),
        ],
      );

      expect(summary.blockers, 0);
      expect(summary.canConnect, isTrue);
    });

    test('blocks missing joins and source metadata', () {
      final summary = const PlayoffSeriesValidator().validate(
        teams: teams,
        seasons: seasons,
        series: const [
          PlayoffSeriesRecord(id: 'bad-row', seasonId: 'season-1900', winningTeamId: 'missing-team', losingTeamId: 'also-missing'),
        ],
      );

      expect(summary.issues.where((issue) => issue.code == 'season-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'winning-team-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'losing-team-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-source-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-as-of'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });

    test('blocks duplicate rows and same-team series', () {
      final summary = const PlayoffSeriesValidator().validate(
        teams: teams,
        seasons: seasons,
        series: const [
          PlayoffSeriesRecord(id: 'dup-row', seasonId: 'season-2025', round: 'Finals', winningTeamId: 'bos', losingTeamId: 'bos', sourceId: 'source', asOf: '2026-06-05'),
          PlayoffSeriesRecord(id: 'dup-row', seasonId: 'season-2025', round: 'Finals', winningTeamId: 'bos', losingTeamId: 'bos', sourceId: 'source', asOf: '2026-06-05'),
        ],
      );

      expect(summary.issues.where((issue) => issue.code == 'duplicate-row-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'duplicate-natural-key'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'same-team-series'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });
  });
}
