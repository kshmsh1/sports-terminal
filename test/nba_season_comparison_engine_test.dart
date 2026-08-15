import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_season_comparison_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('compares only teams present in both explicitly selected seasons', () {
    final result = const NbaSeasonComparisonEngine().build(
      leftSeed: _seed('2024-25', const [
        ('AAA', 'BBB', 100, 90),
        ('CCC', 'AAA', 95, 105),
      ]),
      leftSeasonId: '2024-25',
      rightSeed: _seed('2025-26', const [
        ('AAA', 'BBB', 120, 100),
        ('DDD', 'AAA', 108, 112),
      ]),
      rightSeasonId: '2025-26',
    );

    expect(result.commonTeams.map((row) => row.teamId).toSet(), {'AAA', 'BBB'});
    expect(result.onlyLeftTeams.map((row) => row.teamId), ['CCC']);
    expect(result.onlyRightTeams.map((row) => row.teamId), ['DDD']);
    expect(result.leftSeasonId, '2024-25');
    expect(result.rightSeasonId, '2025-26');
  });

  test('team deltas use scored-game-derived records rather than seed records', () {
    final result = const NbaSeasonComparisonEngine().build(
      leftSeed: _seed('2024-25', const [('AAA', 'BBB', 100, 90)]),
      leftSeasonId: '2024-25',
      rightSeed: _seed('2025-26', const [
        ('AAA', 'BBB', 90, 100),
        ('AAA', 'BBB', 120, 100),
      ]),
      rightSeasonId: '2025-26',
    );
    final alpha = result.commonTeams.firstWhere((row) => row.teamId == 'AAA');

    expect(alpha.leftWinPct, 1);
    expect(alpha.rightWinPct, .5);
    expect(alpha.winPctDelta, -.5);
    expect(alpha.leftDifferential, 10);
    expect(alpha.rightDifferential, 5);
    expect(alpha.differentialDelta, -5);
  });

  test('scheduled games stay in coverage but never change comparison performance', () {
    final right = _seed(
      '2025-26',
      const [('AAA', 'BBB', 110, 100)],
      includeScheduled: true,
    );
    final result = const NbaSeasonComparisonEngine().build(
      leftSeed: _seed('2024-25', const [('AAA', 'BBB', 105, 100)]),
      leftSeasonId: '2024-25',
      rightSeed: right,
      rightSeasonId: '2025-26',
    );

    expect(result.right.completedGames, 1);
    expect(result.right.scheduledGames, 1);
    final alpha = result.commonTeams.firstWhere((row) => row.teamId == 'AAA');
    expect(alpha.rightGames, 1);
    expect(alpha.rightWinPct, 1);
  });

  test('requested season id prevents other-season leakage inside either seed', () {
    final left = _seed('2024-25', const [('AAA', 'BBB', 100, 90)],
        extraSeason: '1999-00');
    final right = _seed('2025-26', const [('AAA', 'BBB', 90, 100)],
        extraSeason: '2000-01');
    final result = const NbaSeasonComparisonEngine().build(
      leftSeed: left,
      leftSeasonId: '2024-25',
      rightSeed: right,
      rightSeasonId: '2025-26',
    );

    expect(result.left.completedGames, 1);
    expect(result.right.completedGames, 1);
  });
}

NbaTerminalSeedSnapshot _seed(
  String seasonId,
  List<(String, String, int, int)> scored, {
  bool includeScheduled = false,
  String extraSeason = '',
}) {
  final games = <Map<String, dynamic>>[];
  for (var index = 0; index < scored.length; index++) {
    final row = scored[index];
    games.add({
      'game_id': '$seasonId-g$index',
      'season_id': seasonId,
      'game_date': '2026-01-${(index + 1).toString().padLeft(2, '0')}',
      'season_type': 'Regular Season',
      'home_team_id': row.$1,
      'away_team_id': row.$2,
      'home_score': row.$3,
      'away_score': row.$4,
      'status': 'Final',
    });
  }
  if (includeScheduled) {
    games.add({
      'game_id': '$seasonId-scheduled',
      'season_id': seasonId,
      'game_date': '2026-02-01',
      'season_type': 'Regular Season',
      'home_team_id': 'AAA',
      'away_team_id': 'BBB',
      'status': 'Scheduled',
    });
  }
  if (extraSeason.isNotEmpty) {
    games.add({
      'game_id': 'extra',
      'season_id': extraSeason,
      'game_date': '2000-01-01',
      'season_type': 'Regular Season',
      'home_team_id': 'AAA',
      'away_team_id': 'BBB',
      'home_score': 200,
      'away_score': 50,
      'status': 'Final',
    });
  }
  return NbaTerminalSeedSnapshot.fromMap({
    'manifest': const {},
    'teams': const [
      {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
      {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
      {'team_id': 'CCC', 'team_name': 'Gamma', 'abbreviation': 'CCC'},
      {'team_id': 'DDD', 'team_name': 'Delta', 'abbreviation': 'DDD'},
    ],
    'players': const [],
    'games': games,
    'team_records': const [],
    'team_game_logs': const [],
    'player_season_totals': const [],
    'player_leaders': const {},
    'player_game_highs': const {},
    'player_game_logs_top': const [],
    'search_index': const [],
    'data_dictionary': const {},
    'validation_report': {'status': 'pass'},
    'release_manifest': {'status': 'test'},
    'standings': const [],
    'launch_config': {'supportedSeason': seasonId, 'datasetStatus': 'test'},
    'asset_path': 'test://$seasonId',
    'used_fallback': false,
  });
}
