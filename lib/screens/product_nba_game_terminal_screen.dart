import 'package:flutter/material.dart';

import '../controllers/route_payload_controller.dart';
import '../services/nba_game_event_batch_route_service.dart';
import '../services/nba_game_event_query_engine.dart';
import '../services/nba_game_intelligence_engine.dart';
import '../services/nba_game_play_by_play_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/sports_object_router.dart';
import '../widgets/nba_game_deep_intelligence_panel.dart';
import '../widgets/nba_game_event_batch_export_panel.dart';
import '../widgets/nba_game_event_explorer_panel.dart';
import '../widgets/nba_game_event_intelligence_panel.dart';
import '../widgets/nba_game_event_profile_panel.dart';
import 'product_nba_game_command_center_screen.dart';

/// Permanent canonical Game route composition. The base Command Center and all
/// deeper event/context intelligence share one seed future so provenance and
/// scope cannot drift between sections.
class ProductNbaGameTerminalScreen extends StatefulWidget {
  const ProductNbaGameTerminalScreen({
    super.key,
    required this.gameId,
    this.loadSeed,
    this.onOpenGame,
    this.onOpenTeam,
    this.onOpenPlayer,
  });

  final String gameId;
  final Future<NbaTerminalSeedSnapshot> Function()? loadSeed;
  final void Function(String gameId, String gameLabel)? onOpenGame;
  final ValueChanged<String>? onOpenTeam;
  final NbaGamePlayerOpenCallback? onOpenPlayer;

  @override
  State<ProductNbaGameTerminalScreen> createState() =>
      _ProductNbaGameTerminalScreenState();
}

class _ProductNbaGameTerminalScreenState
    extends State<ProductNbaGameTerminalScreen> {
  late Future<NbaTerminalSeedSnapshot> _seedFuture;

  @override
  void initState() {
    super.initState();
    _seedFuture = _load();
  }

  @override
  void didUpdateWidget(ProductNbaGameTerminalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameId != widget.gameId ||
        oldWidget.loadSeed != widget.loadSeed) {
      _seedFuture = _load();
    }
  }

  Future<NbaTerminalSeedSnapshot> _load() =>
      widget.loadSeed?.call() ?? const NbaTerminalSeedRepository().load();

  Future<NbaTerminalSeedSnapshot> _sharedSeed() => _seedFuture;

  void _routeEvent(
    NbaGameIntelligenceSnapshot game,
    NbaGamePlayByPlayEvent event,
    String targetRoute,
  ) {
    final controller = RoutePayloadScope.maybeOf(context);
    if (controller == null) {
      _notice('Shared RoutePayload state is unavailable in this shell.');
      return;
    }
    try {
      final payload = const SportsObjectRouter().packageGameEvent(
        game: game,
        event: event,
        targetRoute: targetRoute,
      );
      controller.setActivePayload(
        payload,
        origin:
            'NBA Game Event Explorer · ${game.gameId} · ${event.sequence ?? 'unsequenced'}',
      );
      _notice('${payload.displayLabel} routed to $targetRoute.');
    } catch (error) {
      _notice('Unable to route event: $error');
    }
  }

  void _routeEventSelection(
    NbaGameIntelligenceSnapshot game,
    NbaGameEventQueryResult result,
    String targetRoute,
  ) {
    final controller = RoutePayloadScope.maybeOf(context);
    if (controller == null) {
      _notice('Shared RoutePayload state is unavailable in this shell.');
      return;
    }
    try {
      final payload = const NbaGameEventBatchRouteService().package(
        game: game,
        result: result,
        targetRoute: targetRoute,
      );
      controller.setActivePayload(
        payload,
        origin:
            'NBA Game Event Explorer Batch · ${game.gameId} · ${result.matchedEvents} events',
      );
      _notice('${result.matchedEvents} events routed to $targetRoute.');
    } catch (error) {
      _notice('Unable to route event selection: $error');
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductNbaGameCommandCenterScreen(
          gameId: widget.gameId,
          loadSeed: _sharedSeed,
          onOpenTeam: widget.onOpenTeam,
          onOpenPlayer: widget.onOpenPlayer,
        ),
        FutureBuilder<NbaTerminalSeedSnapshot>(
          future: _seedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                snapshot.hasError ||
                snapshot.data == null) {
              return const SizedBox.shrink();
            }

            NbaGameIntelligenceSnapshot game;
            try {
              game = const NbaGameIntelligenceEngine().build(
                seed: snapshot.data!,
                gameId: widget.gameId,
              );
            } catch (_) {
              // The base Command Center owns canonical missing/error states.
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NbaGameDeepIntelligencePanel(
                    key: ValueKey('game-deep-intelligence-${game.gameId}'),
                    seed: snapshot.data!,
                    game: game,
                    onOpenGame: widget.onOpenGame,
                    onOpenTeam: widget.onOpenTeam,
                    onOpenPlayer: widget.onOpenPlayer,
                  ),
                  const SizedBox(height: 12),
                  NbaGameEventIntelligencePanel(
                    key: ValueKey(
                      'game-event-intelligence-panel-${game.gameId}',
                    ),
                    seed: snapshot.data!,
                    game: game,
                    onOpenTeam: widget.onOpenTeam,
                    onOpenPlayer: widget.onOpenPlayer,
                  ),
                  const SizedBox(height: 12),
                  NbaGameEventProfilePanel(
                    key: ValueKey('game-event-profile-panel-${game.gameId}'),
                    seed: snapshot.data!,
                    game: game,
                    onOpenTeam: widget.onOpenTeam,
                    onOpenPlayer: widget.onOpenPlayer,
                  ),
                  const SizedBox(height: 12),
                  NbaGameEventBatchExportPanel(
                    key: ValueKey('game-event-batch-panel-${game.gameId}'),
                    seed: snapshot.data!,
                    game: game,
                    onRouteSelection: (result, targetRoute) =>
                        _routeEventSelection(game, result, targetRoute),
                  ),
                  const SizedBox(height: 12),
                  NbaGameEventExplorerPanel(
                    key: ValueKey('game-event-explorer-panel-${game.gameId}'),
                    seed: snapshot.data!,
                    game: game,
                    onOpenTeam: widget.onOpenTeam,
                    onOpenPlayer: widget.onOpenPlayer,
                    onRouteEvent: (event, targetRoute) =>
                        _routeEvent(game, event, targetRoute),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
