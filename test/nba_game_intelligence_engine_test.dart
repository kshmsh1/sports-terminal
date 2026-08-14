import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_game_intelligence_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  const engine = NbaGameIntelligenceEngine();

  test('builds a canonical game snapshot from game, team and player rows', () {
    final result = engine.build(seed: _seed(), gameId: 'g-1');

    expect(result.gameId, 'g-1');
    expect(result.awayTeam.abbreviation, 'AWY');
    expect(result.homeTeam.abbreviation, 'HME');
    expect(result.awayScore, 101);
    expect(result.homeScore, 112);
    expect(result.winnerTeamId, 'HME');
    expect(result.coverage.scoreboard, isTrue);
    expect(result.coverage.teamBoxScore, isTrue);
    expect(result.coverage.playerBoxScore, isTrue);
    expect(result.coverage.periodScoring, isTrue);
    expect(result.coverage.usedCompatibilityJoin, isFalse);
    expect(result.playerLines, hasLength(2));
    expect(result.awayPlayers.single.playerName, 'Away Star');
    expect(result.homePlayers.single.points, 31);
    expect(result.provenance.sourceIds, contains('test-source'));
    expect(result.hasBlockingIssue, isFalse);
  });

  test('joins legacy game logs by date and participants when game id is absent', () {
    final seed = _seed(
      teamLogs: [
        {
          'game_date': '2026-01-05T00:00:00Z',
          'team_id': 'AWY',
          'opponent_team_id': 'HME',
          'points': 101,
        },
        {
          'game_date': '2026-01-05',
          'team_id': 'HME',
          'opponent_team_id': 'AWY',
          'points': 112,
        },
      ],
      playerLogs: [
        {
          'game_date': '2026-01-05',
          'team_id': 'HME',
          'opponent_team_id': 'AWY',
          'player_id': 'p-home',
          'player_name': 'Home Star',
          'minutes': '34:30',
          'points': 31,
        },
      ],
    );

    final result = engine.build(seed: seed, gameId: 'g-1');

    expect(result.coverage.usedCompatibilityJoin, isTrue);
    expect(result.coverage.teamBoxScore, isTrue);
    expect(result.homePlayers.single.playerId, 'p-home');
  });

  test('surfaces reconciliation warnings instead of hiding conflicting scores', () {
    final seed = _seed(
      teamLogs: [
        {
          'game_id': 'g-1',
          'team_id': 'AWY',
          'points': 99,
        },
        {
          'game_id': 'g-1',
          'team_id': 'HME',
          'points': 112,
        },
      ],
    );

    final result = engine.build(seed: seed, gameId: 'g-1');

    expect(
      result.integrityIssues.map((issue) => issue.code),
      contains('away-score-mismatch'),
    );
    expect(result.hasBlockingIssue, isFalse);
  });

  test('throws a domain-specific error when the game is outside active scope', () {
    expect(
      () => engine.build(seed: _seed(), gameId: 'missing-game'),
      throwsA(isA<NbaGameNotFoundException>()),
    );
  });
}

NbaTerminalSeedSnapshot _seed({
  List<Map<String, dynamic>>? teamLogs,
  List<Map<String, dynamic>>? playerLogs,
}) {
  return NbaTerminalSeedSnapshot.fromMap({
    'manifest': {
      'warehouseBuild': {
        'generatedAt': '2026-01-06T00:00:00Z',
        'playByPlayEventsNormalized': 50,
      },
    },
    'teams': [
      {
        'team_id': 'AWY',
        'team_name': 'Away Team',
        'abbreviation': 'AWY',
      },
      {
        'team_id': 'HME',
        'team_name': 'Home Team',
        'abbreviation': 'HME',
      },
    ],
    'players': [
      {'player_id': 'p-away', 'player_name': 'Away Star'},
      {'player_id': 'p-home', 'player_name': 'Home Star'},
    ],
    'games': [
      {
        'game_id': 'g-1',
        'game_date': '2026-01-05',
        'season': '2025-26',
        'season_type': 'regular',
        'away_team_id': 'AWY',
        'home_team_id': 'HME',
        'away_score': 101,
        'home_score': 112,
        'status': 'Final',
        'arena': 'Test Arena',
        'source_id': 'test-source',
        'as_of': '2026-01-06T00:00:00Z',
        'periods': [
          {'label': 'Q1', 'away_score': 22, 'home_score': 29},
          {'label': 'Q2', 'away_score': 30, 'home_score': 27},
          {'label': 'Q3', 'away_score': 25, 'home_score': 28},
          {'label': 'Q4', 'away_score': 24, 'home_score': 28},
        ],
      },
    ],
    'team_records': const [],
    'team_game_logs': teamLogs ??
        [
          {
            'game_id': 'g-1',
            'team_id': 'AWY',
            'points': 101,
            'rebounds': 41,
            'assists': 24,
            'turnovers': 13,
          },
          {
            'game_id': 'g-1',
            'team_id': 'HME',
            'points': 112,
            'rebounds': 47,
            'assists': 28,
            'turnovers': 10,
          },
        ],
    'player_season_totals': const [],
    'player_leaders': const {},
    'player_game_highs': const {},
    'player_game_logs_top': playerLogs ??
        [
          {
            'game_id': 'g-1',
            'team_id': 'AWY',
            'player_id': 'p-away',
            'player_name': 'Away Star',
            'minutes': '36:00',
            'points': 27,
            'rebounds': 6,
            'assists': 7,
          },
          {
            'game_id': 'g-1',
            'team_id': 'HME',
            'player_id': 'p-home',
            'player_name': 'Home Star',
            'minutes': '34:30',
            'points': 31,
            'rebounds': 9,
            'assists': 8,
          },
        ],
    'search_index': const [],
    'data_dictionary': const {},
    'validation_report': {'status': 'pass'},
    'release_manifest': {
      'id': 'release-test',
      'version': '1',
      'status': 'certified',
    },
    'standings': const [],
    'launch_config': {
      'supportedSeason': '2025-26',
      'datasetStatus': 'certified',
    },
    'asset_path': 'test://nba-2026',
    'used_fallback': false,
  });
}
