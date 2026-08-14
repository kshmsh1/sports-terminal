import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_game_player_scoring_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('credits only explicit scoring actions with player identity', () {
    final result = const NbaGamePlayerScoringEngine().build(_seed(), gameId: 'g1');

    expect(result.observedPoints, 8);
    expect(result.creditedPoints, 6);
    expect(result.uncreditedPoints, 2);
    expect(result.fullyAttributed, isFalse);
    expect(result.players, hasLength(2));

    final alpha = result.players.firstWhere((row) => row.player.id == 'p1');
    expect(alpha.observedPoints, 3);
    expect(alpha.scoringEvents, 2);
    expect(alpha.closeWindowPoints, 1);
    expect(alpha.lastScore?.scoreLabel, '3–5');

    final beta = result.players.firstWhere((row) => row.player.id == 'p2');
    expect(beta.observedPoints, 3);
    expect(beta.scoringEvents, 1);

    expect(result.uncreditedScoreChanges.single.reason, 'scoring-player-not-exposed');
  });

  test('does not credit a player when team evidence conflicts with score delta', () {
    final result = const NbaGamePlayerScoringEngine().build(
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
          {
            'game_id': 'g1',
            'event_num': 2,
            'period': 1,
            'clock': '11:40',
            'event_type': 'made shot',
            'team_id': 'BBB',
            'player_id': 'p2',
            'home_score': 2,
            'away_score': 0,
          },
        ],
      ),
      gameId: 'g1',
    );

    expect(result.players, isEmpty);
    expect(result.uncreditedPoints, 2);
    expect(
      result.uncreditedScoreChanges.single.reason,
      'scoring-team-conflicts-with-score-delta',
    );
  });

  test('keeps a score delta uncredited when action semantics are not scoring', () {
    final result = const NbaGamePlayerScoringEngine().build(
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
          {
            'game_id': 'g1',
            'event_num': 2,
            'period': 1,
            'clock': '11:40',
            'event_type': 'timeout',
            'team_id': 'AAA',
            'player_id': 'p1',
            'home_score': 2,
            'away_score': 0,
          },
        ],
      ),
      gameId: 'g1',
    );

    expect(result.players, isEmpty);
    expect(result.uncreditedPoints, 2);
    expect(
      result.uncreditedScoreChanges.single.reason,
      'score-change-without-explicit-scoring-action',
    );
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
          'game_date': '2026-03-01',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 5,
          'away_score': 3,
          'status': 'Final',
        },
      ],
      'team_records': const [],
      'team_game_logs': const [],
      'player_season_totals': const [],
      'player_leaders': const {},
      'player_game_highs': const {},
      'player_game_logs_top': [
        {
          'game_id': 'g1',
          'player_id': 'p1',
          'player_name': 'Alpha Guard',
          'team_id': 'AAA',
          'points': 3,
        },
        {
          'game_id': 'g1',
          'player_id': 'p2',
          'player_name': 'Beta Wing',
          'team_id': 'BBB',
          'points': 3,
        },
      ],
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
              'home_score': 0,
              'away_score': 0,
            },
            {
              'game_id': 'g1',
              'event_num': 2,
              'period': 1,
              'clock': '11:30',
              'event_type': 'made shot',
              'team_id': 'AAA',
              'player_id': 'p1',
              'home_score': 2,
              'away_score': 0,
            },
            {
              'game_id': 'g1',
              'event_num': 3,
              'period': 1,
              'clock': '11:00',
              'event_type': 'made shot',
              'team_id': 'BBB',
              'player_id': 'p2',
              'home_score': 2,
              'away_score': 3,
            },
            {
              'game_id': 'g1',
              'event_num': 4,
              'period': 2,
              'clock': '9:00',
              'event_type': 'missed shot',
              'team_id': 'AAA',
              'player_id': 'p1',
              'home_score': 2,
              'away_score': 3,
            },
            {
              'game_id': 'g1',
              'event_num': 5,
              'period': 3,
              'clock': '5:00',
              'event_type': 'made shot',
              'team_id': 'AAA',
              'home_score': 4,
              'away_score': 3,
            },
            {
              'game_id': 'g1',
              'event_num': 6,
              'period': 4,
              'clock': '4:20',
              'event_type': 'free throw',
              'description': 'Alpha Guard Free Throw GOOD',
              'team_id': 'AAA',
              'player_id': 'p1',
              'home_score': 5,
              'away_score': 3,
            },
          ],
      'launch_config': {
        'supportedSeason': '2025-26',
        'datasetStatus': 'test',
      },
      'asset_path': 'test://player-scoring',
      'used_fallback': false,
    });
