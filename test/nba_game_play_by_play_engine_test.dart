import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_game_play_by_play_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('seed snapshot hydrates first-class play-by-play rows', () {
    final seed = _seed();

    expect(seed.playByPlay, hasLength(5));
    expect(seed.playByPlayEvents, 5);
  });

  test('canonicalizes and orders play-by-play with score context', () {
    final result = const NbaGamePlayByPlayEngine().build(
      _seed(),
      gameId: 'g1',
    );

    expect(result.eventCount, 4);
    expect(result.scoreEvents, 4);
    expect(result.periodsCovered, 2);
    expect(result.availabilityLabel, 'AVAILABLE');
    expect(result.rowsForOtherGames, 1);
    expect(result.classifiedEvents, 4);

    final first = result.events.first;
    expect(first.sequence, 10);
    expect(first.periodLabel, 'Q1');
    expect(first.clockSecondsRemaining, 690);
    expect(first.elapsedGameSeconds, 30);
    expect(first.homeScore, 2);
    expect(first.awayScore, 0);
    expect(first.team.abbreviation, 'AAA');
    expect(first.player.name, 'Example Guard');
    expect(first.description, contains('jumper'));
    expect(first.category, NbaPbpEventCategory.madeFieldGoal);
    expect(first.result, NbaPbpEventResult.made);
    expect(first.isScoringAction, isTrue);

    final last = result.events.last;
    expect(last.sequence, 40);
    expect(last.periodLabel, 'Q2');
    expect(last.clockSecondsRemaining, 715.5);
    expect(last.scoreLabel, '5–7');
  });

  test('accepts modern camelCase event aliases without inventing participants', () {
    final result = const NbaGamePlayByPlayEngine().build(
      _seed(
        playByPlay: [
          {
            'gameId': 'g1',
            'actionNumber': 88,
            'period': 4,
            'clock': 'PT1M05.00S',
            'actionType': '3pt',
            'subType': 'Jump Shot',
            'description': 'Late three',
            'scoreHome': 101,
            'scoreAway': 99,
            'sourceId': 'pbp-v3',
          },
        ],
      ),
      gameId: 'g1',
    );

    expect(result.events, hasLength(1));
    final event = result.events.single;
    expect(event.clockSecondsRemaining, 65);
    expect(event.elapsedGameSeconds, 2815);
    expect(event.homeScore, 101);
    expect(event.awayScore, 99);
    expect(event.team.id, isEmpty);
    expect(event.player.isEmpty, isTrue);
    expect(event.category, NbaPbpEventCategory.madeFieldGoal);
    expect(event.typeLabel, '3PT · JUMP SHOT');
  });

  test('classifies legacy event codes and preserves secondary participants', () {
    final result = const NbaGamePlayByPlayEngine().build(
      _seed(
        playByPlay: [
          {
            'game_id': 'g1',
            'event_num': 90,
            'event_msg_type': 8,
            'period': 3,
            'clock': '6:30',
            'team_id': 'AAA',
            'player1_id': 'p1',
            'player1_name': 'Example Guard',
            'player2_id': 'p3',
            'player2_name': 'Reserve Guard',
            'description': 'SUB: Reserve Guard FOR Example Guard',
          },
        ],
      ),
      gameId: 'g1',
    );

    final event = result.events.single;
    expect(event.category, NbaPbpEventCategory.substitution);
    expect(event.player.id, 'p1');
    expect(event.secondaryPlayer.id, 'p3');
    expect(event.hasExplicitSubstitution, isTrue);
    expect(event.substitutionOut.id, 'p1');
    expect(event.substitutionIn.id, 'p3');
    expect(result.explicitSubstitutionEvents, 1);
  });

  test('does not fabricate a substitution counterpart from an incomplete row', () {
    final result = const NbaGamePlayByPlayEngine().build(
      _seed(
        playByPlay: [
          {
            'game_id': 'g1',
            'event_num': 91,
            'event_type': 'substitution',
            'period': 4,
            'clock': '4:00',
            'team_id': 'AAA',
            'player_out_id': 'p1',
            'player_out_name': 'Example Guard',
          },
        ],
      ),
      gameId: 'g1',
    );

    final event = result.events.single;
    expect(event.category, NbaPbpEventCategory.substitution);
    expect(event.substitutionOut.id, 'p1');
    expect(event.substitutionIn.isEmpty, isTrue);
    expect(event.hasExplicitSubstitution, isFalse);
    expect(result.explicitSubstitutionEvents, 0);
  });

  test('normalizes free-throw outcome only when the row supports it', () {
    final result = const NbaGamePlayByPlayEngine().build(
      _seed(
        playByPlay: [
          {
            'game_id': 'g1',
            'event_num': 100,
            'event_msg_type': 3,
            'period': 4,
            'clock': '0:42',
            'player_id': 'p1',
            'team_id': 'AAA',
            'description': 'Example Guard Free Throw 1 of 2 MISS',
            'home_score': 100,
            'away_score': 99,
          },
          {
            'game_id': 'g1',
            'event_num': 101,
            'event_msg_type': 3,
            'period': 4,
            'clock': '0:42',
            'player_id': 'p1',
            'team_id': 'AAA',
            'description': 'Example Guard Free Throw 2 of 2 GOOD',
            'home_score': 101,
            'away_score': 99,
          },
        ],
      ),
      gameId: 'g1',
    );

    expect(result.events.first.category, NbaPbpEventCategory.freeThrow);
    expect(result.events.first.result, NbaPbpEventResult.missed);
    expect(result.events.first.isScoringAction, isFalse);
    expect(result.events.last.result, NbaPbpEventResult.made);
    expect(result.events.last.isScoringAction, isTrue);
  });

  test('reports event rows not exposed when manifest declares normalized PBP', () {
    final result = const NbaGamePlayByPlayEngine().build(
      _seed(
        playByPlay: const [],
        manifest: const {
          'warehouseBuild': {'playByPlayEventsNormalized': 412},
        },
      ),
      gameId: 'g1',
    );

    expect(result.events, isEmpty);
    expect(result.declaredNormalizedEventCount, 412);
    expect(result.availabilityLabel, 'EVENT ROWS NOT EXPOSED');
  });

  test('does not attach rows from another canonical game', () {
    final result = const NbaGamePlayByPlayEngine().build(
      _seed(
        playByPlay: [
          {
            'game_id': 'g2',
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

    expect(result.events, isEmpty);
    expect(result.rowsForOtherGames, 1);
    expect(result.availabilityLabel, 'NO EVENTS FOR GAME');
  });
}

NbaTerminalSeedSnapshot _seed({
  List<Map<String, dynamic>>? playByPlay,
  Map<String, dynamic>? manifest,
}) =>
    NbaTerminalSeedSnapshot.fromMap({
      'manifest': manifest ?? const {},
      'teams': [
        {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
        {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
      ],
      'players': [
        {'player_id': 'p1', 'player_name': 'Example Guard', 'team_id': 'AAA'},
        {'player_id': 'p2', 'player_name': 'Example Wing', 'team_id': 'BBB'},
        {'player_id': 'p3', 'player_name': 'Reserve Guard', 'team_id': 'AAA'},
      ],
      'games': [
        {
          'game_id': 'g1',
          'season_id': '2025-26',
          'game_date': '2026-01-15',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 110,
          'away_score': 105,
        },
        {
          'game_id': 'g2',
          'season_id': '2025-26',
          'game_date': '2026-02-01',
          'season_type': 'Regular Season',
          'home_team_id': 'BBB',
          'away_team_id': 'AAA',
          'home_score': 100,
          'away_score': 98,
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
              'event_num': 30,
              'period': 1,
              'clock': '10:40',
              'event_type': 'made shot',
              'description': 'Example Guard driving layup',
              'team_id': 'AAA',
              'player_id': 'p1',
              'home_score': 4,
              'away_score': 3,
              'source_id': 'pbp',
            },
            {
              'game_id': 'g1',
              'event_num': 10,
              'period': 1,
              'clock': '11:30',
              'event_type': 'made shot',
              'description': 'Example Guard jumper',
              'team_id': 'AAA',
              'player_id': 'p1',
              'home_score': 2,
              'away_score': 0,
              'source_id': 'pbp',
            },
            {
              'game_id': 'g1',
              'event_num': 20,
              'period': 1,
              'clock': '11:01',
              'event_type': 'made shot',
              'description': 'Example Wing three',
              'team_id': 'BBB',
              'player_id': 'p2',
              'home_score': 2,
              'away_score': 3,
              'source_id': 'pbp',
            },
            {
              'game_id': 'g1',
              'event_num': 40,
              'period': 2,
              'clock': '11:55.5',
              'event_type': 'made shot',
              'description': 'Second-quarter basket',
              'team_id': 'BBB',
              'player_id': 'p2',
              'home_score': 7,
              'away_score': 5,
              'source_id': 'pbp',
            },
            {
              'game_id': 'g2',
              'event_num': 1,
              'period': 1,
              'clock': '12:00',
              'home_score': 0,
              'away_score': 0,
            },
          ],
      'launch_config': {
        'supportedSeason': '2025-26',
        'datasetStatus': 'test',
      },
      'asset_path': 'test://pbp',
      'used_fallback': false,
    });
