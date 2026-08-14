import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_game_event_query_engine.dart';
import 'package:sports_terminal/services/nba_game_play_by_play_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('filters canonical event stream by category, team, player and period', () {
    final engine = const NbaGameEventQueryEngine();
    final seed = _seed();

    final made = engine.build(
      seed,
      gameId: 'g1',
      category: NbaPbpEventCategory.madeFieldGoal,
      teamId: 'AAA',
      playerId: 'p1',
      period: 4,
    );

    expect(made.totalEvents, 8);
    expect(made.matchedEvents, 2);
    expect(made.events.map((event) => event.sequence), [3, 7]);
    expect(made.filterSummary, contains('category=madeFieldGoal'));
    expect(made.filterSummary, contains('team=AAA'));
    expect(made.filterSummary, contains('player=p1'));
  });

  test('searches descriptions, identities, category labels and source metadata', () {
    final engine = const NbaGameEventQueryEngine();
    final seed = _seed();

    expect(
      engine.build(seed, gameId: 'g1', query: 'corner three').events.single.sequence,
      3,
    );
    expect(
      engine.build(seed, gameId: 'g1', query: 'Example Wing').events.length,
      3,
    );
    expect(
      engine.build(seed, gameId: 'g1', query: 'SUBSTITUTION').events.single.sequence,
      6,
    );
    expect(
      engine.build(seed, gameId: 'g1', query: 'pbp-v3').matchedEvents,
      8,
    );
  });

  test('observed close filter requires Q4 or OT, five minutes and explicit margin <= five', () {
    final result = const NbaGameEventQueryEngine().build(
      _seed(),
      gameId: 'g1',
      closeGameOnly: true,
    );

    expect(result.events.map((event) => event.sequence), [2, 3, 4, 5, 6, 7, 8]);
    expect(result.events.every((event) => event.period! >= 4), isTrue);
    expect(result.events.every((event) => event.clockSecondsRemaining! <= 300), isTrue);
    expect(result.events.every((event) => event.margin!.abs() <= 5), isTrue);
  });

  test('scoring and substitution filters remain evidence based', () {
    final seed = _seed();
    final engine = const NbaGameEventQueryEngine();

    final scoring = engine.build(seed, gameId: 'g1', scoringOnly: true);
    expect(scoring.events.map((event) => event.sequence), [3, 4, 7]);

    final substitutions = engine.build(
      seed,
      gameId: 'g1',
      substitutionsOnly: true,
    );
    expect(substitutions.events.single.sequence, 6);
    expect(substitutions.events.single.hasExplicitSubstitution, isTrue);
  });

  test('supports reverse order, hard result limits and facet counts', () {
    final result = const NbaGameEventQueryEngine().build(
      _seed(),
      gameId: 'g1',
      ascending: false,
      limit: 3,
    );

    expect(result.matchedEvents, 8);
    expect(result.returnedEvents, 3);
    expect(result.truncated, isTrue);
    expect(result.events.map((event) => event.sequence), [8, 7, 6]);
    expect(result.categoryCounts[NbaPbpEventCategory.madeFieldGoal], 2);
    expect(result.categoryCounts[NbaPbpEventCategory.freeThrow], 1);
    expect(result.periodCounts[4], 7);
    expect(result.teamCounts['AAA'], 4);
    expect(result.playerCounts['p1'], 4);
  });

  test('empty upstream event rows stay explicitly unavailable', () {
    final result = const NbaGameEventQueryEngine().build(
      _seed(playByPlay: const []),
      gameId: 'g1',
      query: 'anything',
    );

    expect(result.events, isEmpty);
    expect(result.totalEvents, 0);
    expect(result.matchedEvents, 0);
    expect(result.availabilityLabel, 'UNAVAILABLE');
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
        {'player_id': 'p1', 'player_name': 'Example Guard', 'team_id': 'AAA'},
        {'player_id': 'p2', 'player_name': 'Example Wing', 'team_id': 'BBB'},
        {'player_id': 'p3', 'player_name': 'Bench Guard', 'team_id': 'AAA'},
      ],
      'games': [
        {
          'game_id': 'g1',
          'season_id': '2025-26',
          'game_date': '2026-01-15',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 106,
          'away_score': 105,
          'status': 'Final',
        },
      ],
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
      'play_by_play': playByPlay ??
          [
            {
              'game_id': 'g1',
              'event_num': 1,
              'period': 1,
              'clock': '11:30',
              'event_type': '2',
              'description': 'Example Wing misses jumper',
              'team_id': 'BBB',
              'player_id': 'p2',
              'home_score': 10,
              'away_score': 8,
              'source_id': 'pbp-v3',
            },
            {
              'game_id': 'g1',
              'event_num': 2,
              'period': 4,
              'clock': '4:58',
              'event_type': '5',
              'description': 'Example Wing turnover',
              'team_id': 'BBB',
              'player_id': 'p2',
              'home_score': 96,
              'away_score': 94,
              'source_id': 'pbp-v3',
            },
            {
              'game_id': 'g1',
              'event_num': 3,
              'period': 4,
              'clock': '4:20',
              'event_type': '1',
              'description': 'Example Guard corner three',
              'team_id': 'AAA',
              'player_id': 'p1',
              'home_score': 99,
              'away_score': 94,
              'source_id': 'pbp-v3',
            },
            {
              'game_id': 'g1',
              'event_num': 4,
              'period': 4,
              'clock': '3:10',
              'event_type': '3',
              'sub_type': '1 of 1',
              'description': 'Example Wing makes free throw',
              'team_id': 'BBB',
              'player_id': 'p2',
              'home_score': 99,
              'away_score': 95,
              'source_id': 'pbp-v3',
            },
            {
              'game_id': 'g1',
              'event_num': 5,
              'period': 4,
              'clock': '2:00',
              'event_type': '6',
              'description': 'Personal foul',
              'team_id': 'AAA',
              'player_id': 'p1',
              'home_score': 101,
              'away_score': 99,
              'source_id': 'pbp-v3',
            },
            {
              'game_id': 'g1',
              'event_num': 6,
              'period': 4,
              'clock': '1:30',
              'event_type': '8',
              'description': 'SUB: Bench Guard FOR Example Guard',
              'team_id': 'AAA',
              'player1_id': 'p1',
              'player1_name': 'Example Guard',
              'player2_id': 'p3',
              'player2_name': 'Bench Guard',
              'home_score': 101,
              'away_score': 99,
              'source_id': 'pbp-v3',
            },
            {
              'game_id': 'g1',
              'event_num': 7,
              'period': 4,
              'clock': '0:40',
              'event_type': '1',
              'description': 'Example Guard layup',
              'team_id': 'AAA',
              'player_id': 'p1',
              'home_score': 103,
              'away_score': 101,
              'source_id': 'pbp-v3',
            },
            {
              'game_id': 'g1',
              'event_num': 8,
              'period': 4,
              'clock': '0:00',
              'event_type': '13',
              'description': 'End of game',
              'home_score': 106,
              'away_score': 105,
              'source_id': 'pbp-v3',
            },
          ],
      'launch_config': {
        'supportedSeason': '2025-26',
        'datasetStatus': 'test',
      },
      'asset_path': 'test://event-query',
      'used_fallback': false,
    });
