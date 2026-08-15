import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_game_segment_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('builds period and late-game observed segments from one event stream', () {
    final result = const NbaGameSegmentEngine().build(_seed(), gameId: 'g1');

    expect(result.periodSegments.map((segment) => segment.label), ['Q1', 'Q4']);
    expect(result.lateSegments.map((segment) => segment.label), [
      'FINAL 5:00',
      'FINAL 2:00',
      'FINAL 1:00',
    ]);

    final q1 = result.periodSegments.first;
    expect(q1.eventCount, 3);
    expect(q1.startScoreLabel, '0–0');
    expect(q1.endScoreLabel, '20–24');
    expect(q1.observedPointsLabel, '20–24');
    expect(q1.startsAtBoundary, isTrue);
    expect(q1.endsAtBoundary, isTrue);
    expect(q1.boundaryComplete, isTrue);

    final finalFive = result.lateSegments.first;
    expect(finalFive.eventCount, 5);
    expect(finalFive.observedPointsLabel, '7–5');
    expect(finalFive.startScoreLabel, '90–90');
    expect(finalFive.endScoreLabel, '97–95');
    expect(finalFive.leadChanges, 3);
    expect(finalFive.ties, 1);
  });

  test('preserves partial boundary coverage instead of declaring completeness', () {
    final result = const NbaGameSegmentEngine().build(
      _seed(
        playByPlay: [
          {
            'game_id': 'g1',
            'event_num': 1,
            'period': 2,
            'clock': '8:00',
            'home_score': 30,
            'away_score': 28,
          },
          {
            'game_id': 'g1',
            'event_num': 2,
            'period': 2,
            'clock': '4:00',
            'home_score': 40,
            'away_score': 36,
          },
        ],
      ),
      gameId: 'g1',
    );

    final q2 = result.periodSegments.single;
    expect(q2.hasEvents, isTrue);
    expect(q2.startsAtBoundary, isFalse);
    expect(q2.endsAtBoundary, isFalse);
    expect(q2.boundaryComplete, isFalse);
  });

  test('creates explicit empty late windows when a game has no late rows', () {
    final result = const NbaGameSegmentEngine().build(
      _seed(
        playByPlay: [
          {
            'game_id': 'g1',
            'event_num': 1,
            'period': 1,
            'clock': '12:00',
            'home_score': 0,
            'away_score': 0,
          },
        ],
      ),
      gameId: 'g1',
    );

    expect(result.lateSegments, hasLength(3));
    expect(result.lateSegments.every((segment) => !segment.hasEvents), isTrue);
  });
}

NbaTerminalSeedSnapshot _seed({List<Map<String, dynamic>>? playByPlay}) =>
    NbaTerminalSeedSnapshot.fromMap({
      'manifest': const {},
      'teams': [
        {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
        {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
      ],
      'players': const [],
      'games': [
        {
          'game_id': 'g1',
          'season_id': '2025-26',
          'game_date': '2026-03-01',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 95,
          'away_score': 97,
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
              'clock': '12:00',
              'event_msg_type': 12,
              'home_score': 0,
              'away_score': 0,
            },
            {
              'game_id': 'g1',
              'event_num': 2,
              'period': 1,
              'clock': '11:30',
              'home_score': 2,
              'away_score': 0,
            },
            {
              'game_id': 'g1',
              'event_num': 3,
              'period': 1,
              'clock': '0:00',
              'event_msg_type': 13,
              'home_score': 24,
              'away_score': 20,
            },
            {
              'game_id': 'g1',
              'event_num': 20,
              'period': 4,
              'clock': '5:30',
              'home_score': 90,
              'away_score': 90,
            },
            {
              'game_id': 'g1',
              'event_num': 21,
              'period': 4,
              'clock': '4:50',
              'home_score': 92,
              'away_score': 90,
            },
            {
              'game_id': 'g1',
              'event_num': 22,
              'period': 4,
              'clock': '3:40',
              'home_score': 92,
              'away_score': 93,
            },
            {
              'game_id': 'g1',
              'event_num': 23,
              'period': 4,
              'clock': '2:40',
              'home_score': 95,
              'away_score': 93,
            },
            {
              'game_id': 'g1',
              'event_num': 24,
              'period': 4,
              'clock': '1:20',
              'home_score': 95,
              'away_score': 95,
            },
            {
              'game_id': 'g1',
              'event_num': 25,
              'period': 4,
              'clock': '0:00',
              'event_msg_type': 13,
              'home_score': 95,
              'away_score': 97,
            },
          ],
      'launch_config': {
        'supportedSeason': '2025-26',
        'datasetStatus': 'test',
      },
      'asset_path': 'test://segments',
      'used_fallback': false,
    });
