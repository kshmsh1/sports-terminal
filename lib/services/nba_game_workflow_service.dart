import '../controllers/route_payload_controller.dart';
import '../models/route_payload.dart';
import 'nba_entity_watchlist_store.dart';
import 'nba_game_intelligence_engine.dart';
import 'nba_research_context_store.dart';
import 'sports_object_router.dart';

/// Coordinates cross-product actions for one canonical NBA game.
///
/// This service intentionally owns workflow orchestration rather than sports
/// data assembly. [NbaGameIntelligenceEngine] remains the source of truth for
/// the game object, while this layer routes that object into shared terminal
/// state, research context, and the entity watchlist.
class NbaGameWorkflowService {
  const NbaGameWorkflowService({
    SportsObjectRouter router = const SportsObjectRouter(),
    NbaResearchContextStore contextStore = const NbaResearchContextStore(),
    NbaEntityWatchlistStore watchlistStore = const NbaEntityWatchlistStore(),
  })  : _router = router,
        _contextStore = contextStore,
        _watchlistStore = watchlistStore;

  final SportsObjectRouter _router;
  final NbaResearchContextStore _contextStore;
  final NbaEntityWatchlistStore _watchlistStore;

  RoutePayload route(
    RoutePayloadController controller, {
    required NbaGameIntelligenceSnapshot game,
    required String targetRoute,
  }) {
    final normalizedTarget = targetRoute.trim();
    if (!immediateRouteTargets.contains(normalizedTarget)) {
      throw ArgumentError.value(
        targetRoute,
        'targetRoute',
        'Unsupported Sports Terminal route target.',
      );
    }
    final payload = _router.packageGame(
      game: game,
      targetRoute: normalizedTarget,
    );
    controller.setActivePayload(
      payload,
      origin: 'NBA Game Command Center · ${game.gameId}',
    );
    return payload;
  }

  Future<NbaResearchContext> activateResearch(
    NbaGameIntelligenceSnapshot game,
  ) async {
    if (game.provenance.historicalContext) {
      if (game.seasonId.trim().isEmpty) {
        throw StateError(
          'Historical game ${game.gameId} cannot be activated without a season.',
        );
      }
      return _contextStore.activateHistorical(
        season: game.seasonId,
        league: 'NBA',
        seasonType: _normalizedSeasonType(game.seasonType),
        gameKey: game.gameId,
      );
    }

    final context = NbaResearchContext(
      scope: 'current',
      gameKey: game.gameId,
      updatedAt: DateTime.now().toUtc(),
    );
    await _contextStore.restore(context);
    return _contextStore.load();
  }

  NbaEntityWatchItem watchItem(NbaGameIntelligenceSnapshot game) {
    final away = _teamLabel(game.awayTeam);
    final home = _teamLabel(game.homeTeam);
    final details = <String>[
      if (game.gameDate.trim().isNotEmpty) game.gameDate.trim(),
      if (game.status.trim().isNotEmpty) game.status.trim(),
    ];
    return NbaEntityWatchItem(
      kind: 'game',
      key: game.gameId,
      label: '$away @ $home',
      subtitle: details.join(' · '),
      season: game.seasonId,
      league: 'NBA',
      seasonType: _normalizedSeasonType(game.seasonType),
    );
  }

  Future<bool> isWatched(NbaGameIntelligenceSnapshot game) =>
      _watchlistStore.contains(watchItem(game).signature);

  Future<bool> toggleWatch(NbaGameIntelligenceSnapshot game) async {
    final item = watchItem(game);
    final next = await _watchlistStore.toggle(item);
    return next.any((candidate) => candidate.signature == item.signature);
  }

  String _normalizedSeasonType(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    if (normalized.contains('playoff') || normalized.contains('postseason')) {
      return 'playoffs';
    }
    if (normalized.contains('preseason')) return 'preseason';
    if (normalized.contains('all_star') || normalized.contains('all star')) {
      return 'all_star';
    }
    return 'regular';
  }

  String _teamLabel(NbaGameTeam team) {
    if (team.abbreviation.trim().isNotEmpty) return team.abbreviation.trim();
    if (team.name.trim().isNotEmpty) return team.name.trim();
    return team.id.trim().isEmpty ? 'Unknown' : team.id.trim();
  }
}
