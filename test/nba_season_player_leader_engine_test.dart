import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_season_player_leader_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('ranks canonical season leaders without cross-season leakage', () {
    final result = const NbaSeasonPlayerLeaderEngine().build(
      _seed(),
      seasonId: '2025-26',
      metric: NbaSeasonLeaderMetric.points,
    );

    expect(result.leaders.map((row) => row.playerId), ['p2', 'p1']);
    expect(result.leaders.first.value, 30);
    expect(result.eligiblePlayers, 2);
    expect(result.leaders.map((row) => row.playerId), isNot(contains('old')));
  });

  test('keeps regular season and playoffs isolated', () {
    final regular = const NbaSeasonPlayerLeaderEngine().build(
      _seed(),
      seasonId: '2025-26',
      seasonType: 'Regular Season',
      metric: NbaSeasonLeaderMetric.rebounds,
    );
    final playoffs = const NbaSeasonPlayerLeaderEngine().build(
      _seed(),
      seasonId: '2025-26',
      seasonType: 'Playoffs',
      metric: NbaSeasonLeaderMetric.points,
    );

    expect(regular.leaders.first.playerId, 'p1');
    expect(playoffs.leaders.map((row) => row.playerId), ['p1']);
    expect(playoffs.leaders.single.value, 35);
  });

  test('minimum games qualification is explicit', () {
    final result = const NbaSeasonPlayerLeaderEngine().build(
      _seed(),
      seasonId: '2025-26',
      minimumGames: 8,
    );

    expect(result.leaders.map((row) => row.playerId), ['p1']);
    expect(result.eligiblePlayers, 1);
  });

  test('missing metric values are not fabricated into leader rows', () {
    final result = const NbaSeasonPlayerLeaderEngine().build(
      _seed(includeMissing: true),
      seasonId: '2025-26',
      metric: NbaSeasonLeaderMetric.blocks,
    );

    expect(result.leaders.map((row) => row.playerId), ['p1', 'p2']);
    expect(result.leaders.map((row) => row.playerId), isNot(contains('p3')));
  });
}

NbaTerminalSeedSnapshot _seed({bool includeMissing = false}) {
  final totals = <Map<String, dynamic>>[
    {
      'season_id': '2025-26',
      'season_type': 'Regular Season',
      'player_id': 'p1',
      'player_label': 'Alpha Guard',
      'team_id': 'AAA',
      'games': 10,
      'points': 250,
      'rebounds': 80,
      'assists': 90,
      'steals': 15,
      'blocks': 10,
    },
    {
      'season_id': '2025-26',
      'season_type': 'Regular Season',
      'player_id': 'p2',
      'player_label': 'Beta Wing',
      'team_id': 'BBB',
      'games': 5,
      'points': 150,
      'rebounds': 25,
      'assists': 20,
      'steals': 5,
      'blocks': 2,
    },
    {
      'season_id': '2025-26',
      'season_type': 'Playoffs',
      'player_id': 'p1',
      'player_label': 'Alpha Guard',
      'team_id': 'AAA',
      'games': 2,
      'points': 70,
      'rebounds': 12,
      'assists': 16,
      'blocks': 2,
    },
    {
      'season_id': '2024-25',
      'season_type': 'Regular Season',
      'player_id': 'old',
      'player_label': 'Old Leader',
      'team_id': 'CCC',
      'games': 82,
      'points': 3000,
      'rebounds': 900,
      'assists': 700,
      'blocks': 100,
    },
  ];
  if (includeMissing) {
    totals.add({
      'season_id': '2025-26',
      'season_type': 'Regular Season',
      'player_id': 'p3',
      'player_label': 'Gamma Guard',
      'team_id': 'CCC',
      'games': 10,
      'points': 100,
      'rebounds': 20,
    });
  }
  return NbaTerminalSeedSnapshot.fromMap({
    'manifest': const {},
    'teams': const [],
    'players': const [],
    'games': const [],
    'team_records': const [],
    'team_game_logs': const [],
    'player_season_totals': totals,
    'player_leaders': const {},
    'player_game_highs': const {},
    'player_game_logs_top': const [],
    'search_index': const [],
    'data_dictionary': const {},
    'validation_report': {'status': 'pass'},
    'release_manifest': {'status': 'test'},
    'standings': const [],
    'launch_config': {
      'supportedSeason': '2025-26',
      'datasetStatus': 'test',
    },
    'asset_path': 'test://season-leaders',
    'used_fallback': false,
  });
}
