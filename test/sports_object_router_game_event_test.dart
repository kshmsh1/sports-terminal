import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_game_intelligence_engine.dart';
import 'package:sports_terminal/services/nba_game_play_by_play_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';
import 'package:sports_terminal/services/sports_object_router.dart';

void main() {
  test('packages a canonical game event as a ready structured RoutePayload', () {
    final seed = _seed();
    final game = const NbaGameIntelligenceEngine().build(seed: seed, gameId: 'g1');
    final event = const NbaGamePlayByPlayEngine().build(seed, gameId: 'g1').events[1];

    final payload = const SportsObjectRouter().packageGameEvent(
      game: game,
      event: event,
      targetRoute: 'Python Lab',
    );

    expect(payload.sourceObjectType, 'NBA Game Event');
    expect(payload.sourceObjectId, 'g1:2');
    expect(payload.targetRoute, 'Python Lab');
    expect(payload.readinessState, 'Ready');
    expect(payload.blockers, isEmpty);
    expect(payload.rowCount, 1);
    expect(payload.selectedRows, ['g1:2']);
    expect(payload.rows.single['game_id'], 'g1');
    expect(payload.rows.single['sequence'], 2);
    expect(payload.rows.single['category'], 'madeFieldGoal');
    expect(payload.rows.single['player_id'], 'p1');
    expect(payload.rows.single['home_score'], 2);
    expect(payload.metadata['eventSequence'], 2);
    expect(payload.metadata['releaseId'], 'event-test-release');
    expect(payload.availableActions, contains('Workspace'));
    expect(payload.availableActions, contains('Source Audit'));
    expect(const SportsObjectRouter().pythonVariableName(payload), 'nba_game_event_g1_2');
  });

  test('retains structured substitution identities in routed event rows', () {
    final seed = _seed();
    final game = const NbaGameIntelligenceEngine().build(seed: seed, gameId: 'g1');
    final event = const NbaGamePlayByPlayEngine().build(seed, gameId: 'g1').events[2];

    final payload = const SportsObjectRouter().packageGameEvent(game: game, event: event);

    expect(payload.rows.single['category'], 'substitution');
    expect(payload.rows.single['substitution_out_id'], 'p1');
    expect(payload.rows.single['substitution_in_id'], 'p3');
    expect(payload.metadata['eventHasExplicitSubstitution'], isTrue);
  });

  test('marks an event partial when core ordering/time fields are missing', () {
    final seed = _seed(
      playByPlay: [
        {
          'game_id': 'g1',
          'event_type': '9',
          'description': 'Timeout',
          'home_score': 0,
          'away_score': 0,
        },
      ],
    );
    final game = const NbaGameIntelligenceEngine().build(seed: seed, gameId: 'g1');
    final event = const NbaGamePlayByPlayEngine().build(seed, gameId: 'g1').events.single;

    final payload = const SportsObjectRouter().packageGameEvent(game: game, event: event);

    expect(payload.readinessState, 'Partial');
    expect(payload.blockers, isEmpty);
    expect(payload.metadata['missingCoreFields'], containsAll(['sequence', 'period', 'clock']));
  });

  test('blocks routing when event and parent canonical game identities disagree', () {
    final seed = _seed();
    final game = const NbaGameIntelligenceEngine().build(seed: seed, gameId: 'g1');
    final foreign = const NbaGamePlayByPlayEngine().build(seed, gameId: 'g2').events.single;

    final payload = const SportsObjectRouter().packageGameEvent(game: game, event: foreign);

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
        {'player_id': 'p3', 'player_name': 'Alpha Bench', 'team_id': 'AAA'},
      ],
      'games': [
        {
          'game_id': 'g1', 'season_id': '2025-26', 'game_date': '2026-01-15',
          'season_type': 'Regular Season', 'home_team_id': 'AAA', 'away_team_id': 'BBB',
          'home_score': 2, 'away_score': 0, 'status': 'Final',
        },
        {
          'game_id': 'g2', 'season_id': '2025-26', 'game_date': '2026-02-01',
          'season_type': 'Regular Season', 'home_team_id': 'BBB', 'away_team_id': 'AAA',
          'home_score': 1, 'away_score': 0, 'status': 'Final',
        },
      ],
      'team_records': const [],
      'team_game_logs': [
        {'game_id': 'g1', 'team_id': 'AAA', 'points': 2},
        {'game_id': 'g1', 'team_id': 'BBB', 'points': 0},
      ],
      'player_season_totals': const [],
      'player_leaders': const {},
      'player_game_highs': const {},
      'player_game_logs_top': [
        {'game_id': 'g1', 'player_id': 'p1', 'player_name': 'Alpha Guard', 'team_id': 'AAA', 'points': 2},
      ],
      'search_index': const [],
      'data_dictionary': const {},
      'validation_report': {'status': 'pass'},
      'release_manifest': {'id': 'event-test-release', 'status': 'test'},
      'standings': const [],
      'play_by_play': playByPlay ??
          [
            {
              'game_id': 'g1', 'event_num': 1, 'period': 1, 'clock': '12:00',
              'event_type': '12', 'description': 'Start', 'home_score': 0, 'away_score': 0,
              'source_id': 'pbp',
            },
            {
              'game_id': 'g1', 'event_num': 2, 'period': 1, 'clock': '11:30',
              'event_type': '1', 'description': 'Alpha Guard layup', 'team_id': 'AAA',
              'player_id': 'p1', 'home_score': 2, 'away_score': 0, 'source_id': 'pbp',
            },
            {
              'game_id': 'g1', 'event_num': 3, 'period': 1, 'clock': '10:00',
              'event_type': '8', 'description': 'SUB: Alpha Bench FOR Alpha Guard', 'team_id': 'AAA',
              'player1_id': 'p1', 'player1_name': 'Alpha Guard',
              'player2_id': 'p3', 'player2_name': 'Alpha Bench',
              'home_score': 2, 'away_score': 0, 'source_id': 'pbp',
            },
            {
              'game_id': 'g2', 'event_num': 1, 'period': 1, 'clock': '11:00',
              'event_type': '3', 'description': 'Free throw', 'team_id': 'BBB',
              'home_score': 1, 'away_score': 0, 'source_id': 'pbp',
            },
          ],
      'launch_config': {'supportedSeason': '2025-26', 'datasetStatus': 'test'},
      'asset_path': 'test://event-router',
      'used_fallback': false,
    });
