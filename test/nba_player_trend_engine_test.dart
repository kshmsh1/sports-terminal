import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_trend_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('builds chronological raw and rolling player trend observations', () {
    final result = const NbaPlayerTrendEngine().build(
      _seed(),
      playerId: 'p1',
      playerName: 'Alpha Guard',
      rollingWindow: 3,
    );

    expect(result.observations.map((row) => row.gameId), ['g1', 'g2', 'g3', 'g4']);
    expect(result.observations.map((row) => row.value), [10, 20, 30, 40]);
    expect(result.observations[0].rollingAverage, 10);
    expect(result.observations[1].rollingAverage, 15);
    expect(result.observations[2].rollingAverage, 20);
    expect(result.observations[3].rollingAverage, 30);
    expect(result.average, 25);
    expect(result.availableObservations, 4);
    expect(result.missingObservations, 0);
  });

  test('retains missing metric observations as visible gaps', () {
    final result = const NbaPlayerTrendEngine().build(
      _seed(missingThirdAssists: true),
      playerId: 'p1',
      metric: NbaPlayerTrendMetric.assists,
      rollingWindow: 2,
    );

    expect(result.observations, hasLength(4));
    expect(result.observations[2].value, isNull);
    expect(result.observations[2].rollingSampleSize, 1);
    expect(result.missingObservations, 1);
    expect(result.availableObservations, 3);
  });

  test('keeps regular season and playoffs separated', () {
    final regular = const NbaPlayerTrendEngine().build(
      _seed(includePlayoff: true),
      playerId: 'p1',
      seasonType: 'Regular Season',
    );
    final playoffs = const NbaPlayerTrendEngine().build(
      _seed(includePlayoff: true),
      playerId: 'p1',
      seasonType: 'Playoffs',
    );

    expect(regular.observations.map((row) => row.gameId), ['g1', 'g2', 'g3', 'g4']);
    expect(playoffs.observations.map((row) => row.gameId), ['gp1']);
  });

  test('bounds recent windows without reordering canonical games', () {
    final result = const NbaPlayerTrendEngine().build(
      _seed(),
      playerId: 'p1',
      maxGames: 2,
    );

    expect(result.observations.map((row) => row.gameId), ['g3', 'g4']);
  });

  test('trend label requires two observed five-game comparison windows', () {
    final result = const NbaPlayerTrendEngine().build(
      _seed(),
      playerId: 'p1',
    );

    expect(result.recentFiveAverage, 25);
    expect(result.priorFiveAverage, isNull);
    expect(result.recentDelta, isNull);
    expect(result.trendLabel, 'INSUFFICIENT HISTORY');
  });
}

NbaTerminalSeedSnapshot _seed({
  bool missingThirdAssists = false,
  bool includePlayoff = false,
}) {
  final games = <Map<String, dynamic>>[];
  final logs = <Map<String, dynamic>>[];
  for (var index = 1; index <= 4; index++) {
    games.add({
      'game_id': 'g$index',
      'season_id': '2025-26',
      'game_date': '2026-01-0$index',
      'season_type': 'Regular Season',
      'home_team_id': index.isOdd ? 'AAA' : 'BBB',
      'away_team_id': index.isOdd ? 'BBB' : 'AAA',
      'home_score': index.isOdd ? 100 + index : 90 + index,
      'away_score': index.isOdd ? 90 + index : 100 + index,
      'status': 'Final',
    });
    logs.add({
      'game_id': 'g$index',
      'game_date': '2026-01-0$index',
      'season_type': 'Regular Season',
      'player_id': 'p1',
      'player_name': 'Alpha Guard',
      'team_id': 'AAA',
      'points': index * 10,
      if (!(missingThirdAssists && index == 3)) 'assists': index,
      'rebounds': index + 2,
      'steals': 1,
      'blocks': 0,
      'turnovers': 2,
      'plus_minus': index - 2,
      'source_id': 'box-test',
    });
  }
  if (includePlayoff) {
    games.add({
      'game_id': 'gp1',
      'season_id': '2025-26',
      'game_date': '2026-04-20',
      'season_type': 'Playoffs',
      'home_team_id': 'AAA',
      'away_team_id': 'BBB',
      'home_score': 110,
      'away_score': 105,
      'status': 'Final',
    });
    logs.add({
      'game_id': 'gp1',
      'game_date': '2026-04-20',
      'season_type': 'Playoffs',
      'player_id': 'p1',
      'player_name': 'Alpha Guard',
      'team_id': 'AAA',
      'points': 35,
      'assists': 8,
      'rebounds': 6,
      'source_id': 'box-test',
    });
  }
  return NbaTerminalSeedSnapshot.fromMap({
    'manifest': const {},
    'teams': [
      {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
      {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
    ],
    'players': [
      {'player_id': 'p1', 'player_name': 'Alpha Guard', 'team_id': 'AAA'},
    ],
    'games': games,
    'team_records': const [],
    'team_game_logs': const [],
    'player_season_totals': const [],
    'player_leaders': const {},
    'player_game_highs': const {},
    'player_game_logs_top': logs,
    'search_index': const [],
    'data_dictionary': const {},
    'validation_report': {'status': 'pass'},
    'release_manifest': {'status': 'test'},
    'standings': const [],
    'launch_config': {'supportedSeason': '2025-26', 'datasetStatus': 'test'},
    'asset_path': 'test://player-trends',
    'used_fallback': false,
  });
}
