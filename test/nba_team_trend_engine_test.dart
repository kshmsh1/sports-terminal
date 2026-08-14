import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_team_trend_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('builds chronological team differential and rolling trend', () {
    final result = const NbaTeamTrendEngine().build(
      _seed(),
      teamId: 'AAA',
      rollingWindow: 3,
    );

    expect(result.observations.map((row) => row.gameId), ['g1', 'g2', 'g3', 'g4']);
    expect(result.observations.map((row) => row.value), [10, -5, 20, 5]);
    expect(result.observations[0].rollingAverage, 10);
    expect(result.observations[1].rollingAverage, 2.5);
    expect(result.observations[2].rollingAverage, closeTo(25 / 3, 0.0001));
    expect(result.observations[3].rollingAverage, closeTo(20 / 3, 0.0001));
    expect(result.average, 7.5);
    expect(result.recentRecord, '3-1');
    expect(result.currentStreak, 'W2');
    expect(result.recentAverageDifferential, 7.5);
  });

  test('switches between points for and points against without changing games', () {
    final scored = const NbaTeamTrendEngine().build(
      _seed(),
      teamId: 'AAA',
      metric: NbaTeamTrendMetric.pointsFor,
    );
    final allowed = const NbaTeamTrendEngine().build(
      _seed(),
      teamId: 'AAA',
      metric: NbaTeamTrendMetric.pointsAgainst,
    );

    expect(scored.observations.map((row) => row.value), [110, 95, 120, 105]);
    expect(allowed.observations.map((row) => row.value), [100, 100, 100, 100]);
    expect(scored.observations.map((row) => row.gameId),
        allowed.observations.map((row) => row.gameId));
  });

  test('excludes unscored future games from performance trends', () {
    final result = const NbaTeamTrendEngine().build(
      _seed(includeFuture: true),
      teamId: 'AAA',
    );

    expect(result.completedGames, 4);
    expect(result.observations.map((row) => row.gameId), isNot(contains('g5')));
  });

  test('keeps playoffs separate from regular season', () {
    final regular = const NbaTeamTrendEngine().build(
      _seed(includePlayoff: true),
      teamId: 'AAA',
      seasonType: 'Regular Season',
    );
    final playoffs = const NbaTeamTrendEngine().build(
      _seed(includePlayoff: true),
      teamId: 'AAA',
      seasonType: 'Playoffs',
    );

    expect(regular.completedGames, 4);
    expect(playoffs.observations.map((row) => row.gameId), ['gp1']);
  });

  test('bounds the trend window to the most recent canonical games', () {
    final result = const NbaTeamTrendEngine().build(
      _seed(),
      teamId: 'AAA',
      maxGames: 2,
    );

    expect(result.observations.map((row) => row.gameId), ['g3', 'g4']);
    expect(result.currentStreak, 'W2');
  });
}

NbaTerminalSeedSnapshot _seed({
  bool includeFuture = false,
  bool includePlayoff = false,
}) {
  final games = <Map<String, dynamic>>[
    {
      'game_id': 'g1', 'season_id': '2025-26', 'game_date': '2026-01-01',
      'season_type': 'Regular Season', 'home_team_id': 'AAA', 'away_team_id': 'BBB',
      'home_score': 110, 'away_score': 100, 'status': 'Final',
    },
    {
      'game_id': 'g2', 'season_id': '2025-26', 'game_date': '2026-01-02',
      'season_type': 'Regular Season', 'home_team_id': 'BBB', 'away_team_id': 'AAA',
      'home_score': 100, 'away_score': 95, 'status': 'Final',
    },
    {
      'game_id': 'g3', 'season_id': '2025-26', 'game_date': '2026-01-03',
      'season_type': 'Regular Season', 'home_team_id': 'AAA', 'away_team_id': 'BBB',
      'home_score': 120, 'away_score': 100, 'status': 'Final',
    },
    {
      'game_id': 'g4', 'season_id': '2025-26', 'game_date': '2026-01-04',
      'season_type': 'Regular Season', 'home_team_id': 'BBB', 'away_team_id': 'AAA',
      'home_score': 100, 'away_score': 105, 'status': 'Final',
    },
  ];
  if (includeFuture) {
    games.add({
      'game_id': 'g5', 'season_id': '2025-26', 'game_date': '2026-02-01',
      'season_type': 'Regular Season', 'home_team_id': 'AAA', 'away_team_id': 'BBB',
      'status': 'Scheduled',
    });
  }
  if (includePlayoff) {
    games.add({
      'game_id': 'gp1', 'season_id': '2025-26', 'game_date': '2026-04-20',
      'season_type': 'Playoffs', 'home_team_id': 'AAA', 'away_team_id': 'BBB',
      'home_score': 112, 'away_score': 108, 'status': 'Final',
    });
  }
  return NbaTerminalSeedSnapshot.fromMap({
    'manifest': const {},
    'teams': [
      {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
      {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
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
    'launch_config': {'supportedSeason': '2025-26', 'datasetStatus': 'test'},
    'asset_path': 'test://team-trends',
    'used_fallback': false,
  });
}
