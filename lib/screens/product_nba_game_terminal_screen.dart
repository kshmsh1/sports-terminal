import 'package:flutter/material.dart';

import '../services/nba_game_intelligence_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../widgets/nba_game_deep_intelligence_panel.dart';
import 'product_nba_game_command_center_screen.dart';

/// Permanent canonical Game route composition. The base Command Center and the
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

class _ProductNbaGameTerminalScreenState extends State<ProductNbaGameTerminalScreen> {
  late Future<NbaTerminalSeedSnapshot> _seedFuture;

  @override
  void initState() {
    super.initState();
    _seedFuture = _load();
  }

  @override
  void didUpdateWidget(ProductNbaGameTerminalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameId != widget.gameId || oldWidget.loadSeed != widget.loadSeed) {
      _seedFuture = _load();
    }
  }

  Future<NbaTerminalSeedSnapshot> _load() =>
      widget.loadSeed?.call() ?? const NbaTerminalSeedRepository().load();

  Future<NbaTerminalSeedSnapshot> _sharedSeed() => _seedFuture;

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
              child: NbaGameDeepIntelligencePanel(
                key: ValueKey('game-deep-intelligence-${game.gameId}'),
                seed: snapshot.data!,
                game: game,
                onOpenGame: widget.onOpenGame,
                onOpenTeam: widget.onOpenTeam,
                onOpenPlayer: widget.onOpenPlayer,
              ),
            );
          },
        ),
      ],
    );
  }
}
