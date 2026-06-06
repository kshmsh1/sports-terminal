import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/player_season_stat.dart';
import 'package:sports_terminal/models/season.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/services/player_season_stat_validator.dart';

void main() {
  const players = [PlayerProfile(id: 'nba-2544', displayName: 'LeBron James', sourceId: 'source', asOf: '2026-06-05')];
  const seasons = [Season(id: 'season-2025', label: '2024-25', league: 'NBA', startYear: 2024, endYear: 2025)];
  const teams = [Team(id: 'lal', abbreviation: 'LAL', city: 'Los Angeles', name: 'Lakers', conference: 'West', division: 'Pacific')];

  group('PlayerSeasonStatValidator', () {
    test('passes clean joined rows', () {
      final summary = const PlayerSeasonStatValidator().validate(
        players: players,
        seasons: seasons,
        teams: teams,
        stats: const [
          PlayerSeasonStat(id: 'nba-2544-2025-lal-regular', playerId: 'nba-2544', seasonId: 'season-2025', teamId: 'lal', seasonType: 'Regular Season', gamesPlayed: 70, pointsPerGame: 24.4, fieldGoalPercentage: 0.51, sourceId: 'source', asOf: '2026-06-05'),
        ],
      );

      expect(summary.blockers, 0);
      expect(summary.canConnect, isTrue);
    });

    test('blocks missing player joins and source metadata', () {
      final summary = const PlayerSeasonStatValidator().validate(
        players: players,
        seasons: seasons,
        teams: teams,
        stats: const [
          PlayerSeasonStat(id: 'bad-row', playerId: 'missing-player', seasonId: 'season-2025', teamId: 'lal'),
        ],
      );

      expect(summary.issues.where((issue) => issue.code == 'player-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-source-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-as-of'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });

    test('blocks missing season and team joins', () {
      final summary = const PlayerSeasonStatValidator().validate(
        players: players,
        seasons: seasons,
        teams: teams,
        stats: const [
          PlayerSeasonStat(id: 'bad-row', playerId: 'nba-2544', seasonId: 'season-1900', teamId: 'missing-team', sourceId: 'source', asOf: '2026-06-05'),
        ],
      );

      expect(summary.issues.where((issue) => issue.code == 'season-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'team-join-missing'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });

    test('blocks duplicate row IDs and duplicate natural keys', () {
      final summary = const PlayerSeasonStatValidator().validate(
        players: players,
        seasons: seasons,
        teams: teams,
        stats: const [
          PlayerSeasonStat(id: 'dup-row', playerId: 'nba-2544', seasonId: 'season-2025', teamId: 'lal', seasonType: 'Regular Season', sourceId: 'source', asOf: '2026-06-05'),
          PlayerSeasonStat(id: 'dup-row', playerId: 'nba-2544', seasonId: 'season-2025', teamId: 'lal', seasonType: 'Regular Season', sourceId: 'source', asOf: '2026-06-05'),
        ],
      );

      expect(summary.issues.where((issue) => issue.code == 'duplicate-row-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'duplicate-natural-key'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });

    test('blocks negative stats and warns on out-of-range percentages', () {
      final summary = const PlayerSeasonStatValidator().validate(
        players: players,
        seasons: seasons,
        teams: teams,
        stats: const [
          PlayerSeasonStat(id: 'bad-values', playerId: 'nba-2544', seasonId: 'season-2025', teamId: 'lal', seasonType: 'Regular Season', gamesPlayed: -1, fieldGoalPercentage: 2.1, sourceId: 'source', asOf: '2026-06-05'),
        ],
      );

      expect(summary.issues.where((issue) => issue.code == 'negative-gamesPlayed'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'percent-range-fieldGoalPercentage'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });
  });
}
