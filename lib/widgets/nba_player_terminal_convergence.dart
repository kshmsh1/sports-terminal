import 'package:flutter/material.dart';

import 'nba_player_career_navigation.dart';

/// One terminal-level entrypoint for opening an NBA Player regardless of
/// whether the caller holds a current-release ID or a canonical historical key.
/// Provider/release identifiers are never silently treated as historical keys.
Future<void> openCanonicalNbaPlayerFromTerminal(
  BuildContext context, {
  required String playerName,
  String currentPlayerId = '',
  String historicalPlayerKey = '',
  String league = 'NBA',
  ValueChanged<String>? onOpenTeam,
}) {
  final historical = historicalPlayerKey.trim();
  if (historical.isNotEmpty) {
    return openNbaPlayerCareerPage(
      context,
      playerKey: historical,
      playerName: playerName,
      league: league,
      onOpenTeam: onOpenTeam,
    );
  }

  final current = currentPlayerId.trim();
  if (current.isEmpty) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'Canonical Player route requires a historical key or a resolvable current Player ID.',
        ),
      ),
    );
    return Future.value();
  }

  return openResolvedNbaPlayerCareerPage(
    context,
    playerId: current,
    playerName: playerName,
    league: league,
    onOpenTeam: onOpenTeam,
  );
}

class NbaPlayerTerminalReference {
  const NbaPlayerTerminalReference({
    required this.playerName,
    this.currentPlayerId = '',
    this.historicalPlayerKey = '',
    this.league = 'NBA',
  });

  final String playerName;
  final String currentPlayerId;
  final String historicalPlayerKey;
  final String league;

  bool get canOpen =>
      historicalPlayerKey.trim().isNotEmpty || currentPlayerId.trim().isNotEmpty;

  String get canonicalIntent => historicalPlayerKey.trim().isNotEmpty
      ? 'historical:${historicalPlayerKey.trim()}'
      : 'resolve-current:${currentPlayerId.trim()}';
}
