import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_game_log_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  const engine = NbaPlayerGameLogEngine();

  test('joins player logs to canonical games and derives matchup context', () {
    final result = engine.build(
      _seed(),
      playerId: 'p1',
      seasonType: 'Regular Season',
    );

    expect(result.rows, hasLength(2));
    expect(result.linkedRows, 2);
    expect(result.unlinkedRows, 0);
    expect(result.completedRows, 2);

    final latest = result.rows.first;
    expect(latest.gameId, 'g2');
    expect(latest.gameDate, '2026-01-20');
    expect(latest.team.id, 'AAA');
    expect(latest.opponent.id, 'CCC');
    expect(latest.location, NbaPlayerGameLocation.away);
    expect(latest.matchupLabel, '@ CCC');
    expect(latest.resultLabel, 'L 98–103');
    expect(latest.points, 31);
    expect(latest.assists, 8);
  });

  test('separates regular season and playoffs without combining them', () {
    final regular = engine.build(
      _seed(),
      playerId: 'p1',
      seasonType: 'regular',
    );
    final playoffs = engine.build(
      _seed(),
      playerId: 'p1',
      seasonType: 'playoffs',
    );

    expect(regular.rows.map((row) => row.gameId), ['g2', 'g1']);
    expect(playoffs.rows.map((row) => row.gameId), ['g3']);
  });

  test('compatibility joins legacy logs by date and participants', () {
    final seed = _seed(extraLogs: [
      {
        'player_id': 'p2',
        'player_name': 'Legacy Wing',
        'team_id': 'BBB',
        'opponent_team_id': 'AAA',
        'game_date': '2026-01-15',
        'points': 19,
      },
    ]);

    final result = engine.build(seed, playerId: 'p2');

    expect(result.rows, hasLength(1));
    expect(result.rows.single.gameId, 'g1');
    expect(result.rows.single.linkedCanonicalGame, isTrue);
    expect(result.rows.single.matchupLabel, '@ AAA');
  });

  test('preserves unlinked log rows instead of fabricating games', () {
    final seed = _seed(extraLogs: [
      {
        'player_id': 'p3',
        'player_name': 'Unlinked Center',
        'team_id': 'DDD',
        'game_date': '2026-02-01',
        'points': 14,
        'rebounds': 12,
      },
    ]);

    final result = engine.build(seed, playerId: 'p3');

    expect(result.rows, hasLength(1));
    expect(result.rows.single.gameId, isEmpty);
    expect(result.rows.single.linkedCanonicalGame, isFalse);
    expect(result.unlinkedRows, 1);
    expect(result.rows.single.points, 14);
    expect(result.rows.single.rebounds, 12);
  });
}

NbaTerminalSeedSnapshot _seed({List<Map<String, dynamic>> extraLogs = const []}) =>
    NbaTerminalSeedSnapshot.fromMap({
      'manifest': const {},
      'teams': [
        {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
        {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
        {'team_id': 'CCC', 'team_name': 'Gamma', 'abbreviation': 'CCC'},
        {'team_id': 'DDD', 'team_name': 'Delta', 'abbreviation': 'DDD'},
      ],
      'players': const [],
      'games': [
        {
          'game_id': 'g1',
          'season_id': '2025-26',
          'game_date': '2026-01-15',
          'season_type': 'regular',
          'status': 'Final',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 110,
          'away_score': 105,
          'source_id': 'games',
        },
        {
          'game_id': 'g2',
          'season_id': '2025-26',
          'game_date': '2026-01-20',
          'season_type': 'Regular Season',
          'status': 'Final',
          'home_team_id': 'CCC',
          'away_team_id': 'AAA',
          'home_score': 103,
          'away_score': 98,
          'source_id': 'games',
        },
        {
          'game_id': 'g3',
          'season_id': '2025-26',
          'game_date': '2026-04-20',
          'season_type': 'Playoffs',
          'status': 'Final',
          'home_team_id': 'AAA',
          'away_team_id': 'BBB',
          'home_score': 115,
          'away_score': 109,
          'source_id': 'games',
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
          'player_name': 'Example Guard',
          'team_id': 'AAA',
          'minutes': '34:00',
          'points': 24,
          'rebounds': 5,
          'assists': 7,
          'source_id': 'box',
        },
        {
          'game_id': 'g2',
          'player_id': 'p1',
          'player_name': 'Example Guard',
          'team_id': 'AAA',
          'minutes': '38:00',
          'points': 31,
          'rebounds': 4,
          'assists': 8,
          'source_id': 'box',
        },
        {
          'game_id': 'g3',
          'player_id': 'p1',
          'player_name': 'Example Guard',
          'team_id': 'AAA',
          'minutes': '40:00',
          'points': 28,
          'rebounds': 6,
          'assists': 9,
          'source_id': 'box',
        },
        ...extraLogs,
      ],
      'search_index': const [],
      'data_dictionary': const {},
      'validation_report': {'status': 'pass'},
      'release_manifest': {'id': 'test-release'},
      'standings': const [],
      'launch_config': {
        'supportedSeason': '2025-26',
        'datasetStatus': 'test',
      },
      'asset_path': 'test://player-game-log',
      'used_fallback': false,
    });
