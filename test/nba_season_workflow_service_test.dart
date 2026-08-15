import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/services/nba_season_workflow_service.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('packages canonical season operating rows into shared RoutePayload state', () {
    final payload = const NbaSeasonWorkflowService().package(
      _seed(),
      seasonId: '2025-26',
      targetRoute: 'Workspace',
    );

    expect(payload.sourceObjectType, 'NBA Season');
    expect(payload.sourceObjectId, '2025-26');
    expect(payload.targetRoute, 'Workspace');
    expect(payload.readinessState, 'Ready');
    expect(payload.rowCount, 6);
    expect(payload.rows.first['row_type'], 'standing');
    expect(payload.rows.first['team_id'], 'AAA');
    expect(payload.rows.first['wins'], 1);
    expect(
      payload.rows.where((row) => row['row_type'] == 'game').length,
      2,
    );
    expect(
      payload.rows.where((row) => row['row_type'] == 'rest_density').length,
      2,
    );
    expect(payload.metadata['gameCount'], 2);
    expect(payload.metadata['completedGames'], 1);
    expect(payload.metadata['scheduledGames'], 1);
    expect(payload.metadata['standingRows'], 2);
    expect(payload.metadata['gameRows'], 2);
    expect(payload.metadata['leaderRows'], 0);
    expect(payload.metadata['restDensityRows'], 2);
  });

  test('season export preserves scheduled games without inventing scores', () {
    final payload = const NbaSeasonWorkflowService().package(
      _seed(),
      seasonId: '2025-26',
      targetRoute: 'Workspace',
    );
    final scheduled = payload.rows.firstWhere(
      (row) => row['row_type'] == 'game' && row['game_id'] == 'g2',
    );

    expect(scheduled['status'], 'Scheduled');
    expect(scheduled['home_score'], isNull);
    expect(scheduled['away_score'], isNull);
  });

  test('season type remains an explicit workflow filter', () {
    final payload = const NbaSeasonWorkflowService().package(
      _seed(includePlayoff: true),
      seasonId: '2025-26',
      seasonType: 'Playoffs',
      targetRoute: 'Python Lab',
    );

    expect(payload.targetRoute, 'Python Lab');
    expect(payload.filterSummary, contains('season_type=Playoffs'));
    expect(payload.metadata['playoffGames'], 1);
    expect(payload.rows.first['season_type'], 'Playoffs');
    expect(payload.metadata['gameRows'], 1);
  });

  test('empty season scope is partial instead of fabricating operating rows', () {
    final payload = const NbaSeasonWorkflowService().package(
      _seed(),
      seasonId: '2099-00',
      targetRoute: 'Source Audit',
    );

    expect(payload.readinessState, 'Partial');
    expect(payload.rows, isEmpty);
    expect(payload.metadata['gameCount'], 0);
    expect(payload.metadata['teamCount'], 0);
  });

  test('canonical Season watch identity persists exact season and filter', () async {
    const workflows = NbaSeasonWorkflowService();
    final seed = _seed();

    expect(
      await workflows.isWatched(
        seed,
        seasonId: '2025-26',
        seasonType: 'Regular Season',
      ),
      isFalse,
    );
    expect(
      await workflows.toggleWatch(
        seed,
        seasonId: '2025-26',
        seasonType: 'Regular Season',
      ),
      isTrue,
    );
    expect(
      await workflows.isWatched(
        seed,
        seasonId: '2025-26',
        seasonType: 'Regular Season',
      ),
      isTrue,
    );
    expect(
      await workflows.isWatched(
        seed,
        seasonId: '2025-26',
        seasonType: 'Playoffs',
      ),
      isFalse,
    );
  });

  test('historical Season research activates exact historical season and type', () async {
    const workflows = NbaSeasonWorkflowService();
    final context = await workflows.activateResearch(
      _seed(historical: true),
      seasonId: '1985-86',
      seasonType: 'Playoffs',
    );

    expect(context.historical, isTrue);
    expect(context.season, '1985-86');
    expect(context.seasonType, 'playoffs');
    expect(context.league, 'NBA');
  });

  test('current Season research never silently flips into historical mode', () async {
    const workflows = NbaSeasonWorkflowService();
    final context = await workflows.activateResearch(
      _seed(),
      seasonId: '2025-26',
      seasonType: 'Regular Season',
    );

    expect(context.historical, isFalse);
  });
}

NbaTerminalSeedSnapshot _seed({
  bool includePlayoff = false,
  bool historical = false,
}) {
  final seasonId = historical ? '1985-86' : '2025-26';
  final games = <Map<String, dynamic>>[
    {
      'game_id': 'g1',
      'season_id': seasonId,
      'game_date': historical ? '1986-01-01' : '2026-01-01',
      'season_type': 'Regular Season',
      'home_team_id': 'AAA',
      'away_team_id': 'BBB',
      'home_score': 110,
      'away_score': 100,
      'status': 'Final',
    },
    {
      'game_id': 'g2',
      'season_id': seasonId,
      'game_date': historical ? '1986-01-05' : '2026-01-05',
      'season_type': 'Regular Season',
      'home_team_id': 'BBB',
      'away_team_id': 'AAA',
      'status': 'Scheduled',
    },
  ];
  if (includePlayoff) {
    games.add({
      'game_id': 'p1',
      'season_id': seasonId,
      'game_date': historical ? '1986-04-20' : '2026-04-20',
      'season_type': 'Playoffs',
      'home_team_id': 'AAA',
      'away_team_id': 'BBB',
      'home_score': 108,
      'away_score': 101,
      'status': 'Final',
    });
  }
  return NbaTerminalSeedSnapshot.fromMap({
    'manifest': const {},
    'teams': [
      {'team_id': 'AAA', 'team_name': 'Alpha', 'abbreviation': 'AAA'},
      {'team_id': 'BBB', 'team_name': 'Beta', 'abbreviation': 'BBB'},
    ],
    'players': const [],
    'games': games,
    'team_records': const [],
    'team_game_logs': const [],
    'player_season_totals': const [],
    'player_leaders': const {},
    'player_game_highs': const {},
    'player_game_logs_top': const [],
    'search_index': const [],
    'data_dictionary': const {},
    'validation_report': {'status': 'pass'},
    'release_manifest': {
      'status': historical ? 'historical-canonical' : 'test',
    },
    'standings': const [],
    'launch_config': {
      'supportedSeason': seasonId,
      'datasetStatus': historical ? 'historical-canonical' : 'test',
    },
    'asset_path': historical
        ? 'backend://v2/nba/history/$seasonId'
        : 'test://season-workflow',
    'used_fallback': false,
  });
}
