import 'package:flutter/material.dart';

import '../screens/product_nba_game_command_center_screen.dart';
import '../screens/product_nba_game_terminal_screen.dart';
import '../screens/product_nba_schedule_screen.dart';
import '../screens/product_nba_season_screen.dart';
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
              key: const ValueKey('open-nba-season'),
              tooltip: 'Open active NBA season',
              onPressed: () => _openActiveSeason(
                routeContext,
                loadSeed: loadSeed,
                onOpenTeam: onOpenTeam,
                onOpenPlayer: onOpenPlayer,
              ),
              icon: const Icon(Icons.calendar_view_month_rounded),
            ),
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
              child: ProductNbaGameTerminalScreen(
                gameId: normalizedId,
                loadSeed: loadSeed,
                onOpenGame: (relatedGameId, relatedGameLabel) => openNbaGamePage(
                  routeContext,
                  gameId: relatedGameId,
                  gameLabel: relatedGameLabel,
                  loadSeed: loadSeed,
                  onOpenTeam: onOpenTeam,
                  onOpenPlayer: onOpenPlayer,
                ),
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
          actions: [
            IconButton(
              key: const ValueKey('schedule-open-nba-season'),
              tooltip: 'Open active NBA season',
              onPressed: () => _openActiveSeason(
                scheduleContext,
                loadSeed: loadSeed,
                onOpenTeam: onOpenTeam,
                onOpenPlayer: onOpenPlayer,
              ),
              icon: const Icon(Icons.calendar_view_month_rounded),
            ),
          ],
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

Future<void> openNbaSeasonPage(
  BuildContext context, {
  required String seasonId,
  Future<NbaTerminalSeedSnapshot> Function()? loadSeed,
  ValueChanged<String>? onOpenTeam,
  NbaGamePlayerOpenCallback? onOpenPlayer,
}) {
  final normalizedSeason = seasonId.trim();
  if (normalizedSeason.isEmpty) return Future.value();

  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(
        name: '/nba/seasons/${Uri.encodeComponent(normalizedSeason)}',
        arguments: {'seasonId': normalizedSeason},
      ),
      builder: (seasonContext) => Scaffold(
        backgroundColor: nbaSeasonBackground,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F151C),
          foregroundColor: const Color(0xFFE8EDF3),
          title: Text('$normalizedSeason NBA Season'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: ProductNbaSeasonScreen(
                seasonId: normalizedSeason,
                loadSeed: loadSeed,
                onOpenTeam: onOpenTeam,
                onOpenPlayer: onOpenPlayer,
                onOpenGame: (gameId, gameLabel) => openNbaGamePage(
                  seasonContext,
                  gameId: gameId,
                  gameLabel: gameLabel,
                  loadSeed: loadSeed,
                  onOpenTeam: onOpenTeam,
                  onOpenPlayer: onOpenPlayer,
                ),
                onOpenSchedule: () => openNbaSchedulePage(
                  seasonContext,
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

/// Opens a permanent historical Season route against the historical seed API.
/// The requested season remains the canonical route identity while its loader
/// is pinned to that same season so current-release rows cannot leak in.
Future<void> openHistoricalNbaSeasonPage(
  BuildContext context, {
  required String seasonId,
  String league = 'NBA',
  String seasonType = 'regular',
  ValueChanged<String>? onOpenTeam,
  NbaGamePlayerOpenCallback? onOpenPlayer,
}) {
  final normalizedSeason = seasonId.trim();
  if (normalizedSeason.isEmpty) return Future.value();
  return openNbaSeasonPage(
    context,
    seasonId: normalizedSeason,
    loadSeed: () => const NbaTerminalSeedRepository().loadHistoricalSeason(
      normalizedSeason,
      league: league,
      seasonType: seasonType,
    ),
    onOpenTeam: onOpenTeam,
    onOpenPlayer: onOpenPlayer,
  );
}

Future<void> _openActiveSeason(
  BuildContext context, {
  Future<NbaTerminalSeedSnapshot> Function()? loadSeed,
  ValueChanged<String>? onOpenTeam,
  NbaGamePlayerOpenCallback? onOpenPlayer,
}) async {
  try {
    final seed = await (loadSeed?.call() ?? const NbaTerminalSeedRepository().load());
    if (!context.mounted || seed.supportedSeason.trim().isEmpty) return;
    await openNbaSeasonPage(
      context,
      seasonId: seed.supportedSeason,
      loadSeed: loadSeed,
      onOpenTeam: onOpenTeam,
      onOpenPlayer: onOpenPlayer,
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Active NBA season is unavailable.')),
    );
  }
}
