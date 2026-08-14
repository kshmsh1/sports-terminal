import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_game_event_batch_route_service.dart';
import 'package:sports_terminal/services/nba_game_event_query_engine.dart';
import 'package:sports_terminal/services/nba_game_intelligence_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('packages exactly the filtered canonical event selection', () {
    final seed = _seed();
    final game = const NbaGameIntelligenceEngine().build(seed: seed, gameId: 'g1');
    final result = const NbaGameEventQueryEngine().build(
      seed,
      gameId: 'g1',
      teamId: 'AAA',
      period: 4,
    );

    final payload = const NbaGameEventBatchRouteService().package(
      game: game,
      result: result,
      targetRoute: 'Python Lab',
    );

    expect(payload.sourceObjectType, 'NBA Game Event Selection');
    expect(payload.targetRoute, 'Python Lab');
    expect(payload.readinessState, 'Ready');
    expect(payload.rowCount, 2);
    expect(payload.rows.map((row) => row['sequence']), [2, 4]);
    expect(payload.filterSummary, contains('team=AAA'));
    expect(payload.filterSummary, contains('period=4'));
    expect(payload.metadata['matchedEvents'], 2);
    expect(payload.metadata['returnedEvents'], 2);
    expect(payload.metadata['queryTruncated'], isFalse);
  });

  test('empty filtered selections remain explicit partial packages', () {
    final seed = _seed();
    final game = const NbaGameIntelligenceEngine().build(seed: seed, gameId: 'g1');
    final result = const NbaGameEventQueryEngine().build(
      seed,
      gameId: 'g1',
      query: 'does-not-exist',
    );

    final payload = const NbaGameEventBatchRouteService().package(
      game: game,
      result: result,
      targetRoute: 'Workspace',
    );

    expect(payload.rows, isEmpty);
    expect(payload.readinessState, 'Partial');
    expect(payload.metadata['matchedEvents'], 0);
    expect(payload.filterSummary, contains('query=does-not-exist'));
  });

  test('partial event rows remain partial instead of being repaired', () {
    final seed = _seed(playByPlay: [
      {
        'game_id': 'g1',
        'event_type': '5',
        'description': 'Turnover without ordering fields',
        'team_id': 'AAA',
        'player_id': 'p1',
      },
    ]);
    final game = const NbaGameIntelligenceEngine().build(seed: seed, gameId: 'g1');
    final result = const NbaGameEventQueryEngine().build(seed, gameId: 'g1');

    final payload = const NbaGameEventBatchRouteService().package(
      game: game,
      result: result,
    );

    expect(payload.readinessState, 'Partial');
    expect(payload.metadata['missingCoreRows'], 1);
    expect(payload.rows.single['sequence'], isNull);
    expect(payload.rows.single['period'], isNull);
    expect(payload.rows.single['clock'], '');
  });

  test('blocks a selection containing an event from another parent game', () {
    final seed = _seed(playByPlay: [
      {
        'game_id': 'g2',
        'event_num': 99,
        'period': 4,
        'clock': '0:10',
        'event_type': '5',
        'description': 'Foreign canonical turnover',
        'team_id': 'BBB',
        'player_id': 'p2',
        'home_score': 12,
        'away_score': 11,
        'source_id': 'test',
      },
    ]);
    final game = const NbaGameIntelligenceEngine().build(seed: seed, gameId: 'g1');
    final foreignSelection = const NbaGameEventQueryEngine().build(
      seed,
      gameId: 'g2',
    );

    final payload = const NbaGameEventBatchRouteService().package(
      game: game,
      result: foreignSelection,
    );

    expect(foreignSelection.events, hasLength(1));
    expect(foreignSelection.events.single.gameId, 'g2');
    expect(payload.readinessState, 'Blocked');
    expect(payload.blockers, contains('event-game-mismatch'));
  });
}

NbaTerminalSeedSnapshot _seed({List<Map<String, dynamic>>? playByPlay}) =>
    NbaTerminalSeedSnapshot.fromMap({
      'manifest': const {},
      'teams': [
        {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
        {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
      ],
      'players': [
        {'player_id': 'p1', 'player_name': 'Alpha Guard', 'team_id': 'AAA'},
        {'player_id': 'p2', 'player_name': 'Beta Wing', 'team_id': 'BBB'},
      ],
      'games': [
        {
          'game_id': 'g1',
          'season_id': '2025-26',
          'game_date': '2026-01-15',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 10,
          'away_score': 9,
          'status': 'Final',
        },
        {
          'game_id': 'g2',
          'season_id': '2025-26',
          'game_date': '2026-01-16',
          'season_type': 'Regular Season',
          'home_team_id': 'BBB',
          'away_team_id': 'AAA',
          'home_score': 12,
          'away_score': 11,
          'status': 'Final',
        },
      ],
      'team_records': const [],
      'team_game_logs': [
        {'game_id': 'g1', 'team_id': 'AAA', 'points': 10},
        {'game_id': 'g1', 'team_id': 'BBB', 'points': 9},
        {'game_id': 'g2', 'team_id': 'AAA', 'points': 11},
        {'game_id': 'g2', 'team_id': 'BBB', 'points': 12},
      ],
      'player_season_totals': const [],
      'player_leaders': const {},
      'player_game_highs': const {},
      'player_game_logs_top': const [],
      'search_index': const [],
      'data_dictionary': const {},
      'validation_report': {'status': 'pass'},
      'release_manifest': {'status': 'test'},
      'standings': const [],
      'play_by_play': playByPlay ??
          [
            {
              'game_id': 'g1', 'event_num': 1, 'period': 1, 'clock': '11:00',
              'event_type': '2', 'description': 'Beta misses', 'team_id': 'BBB',
              'player_id': 'p2', 'home_score': 0, 'away_score': 0,
            },
            {
              'game_id': 'g1', 'event_num': 2, 'period': 4, 'clock': '4:00',
              'event_type': '1', 'description': 'Alpha layup', 'team_id': 'AAA',
              'player_id': 'p1', 'home_score': 8, 'away_score': 7,
            },
            {
              'game_id': 'g1', 'event_num': 3, 'period': 4, 'clock': '2:00',
              'event_type': '5', 'description': 'Beta turnover', 'team_id': 'BBB',
              'player_id': 'p2', 'home_score': 8, 'away_score': 7,
            },
            {
              'game_id': 'g1', 'event_num': 4, 'period': 4, 'clock': '0:30',
              'event_type': '1', 'description': 'Alpha jumper', 'team_id': 'AAA',
              'player_id': 'p1', 'home_score': 10, 'away_score': 9,
            },
          ],
      'launch_config': {'supportedSeason': '2025-26', 'datasetStatus': 'test'},
      'asset_path': 'test://event-batch',
      'used_fallback': false,
    });
