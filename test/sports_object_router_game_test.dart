import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_game_intelligence_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';
import 'package:sports_terminal/services/sports_object_router.dart';

void main() {
  const gameEngine = NbaGameIntelligenceEngine();
  const router = SportsObjectRouter();

  test('packages a complete canonical game for terminal destinations', () {
    final game = gameEngine.build(seed: _seed(), gameId: 'g1');
    final payload = router.packageGame(game: game, targetRoute: 'Python Lab');

    expect(payload.sourceObjectType, 'NBA Game');
    expect(payload.sourceObjectId, 'g1');
    expect(payload.displayLabel, contains('BBB @ AAA'));
    expect(payload.targetRoute, 'Python Lab');
    expect(payload.readinessState, 'Ready');
    expect(payload.blockers, isEmpty);
    expect(payload.selectedRows, ['g1']);
    expect(payload.rows, hasLength(1));
    expect(payload.rows.single['home_score'], 110);
    expect(payload.rows.single['away_score'], 105);
    expect(payload.rows.single['winner_team_id'], 'AAA');
    expect(payload.rows.single['player_lines'], 1);
    expect(payload.rows.single['periods'], 2);
    expect(payload.metadata['datasetId'], 'nba_game_g1');
    expect(payload.metadata['releaseId'], 'release-1');
    expect(payload.metadata['missingSections'], isEmpty);
    expect(router.pythonVariableName(payload), 'nba_game_g1');
    expect(router.toTsv(payload), contains('game_id'));
  });

  test('marks incomplete-but-usable game packages as partial', () {
    final game = gameEngine.build(
      seed: _seed(
        teamGameLogs: const [],
        playerGameLogs: const [],
        includePeriods: false,
      ),
      gameId: 'g1',
    );
    final payload = router.packageGame(game: game);

    expect(payload.readinessState, 'Partial');
    expect(payload.blockers, isEmpty);
    expect(
      payload.metadata['missingSections'],
      containsAll(['team-box-score', 'player-box-score', 'period-scoring']),
    );
  });

  test('surfaces blocking game integrity failures in the route package', () {
    final game = gameEngine.build(
      seed: _seed(homeTeamId: 'AAA', awayTeamId: 'AAA'),
      gameId: 'g1',
    );
    final payload = router.packageGame(game: game);

    expect(payload.readinessState, 'Blocked');
    expect(payload.blockers, contains('same-team-game'));
    expect(payload.metadata['integrityBlockers'], contains('same-team-game'));
  });
}

NbaTerminalSeedSnapshot _seed({
  String homeTeamId = 'AAA',
  String awayTeamId = 'BBB',
  List<Map<String, dynamic>>? teamGameLogs,
  List<Map<String, dynamic>>? playerGameLogs,
  bool includePeriods = true,
}) {
  return NbaTerminalSeedSnapshot.fromMap({
    'manifest': {
      'source': 'Sports Terminal test release',
      'warehouseBuild': {'generatedAt': '2026-08-14T00:00:00Z'},
    },
    'teams': [
      {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
      {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
    ],
    'players': [
      {
        'player_id': 'p1',
        'player_name': 'Example Guard',
        'team_id': 'AAA',
      },
    ],
    'games': [
      {
        'game_id': 'g1',
        'season_id': '2025-26',
        'season_type': 'regular',
        'game_date': '2026-01-15',
        'home_team_id': homeTeamId,
        'away_team_id': awayTeamId,
        'home_score': 110,
        'away_score': 105,
        'status': 'Final',
        'arena': 'Terminal Arena',
        'city': 'Chicago',
        'source_id': 'source-games',
        'as_of': '2026-01-16T00:00:00Z',
        if (includePeriods)
          'periods': [
            {'label': 'Q1', 'home_score': 28, 'away_score': 25},
            {'label': 'Q2', 'home_score': 27, 'away_score': 24},
          ],
      },
    ],
    'team_records': const [],
    'team_game_logs': teamGameLogs ??
        [
          {
            'game_id': 'g1',
            'team_id': 'AAA',
            'opponent_team_id': 'BBB',
            'points': 110,
            'source_id': 'source-team-box',
          },
          {
            'game_id': 'g1',
            'team_id': 'BBB',
            'opponent_team_id': 'AAA',
            'points': 105,
            'source_id': 'source-team-box',
          },
        ],
    'player_season_totals': const [],
    'player_leaders': const {},
    'player_game_highs': const {},
    'player_game_logs_top': playerGameLogs ??
        [
          {
            'game_id': 'g1',
            'player_id': 'p1',
            'player_name': 'Example Guard',
            'team_id': 'AAA',
            'minutes': '34:12',
            'points': 24,
            'rebounds': 5,
            'assists': 8,
            'source_id': 'source-player-box',
          },
        ],
    'search_index': const [],
    'data_dictionary': const {},
    'validation_report': {'status': 'pass', 'dataset': 'nba-test'},
    'release_manifest': {
      'id': 'release-1',
      'version': '1.0.0',
      'status': 'certified',
    },
    'standings': const [],
    'launch_config': {
      'supportedSeason': '2025-26',
      'datasetStatus': 'certified-test',
    },
    'asset_path': 'test://nba/release-1',
    'used_fallback': false,
  });
}
