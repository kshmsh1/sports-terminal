import 'package:flutter/material.dart';

import '../screens/product_nba_game_command_center_screen.dart';
import '../services/nba_terminal_seed_repository.dart';

/// Opens a canonical NBA game route without coupling the Game Command Center
/// to the player/team page implementation.
///
/// Callers may pass player/team callbacks so existing entity routing remains
/// authoritative at the integration surface rather than creating import cycles.
Future<void> openNbaGamePage(
  BuildContext context, {
  required String gameId,
  String gameLabel = 'NBA Game',
  Future<NbaTerminalSeedSnapshot> Function()? loadSeed,
  ValueChanged<String>? onOpenTeam,
  NbaGamePlayerOpenCallback? onOpenPlayer,
}) {
  final normalizedId = gameId.trim();
  if (normalizedId.isEmpty) return Future.value();

  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(
        name: '/nba/games/${Uri.encodeComponent(normalizedId)}',
        arguments: {'gameId': normalizedId},
      ),
      builder: (_) => Scaffold(
        backgroundColor: const Color(0xFF090D12),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F151C),
          foregroundColor: const Color(0xFFE8EDF3),
          title: Text(gameLabel.trim().isEmpty ? 'NBA Game' : gameLabel.trim()),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: ProductNbaGameCommandCenterScreen(
                gameId: normalizedId,
                loadSeed: loadSeed,
                onOpenTeam: onOpenTeam,
                onOpenPlayer: onOpenPlayer,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
