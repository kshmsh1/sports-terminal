import 'package:flutter/material.dart';

import '../screens/product_nba_game_command_center_screen.dart';
import '../screens/product_nba_schedule_screen.dart';
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
      builder: (routeContext) => Scaffold(
        backgroundColor: const Color(0xFF090D12),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F151C),
          foregroundColor: const Color(0xFFE8EDF3),
          title: Text(gameLabel.trim().isEmpty ? 'NBA Game' : gameLabel.trim()),
          actions: [
            IconButton(
              key: const ValueKey('open-nba-schedule'),
              tooltip: 'Open NBA Schedule',
              onPressed: () => openNbaSchedulePage(
                routeContext,
                loadSeed: loadSeed,
                onOpenTeam: onOpenTeam,
                onOpenPlayer: onOpenPlayer,
              ),
              icon: const Icon(Icons.calendar_month_rounded),
            ),
          ],
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

/// Opens the first-class NBA schedule workspace from any surface that already
/// participates in canonical game navigation.
///
/// Optional initial constraints are carried as route arguments and initialized
/// into visible schedule controls so a team/game/search handoff is inspectable
/// and reversible by the user rather than hidden in navigation state.
Future<void> openNbaSchedulePage(
  BuildContext context, {
  Future<NbaTerminalSeedSnapshot> Function()? loadSeed,
  ValueChanged<String>? onOpenTeam,
  NbaGamePlayerOpenCallback? onOpenPlayer,
  String initialTeamId = 'All',
  String initialQuery = '',
  String initialSeasonType = 'All',
  bool initialAscending = true,
}) {
  final team = initialTeamId.trim().isEmpty ? 'All' : initialTeamId.trim();
  final query = initialQuery.trim();
  final seasonType =
      initialSeasonType.trim().isEmpty ? 'All' : initialSeasonType.trim();

  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(
        name: '/nba/schedule',
        arguments: {
          'teamId': team,
          'query': query,
          'seasonType': seasonType,
          'ascending': initialAscending,
        },
      ),
      builder: (scheduleContext) => Scaffold(
        backgroundColor: const Color(0xFF090D12),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F151C),
          foregroundColor: const Color(0xFFE8EDF3),
          title: Text(team == 'All' ? 'NBA Schedule' : '$team Schedule'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: ProductNbaScheduleScreen(
                loadSeed: loadSeed,
                initialTeamId: team,
                initialQuery: query,
                initialSeasonType: seasonType,
                initialAscending: initialAscending,
                onOpenTeam: onOpenTeam,
                onOpenGame: (gameId, gameLabel) => openNbaGamePage(
                  scheduleContext,
                  gameId: gameId,
                  gameLabel: gameLabel,
                  loadSeed: loadSeed,
                  onOpenTeam: onOpenTeam,
                  onOpenPlayer: onOpenPlayer,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
