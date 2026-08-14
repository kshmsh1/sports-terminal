import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_game_play_by_play_engine.dart';
import 'package:sports_terminal/services/nba_game_team_event_profile_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('builds explicit team event profiles and separates score deltas from player credit', () {
    final result = const NbaGameTeamEventProfileEngine().build(_seed(), gameId: 'g1');

    expect(result.eventCount, 8);
    expect(result.profiles, hasLength(2));
    expect(result.unattributedEventCount, 2);
    expect(result.uncreditedObservedPoints, 5);

    final home = result.byTeamId('AAA')!;
    expect(home.explicitTeamEvents, 4);
    expect(home.primaryPlayerEvents, 4);
    expect(home.observedScoreDeltaPoints, 6);
    expect(home.creditedPlayerPoints, 4);
    expect(home.uncreditedTeamObservedPoints, 2);
    expect(home.creditedScoringEvents, 2);
    expect(home.creditedClosePoints, 2);
    expect(home.confirmedSubstitutions, 1);
    expect(home.categoryCount(NbaPbpEventCategory.madeFieldGoal), 2);
    expect(home.categoryCount(NbaPbpEventCategory.substitution), 1);
    expect(home.periodCount(4), 3);
  });

  test('away profile keeps explicit event categories and close-window coverage', () {
    final result = const NbaGameTeamEventProfileEngine().build(_seed(), gameId: 'g1');
    final away = result.byTeamId('BBB')!;

    expect(away.explicitTeamEvents, 2);
    expect(away.observedScoreDeltaPoints, 3);
    expect(away.creditedPlayerPoints, 0);
    expect(away.uncreditedTeamObservedPoints, 3);
    expect(away.closeWindowEvents, 2);
    expect(away.categoryCount(NbaPbpEventCategory.freeThrow), 1);
    expect(away.categoryCount(NbaPbpEventCategory.turnover), 1);
  });

  test('events without a canonical team remain visible as unattributed coverage', () {
    final result = const NbaGameTeamEventProfileEngine().build(_seed(), gameId: 'g1');

    expect(result.unattributedEventCount, 2);
    expect(result.byTeamId('AAA')!.explicitTeamEvents + result.byTeamId('BBB')!.explicitTeamEvents, 6);
  });

  test('empty PBP does not backfill team event profiles with box-score activity', () {
    final result = const NbaGameTeamEventProfileEngine().build(
      _seed(playByPlay: const []),
      gameId: 'g1',
    );

    expect(result.eventCount, 0);
    expect(result.unattributedEventCount, 0);
    expect(result.byTeamId('AAA')!.explicitTeamEvents, 0);
    expect(result.byTeamId('AAA')!.observedScoreDeltaPoints, 0);
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
              'game_id': 'g1', 'event_num': 1, 'period': 1, 'clock': '12:00',
              'event_type': '12', 'description': 'Start', 'home_score': 0, 'away_score': 0,
            },
            {
              'game_id': 'g1', 'event_num': 2, 'period': 1, 'clock': '11:20',
              'event_type': '1', 'description': 'Alpha Guard layup', 'team_id': 'AAA',
              'player_id': 'p1', 'home_score': 2, 'away_score': 0,
            },
            {
              'game_id': 'g1', 'event_num': 3, 'period': 4, 'clock': '4:30',
              'event_type': '5', 'description': 'Beta Wing turnover', 'team_id': 'BBB',
              'player_id': 'p2', 'home_score': 2, 'away_score': 0,
            },
            {
              'game_id': 'g1', 'event_num': 4, 'period': 4, 'clock': '3:40',
              'event_type': '3', 'description': 'Beta Wing makes free throw', 'team_id': 'BBB',
              'player_id': 'p2', 'home_score': 2, 'away_score': 1,
            },
            {
              'game_id': 'g1', 'event_num': 5, 'period': 4, 'clock': '2:50',
              'event_type': '8', 'description': 'SUB: Alpha Bench FOR Alpha Guard', 'team_id': 'AAA',
              'player1_id': 'p1', 'player1_name': 'Alpha Guard',
              'player2_id': 'p3', 'player2_name': 'Alpha Bench',
              'home_score': 2, 'away_score': 1,
            },
            {
              'game_id': 'g1', 'event_num': 6, 'period': 4, 'clock': '1:40',
              'event_type': '1', 'description': 'Alpha Guard jumper', 'team_id': 'AAA',
              'player_id': 'p1', 'home_score': 4, 'away_score': 1,
            },
            {
              'game_id': 'g1', 'event_num': 7, 'period': 4, 'clock': '0:30',
              'event_type': '6', 'description': 'Alpha Guard foul', 'team_id': 'AAA',
              'player_id': 'p1', 'home_score': 4, 'away_score': 1,
            },
            {
              'game_id': 'g1', 'event_num': 8, 'period': 4, 'clock': '0:00',
              'event_type': '13', 'description': 'End', 'home_score': 6, 'away_score': 3,
            },
          ],
      'launch_config': {'supportedSeason': '2025-26', 'datasetStatus': 'test'},
      'asset_path': 'test://team-event-profile',
      'used_fallback': false,
    });
