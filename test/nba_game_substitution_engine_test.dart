import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_game_substitution_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  test('extracts legacy and structured confirmed substitutions', () {
    final result = const NbaGameSubstitutionEngine().build(_seed(), gameId: 'g1');

    expect(result.substitutionRows, 3);
    expect(result.confirmedSwapCount, 2);
    expect(result.incompleteSubstitutionRows, 1);
    expect(result.coverageLabel, 'PARTIAL SWAP COVERAGE');
    expect(result.confirmedForTeam('AAA'), 2);

    final first = result.swaps.first;
    expect(first.playerOut.id, 'p1');
    expect(first.playerIn.id, 'p3');
    expect(first.swapLabel, 'Reserve Guard IN · Alpha Guard OUT');
    expect(first.timeLabel, 'Q2 6:30');

    final second = result.swaps.last;
    expect(second.playerOut.id, 'p3');
    expect(second.playerIn.id, 'p1');
  });

  test('does not construct swaps from descriptive text alone', () {
    final result = const NbaGameSubstitutionEngine().build(
      _seed(
        playByPlay: [
          {
            'game_id': 'g1',
            'event_num': 1,
            'event_type': 'substitution',
            'period': 3,
            'clock': '5:00',
            'team_id': 'AAA',
            'description': 'SUB: Reserve Guard FOR Alpha Guard',
          },
        ],
      ),
      gameId: 'g1',
    );

    expect(result.substitutionRows, 1);
    expect(result.swaps, isEmpty);
    expect(result.incompleteSubstitutionRows, 1);
    expect(result.coverageLabel, 'SUBSTITUTION PARTICIPANTS INCOMPLETE');
  });

  test('reports no substitution rows without implying lineup coverage', () {
    final result = const NbaGameSubstitutionEngine().build(
      _seed(playByPlay: const []),
      gameId: 'g1',
    );

    expect(result.confirmedSwapCount, 0);
    expect(result.coverageLabel, 'NO SUBSTITUTION ROWS');
    expect(result.hasConfirmedSwaps, isFalse);
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
        {'player_id': 'p3', 'player_name': 'Reserve Guard', 'team_id': 'AAA'},
      ],
      'games': [
        {
          'game_id': 'g1',
          'season_id': '2025-26',
          'game_date': '2026-03-01',
          'season_type': 'Regular Season',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 100,
          'away_score': 98,
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
              'event_num': 10,
              'event_msg_type': 8,
              'period': 2,
              'clock': '6:30',
              'team_id': 'AAA',
              'player1_id': 'p1',
              'player1_name': 'Alpha Guard',
              'player2_id': 'p3',
              'player2_name': 'Reserve Guard',
            },
            {
              'game_id': 'g1',
              'event_num': 20,
              'event_type': 'substitution',
              'period': 3,
              'clock': '8:00',
              'team_id': 'AAA',
              'player_out_id': 'p3',
              'player_out_name': 'Reserve Guard',
              'player_in_id': 'p1',
              'player_in_name': 'Alpha Guard',
            },
            {
              'game_id': 'g1',
              'event_num': 30,
              'event_type': 'substitution',
              'period': 4,
              'clock': '4:00',
              'team_id': 'AAA',
              'player_out_id': 'p1',
              'player_out_name': 'Alpha Guard',
            },
          ],
      'launch_config': {
        'supportedSeason': '2025-26',
        'datasetStatus': 'test',
      },
      'asset_path': 'test://substitutions',
      'used_fallback': false,
    });
