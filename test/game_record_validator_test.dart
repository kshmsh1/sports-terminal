import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/game_record.dart';
import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/game_record_validator.dart';

void main() {
  const teams = [
    Team(id: 'bos', name: 'Celtics', abbreviation: 'BOS', city: 'Boston', conference: 'East', division: 'Atlantic'),
    Team(id: 'lal', name: 'Lakers', abbreviation: 'LAL', city: 'Los Angeles', conference: 'West', division: 'Pacific'),
  ];
  const seasons = [Season(id: 'season-2025', label: '2024-25', startYear: 2024, endYear: 2025, league: 'NBA')];

  group('GameRecordValidator', () {
    test('passes clean joined rows', () {
      final summary = const GameRecordValidator().validate(
        teams: teams,
        seasons: seasons,
        games: const [
          GameRecord(id: 'game-1', seasonId: 'season-2025', gameDate: '2025-01-01', homeTeamId: 'bos', awayTeamId: 'lal', homeScore: 110, awayScore: 104, sourceId: 'source', asOf: '2026-06-05'),
        ],
      );
      expect(summary.blockers, 0);
      expect(summary.canConnect, isTrue);
    });

    test('blocks missing joins and source metadata', () {
      final summary = const GameRecordValidator().validate(
        teams: teams,
        seasons: seasons,
        games: const [GameRecord(id: 'bad-game', seasonId: 'season-1900', homeTeamId: 'missing-home', awayTeamId: 'missing-away')],
      );
      expect(summary.issues.where((issue) => issue.code == 'season-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'home-team-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'away-team-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-source-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-as-of'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });

    test('blocks duplicate games, same-team games, and negative scores', () {
      final summary = const GameRecordValidator().validate(
        teams: teams,
        seasons: seasons,
        games: const [
          GameRecord(id: 'dup-game', seasonId: 'season-2025', gameDate: '2025-01-01', homeTeamId: 'bos', awayTeamId: 'bos', homeScore: -1, sourceId: 'source', asOf: '2026-06-05'),
          GameRecord(id: 'dup-game', seasonId: 'season-2025', gameDate: '2025-01-01', homeTeamId: 'bos', awayTeamId: 'bos', sourceId: 'source', asOf: '2026-06-05'),
        ],
      );
      expect(summary.issues.where((issue) => issue.code == 'duplicate-row-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'duplicate-natural-key'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'same-team-game'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'negative-homeScore'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });
  });
}
