import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/controllers/route_payload_controller.dart';
import 'package:sports_terminal/services/nba_game_intelligence_engine.dart';
import 'package:sports_terminal/services/nba_game_workflow_service.dart';
import 'package:sports_terminal/services/nba_research_context_store.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('routes a canonical game into shared RoutePayload state', () {
    final game = _game(_seed());
    final controller = RoutePayloadController();
    const workflows = NbaGameWorkflowService();

    final payload = workflows.route(
      controller,
      game: game,
      targetRoute: 'Python Lab',
    );

    expect(controller.activePayload, same(payload));
    expect(payload.sourceObjectType, 'NBA Game');
    expect(payload.sourceObjectId, 'game-1');
    expect(payload.targetRoute, 'Python Lab');
    expect(controller.lastOrigin, contains('game-1'));
    expect(controller.history, hasLength(1));
  });

  test('rejects a route outside the terminal RoutePayload contract', () {
    final game = _game(_seed());
    final controller = RoutePayloadController();
    const workflows = NbaGameWorkflowService();

    expect(
      () => workflows.route(
        controller,
        game: game,
        targetRoute: 'Made Up Destination',
      ),
      throwsArgumentError,
    );
  });

  test('activates current game research context without changing to history', () async {
    final game = _game(_seed());
    const workflows = NbaGameWorkflowService();

    final context = await workflows.activateResearch(game);

    expect(context.historical, isFalse);
    expect(context.gameKey, 'game-1');
    final loaded = await const NbaResearchContextStore().load();
    expect(loaded.gameKey, 'game-1');
    expect(loaded.historical, isFalse);
  });

  test('activates historical game with season and game identity preserved', () async {
    final game = _game(_seed(historical: true));
    const workflows = NbaGameWorkflowService();

    final context = await workflows.activateResearch(game);

    expect(context.historical, isTrue);
    expect(context.season, '2025-26');
    expect(context.gameKey, 'game-1');
    expect(context.seasonType, 'regular');
  });

  test('toggles the canonical game in the shared entity watchlist', () async {
    final game = _game(_seed());
    const workflows = NbaGameWorkflowService();

    expect(await workflows.isWatched(game), isFalse);
    expect(await workflows.toggleWatch(game), isTrue);
    expect(await workflows.isWatched(game), isTrue);
    expect(await workflows.toggleWatch(game), isFalse);
    expect(await workflows.isWatched(game), isFalse);
  });
}

NbaGameIntelligenceSnapshot _game(NbaTerminalSeedSnapshot seed) =>
    const NbaGameIntelligenceEngine().build(seed: seed, gameId: 'game-1');

NbaTerminalSeedSnapshot _seed({bool historical = false}) {
  return NbaTerminalSeedSnapshot.fromMap({
    'manifest': const {},
    'teams': [
      {'team_id': 'AWY', 'team_name': 'Away Team', 'abbreviation': 'AWY'},
      {'team_id': 'HME', 'team_name': 'Home Team', 'abbreviation': 'HME'},
    ],
    'players': const [],
    'games': [
      {
        'game_id': 'game-1',
        'game_date': '2026-01-05',
        'season': '2025-26',
        'season_type': 'regular',
        'away_team_id': 'AWY',
        'home_team_id': 'HME',
        'away_score': 101,
        'home_score': 112,
        'status': 'Final',
        'source_id': 'test-source',
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
    'release_manifest': {
      'id': historical ? 'historical-test' : 'release-test',
      'version': '1',
      'status': historical ? 'historical-canonical' : 'certified',
    },
    'standings': const [],
    'launch_config': {'supportedSeason': '2025-26', 'datasetStatus': 'certified'},
    'asset_path': historical ? 'backend://v2/nba/history/2025-26' : 'test://nba-2026',
    'used_fallback': false,
  });
}
