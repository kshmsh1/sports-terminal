import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_game_clutch_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('derives observed late-close scoring and lead changes from explicit states', () {
    final result = const NbaGameClutchEngine().build(_seed(), gameId: 'g1');

    expect(result.hasLateEvents, isTrue);
    expect(result.hasObservedCloseWindow, isTrue);
    expect(result.closeEventCount, 6);
    expect(result.closeScoringChangeCount, 5);
    expect(result.homeClosePoints, 4);
    expect(result.awayClosePoints, 5);
    expect(result.closeLeadChanges, 3);
    expect(result.closeTies, 1);
    expect(result.lastTwoMinuteEventCount, 2);
    expect(result.lastMinuteEventCount, 1);
    expect(result.firstCloseClock, '4:50');
    expect(result.lastCloseClock, '0:45');
    expect(result.methodologyLabel, contains('≤5:00'));
  });

  test('does not label a late event clutch when explicit margin is outside five', () {
    final result = const NbaGameClutchEngine().build(
      _seed(
        playByPlay: [
          {
            'game_id': 'g1',
            'event_num': 1,
            'period': 4,
            'clock': '4:30',
            'home_score': 100,
            'away_score': 90,
          },
          {
            'game_id': 'g1',
            'event_num': 2,
            'period': 4,
            'clock': '1:00',
            'home_score': 106,
            'away_score': 96,
          },
        ],
      ),
      gameId: 'g1',
    );

    expect(result.hasLateEvents, isTrue);
    expect(result.hasObservedCloseWindow, isFalse);
    expect(result.scoreChanges, isEmpty);
    expect(result.homeClosePoints, 0);
    expect(result.awayClosePoints, 0);
  });

  test('keeps score attribution empty when the feed omits score states', () {
    final result = const NbaGameClutchEngine().build(
      _seed(
        playByPlay: [
          {
            'game_id': 'g1',
            'event_num': 1,
            'period': 4,
            'clock': '2:00',
            'event_type': 'timeout',
            'team_id': 'AAA',
          },
        ],
      ),
      gameId: 'g1',
    );

    expect(result.hasLateEvents, isTrue);
    expect(result.hasObservedCloseWindow, isFalse);
    expect(result.scoreChanges, isEmpty);
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
        {'player_id': 'p2', 'player_name': 'Beta Guard', 'team_id': 'BBB'},
      ],
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
              'period': 4,
              'clock': '5:30',
              'home_score': 90,
              'away_score': 90,
            },
            {
              'game_id': 'g1',
              'event_num': 2,
              'period': 4,
              'clock': '4:50',
              'event_type': 'made shot',
              'team_id': 'AAA',
              'player_id': 'p1',
              'home_score': 92,
              'away_score': 90,
            },
            {
              'game_id': 'g1',
              'event_num': 3,
              'period': 4,
              'clock': '4:20',
              'event_type': 'made shot',
              'team_id': 'BBB',
              'player_id': 'p2',
              'home_score': 92,
              'away_score': 93,
            },
            {
              'game_id': 'g1',
              'event_num': 4,
              'period': 4,
              'clock': '3:50',
              'event_type': 'made shot',
              'team_id': 'AAA',
              'player_id': 'p1',
              'home_score': 94,
              'away_score': 93,
            },
            {
              'game_id': 'g1',
              'event_num': 5,
              'period': 4,
              'clock': '3:00',
              'event_type': 'free throw',
              'description': 'GOOD',
              'team_id': 'AAA',
              'player_id': 'p1',
              'home_score': 95,
              'away_score': 95,
            },
            {
              'game_id': 'g1',
              'event_num': 6,
              'period': 4,
              'clock': '1:45',
              'event_type': 'made shot',
              'team_id': 'BBB',
              'player_id': 'p2',
              'home_score': 95,
              'away_score': 97,
            },
            {
              'game_id': 'g1',
              'event_num': 7,
              'period': 4,
              'clock': '0:45',
              'event_type': 'timeout',
              'team_id': 'AAA',
              'home_score': 95,
              'away_score': 97,
            },
          ],
      'launch_config': {
        'supportedSeason': '2025-26',
        'datasetStatus': 'test',
      },
      'asset_path': 'test://clutch',
      'used_fallback': false,
    });
