import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_season_leader_matrix_engine.dart';
import 'package:sports_terminal/services/nba_season_player_leader_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('builds union of explicit top-N leaders across selected metrics', () {
    final result = const NbaSeasonLeaderMatrixEngine().build(
      _seed(),
      seasonId: '2025-26',
      metrics: [
        NbaSeasonLeaderMetric.points,
        NbaSeasonLeaderMetric.rebounds,
      ],
      topPerMetric: 1,
    );

    expect(result.metricCount, 2);
    expect(result.players.map((row) => row.playerId).toSet(), {'p1', 'p2'});
    final p2 = result.players.firstWhere((row) => row.playerId == 'p2');
    expect(p2.cells[NbaSeasonLeaderMetric.points]?.rank, 1);
    expect(p2.cells[NbaSeasonLeaderMetric.points]?.value, 30);
    expect(p2.cells[NbaSeasonLeaderMetric.rebounds], isNull);
    final p1 = result.players.firstWhere((row) => row.playerId == 'p1');
    expect(p1.cells[NbaSeasonLeaderMetric.rebounds]?.rank, 1);
    expect(p1.bestRank, 1);
  });

  test('keeps Regular Season and Playoffs as separate matrix scopes', () {
    final regular = const NbaSeasonLeaderMatrixEngine().build(
      _seed(),
      seasonId: '2025-26',
      seasonType: 'Regular Season',
      metrics: [NbaSeasonLeaderMetric.points],
    );
    final playoffs = const NbaSeasonLeaderMatrixEngine().build(
      _seed(),
      seasonId: '2025-26',
      seasonType: 'Playoffs',
      metrics: [NbaSeasonLeaderMetric.points],
    );

    expect(regular.players.map((row) => row.playerId), ['p2', 'p1']);
    expect(playoffs.players.map((row) => row.playerId), ['p1']);
    expect(
      playoffs.players.single.cells[NbaSeasonLeaderMetric.points]?.value,
      35,
    );
  });

  test('minimum-games qualification applies independently to every column', () {
    final result = const NbaSeasonLeaderMatrixEngine().build(
      _seed(),
      seasonId: '2025-26',
      metrics: [
        NbaSeasonLeaderMetric.points,
        NbaSeasonLeaderMetric.rebounds,
      ],
      minimumGames: 8,
    );

    expect(result.players.map((row) => row.playerId), ['p1']);
    expect(result.columns.every((column) => column.eligiblePlayers == 1), isTrue);
  });

  test('missing metric evidence leaves cells absent rather than synthesized', () {
    final result = const NbaSeasonLeaderMatrixEngine().build(
      _seed(includeMissing: true),
      seasonId: '2025-26',
      metrics: [
        NbaSeasonLeaderMetric.points,
        NbaSeasonLeaderMetric.blocks,
      ],
      topPerMetric: 5,
    );

    final p3 = result.players.firstWhere((row) => row.playerId == 'p3');
    expect(p3.cells[NbaSeasonLeaderMetric.points], isNotNull);
    expect(p3.cells[NbaSeasonLeaderMetric.blocks], isNull);
  });

  test('duplicate requested metrics create one matrix column', () {
    final result = const NbaSeasonLeaderMatrixEngine().build(
      _seed(),
      seasonId: '2025-26',
      metrics: [
        NbaSeasonLeaderMetric.points,
        NbaSeasonLeaderMetric.points,
      ],
    );

    expect(result.metricCount, 1);
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
    'asset_path': 'test://season-leader-matrix',
    'used_fallback': false,
  });
}
