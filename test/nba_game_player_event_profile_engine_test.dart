import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_game_player_event_profile_engine.dart';
import 'package:sports_terminal/services/nba_game_play_by_play_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('builds player profiles from observed participation and attributable scoring', () {
    final result = const NbaGamePlayerEventProfileEngine().build(
      _seed(),
      gameId: 'g1',
    );

    expect(result.eventCount, 8);
    expect(result.observedAttributedPoints, 5);
    expect(result.uncreditedObservedPoints, 4);
    expect(result.profiles.map((profile) => profile.player.id), containsAll(['p1', 'p2', 'p3']));

    final guard = result.byPlayerId('p1')!;
    expect(guard.player.name, 'Alpha Guard');
    expect(guard.teamIds, ['AAA']);
    expect(guard.participationEvents, 5);
    expect(guard.primaryEvents, 5);
    expect(guard.secondaryAppearances, 0);
    expect(guard.observedPoints, 4);
    expect(guard.observedScoringEvents, 2);
    expect(guard.closeWindowPoints, 2);
    expect(guard.closeWindowScoringEvents, 1);
    expect(guard.confirmedSubstitutionOuts, 1);
    expect(guard.confirmedSubstitutionIns, 0);
    expect(guard.categoryCount(NbaPbpEventCategory.madeFieldGoal), 2);
    expect(guard.categoryCount(NbaPbpEventCategory.turnover), 1);
  });

  test('tracks secondary/tertiary appearances without relabeling their roles', () {
    final result = const NbaGamePlayerEventProfileEngine().build(_seed(), gameId: 'g1');

    final wing = result.byPlayerId('p2')!;
    expect(wing.secondaryAppearances, 1);
    expect(wing.tertiaryAppearances, 1);
    expect(wing.primaryEvents, 1);
    expect(wing.observedPoints, 1);
    expect(wing.categoryCount(NbaPbpEventCategory.freeThrow), 1);
  });

  test('confirmed substitution participants receive evidence-only entry/exit counts', () {
    final result = const NbaGamePlayerEventProfileEngine().build(_seed(), gameId: 'g1');

    final bench = result.byPlayerId('p3')!;
    expect(bench.confirmedSubstitutionIns, 1);
    expect(bench.confirmedSubstitutionOuts, 0);
    expect(bench.participationEvents, 1);
    expect(bench.primaryEvents, 0);
    expect(bench.substitutionLabel, '1 in / 0 out');
  });

  test('profiles retain close-window participation independently of scoring credit', () {
    final result = const NbaGamePlayerEventProfileEngine().build(_seed(), gameId: 'g1');
    final guard = result.byPlayerId('p1')!;

    expect(guard.closeWindowParticipationEvents, 4);
    expect(guard.closeWindowPoints, 2);
  });

  test('empty row-level PBP produces no fabricated player profiles', () {
    final result = const NbaGamePlayerEventProfileEngine().build(
      _seed(playByPlay: const []),
      gameId: 'g1',
    );

    expect(result.profiles, isEmpty);
    expect(result.eventCount, 0);
    expect(result.observedAttributedPoints, 0);
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
        {'player_id': 'p1', 'player_name': 'Alpha Guard', 'team_id': 'AAA'},
        {'player_id': 'p2', 'player_name': 'Beta Wing', 'team_id': 'BBB'},
        {'player_id': 'p3', 'player_name': 'Alpha Bench', 'team_id': 'AAA'},
      ],
      'games': [
        {
          'game_id': 'g1',
          'season_id': '2025-26',
          'game_date': '2026-01-15',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 6,
          'away_score': 3,
          'status': 'Final',
        },
      ],
      'team_records': const [],
      'team_game_logs': [
        {'game_id': 'g1', 'team_id': 'AAA', 'points': 6},
        {'game_id': 'g1', 'team_id': 'BBB', 'points': 3},
      ],
      'player_season_totals': const [],
      'player_leaders': const {},
      'player_game_highs': const {},
      'player_game_logs_top': [
        {'game_id': 'g1', 'player_id': 'p1', 'player_name': 'Alpha Guard', 'team_id': 'AAA', 'points': 4},
        {'game_id': 'g1', 'player_id': 'p2', 'player_name': 'Beta Wing', 'team_id': 'BBB', 'points': 1},
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
              'event_type': '12',
              'description': 'Start',
              'home_score': 0,
              'away_score': 0,
            },
            {
              'game_id': 'g1',
              'event_num': 2,
              'period': 1,
              'clock': '11:20',
              'event_type': '1',
              'description': 'Alpha Guard layup',
              'team_id': 'AAA',
              'player_id': 'p1',
              'home_score': 2,
              'away_score': 0,
            },
            {
              'game_id': 'g1',
              'event_num': 3,
              'period': 4,
              'clock': '4:30',
              'event_type': '5',
              'description': 'Alpha Guard turnover',
              'team_id': 'AAA',
              'player_id': 'p1',
              'player2_id': 'p2',
              'player2_name': 'Beta Wing',
              'home_score': 2,
              'away_score': 0,
            },
            {
              'game_id': 'g1',
              'event_num': 4,
              'period': 4,
              'clock': '3:40',
              'event_type': '3',
              'description': 'Beta Wing makes free throw',
              'team_id': 'BBB',
              'player_id': 'p2',
              'player3_id': 'p2',
              'player3_name': 'Beta Wing',
              'home_score': 2,
              'away_score': 1,
            },
            {
              'game_id': 'g1',
              'event_num': 5,
              'period': 4,
              'clock': '2:50',
              'event_type': '8',
              'description': 'SUB: Alpha Bench FOR Alpha Guard',
              'team_id': 'AAA',
              'player1_id': 'p1',
              'player1_name': 'Alpha Guard',
              'player2_id': 'p3',
              'player2_name': 'Alpha Bench',
              'home_score': 2,
              'away_score': 1,
            },
            {
              'game_id': 'g1',
              'event_num': 6,
              'period': 4,
              'clock': '1:40',
              'event_type': '1',
              'description': 'Alpha Guard jumper',
              'team_id': 'AAA',
              'player_id': 'p1',
              'home_score': 4,
              'away_score': 1,
            },
            {
              'game_id': 'g1',
              'event_num': 7,
              'period': 4,
              'clock': '0:30',
              'event_type': '6',
              'description': 'Alpha Guard foul',
              'team_id': 'AAA',
              'player_id': 'p1',
              'home_score': 4,
              'away_score': 1,
            },
            {
              'game_id': 'g1',
              'event_num': 8,
              'period': 4,
              'clock': '0:00',
              'event_type': '13',
              'description': 'End',
              'home_score': 6,
              'away_score': 3,
            },
          ],
      'launch_config': {'supportedSeason': '2025-26', 'datasetStatus': 'test'},
      'asset_path': 'test://player-event-profile',
      'used_fallback': false,
    });
