import 'package:flutter/material.dart';

import '../screens/product_nba_player_career_comparison_screen.dart';
import '../services/nba_player_career_comparison_discovery_service.dart';
import '../services/nba_player_career_comparison_loader.dart';
import 'nba_game_navigation.dart';

Future<void> openNbaPlayerCareerComparisonPage(
  BuildContext context, {
  required String leftPlayerKey,
  required String leftPlayerName,
  String rightPlayerKey = '',
  String rightPlayerName = 'Player B',
  String league = 'NBA',
  String initialSeasonType = 'regular',
  NbaPlayerCareerComparisonDossierLoader? loadPlayer,
  NbaPlayerCareerComparisonTeamLoader? loadTeam,
  NbaPlayerComparisonSearchLoader? searchLoader,
  void Function(String playerKey, String playerName)? onOpenPlayer,
  ValueChanged<String>? onOpenSeason,
}) {
  final leftKey = leftPlayerKey.trim();
  if (leftKey.isEmpty) return Future.value();
  final rightKey = rightPlayerKey.trim();
  final normalizedLeague =
      league.trim().isEmpty ? 'NBA' : league.trim().toUpperCase();
  final routeSuffix = rightKey.isEmpty
      ? Uri.encodeComponent(leftKey)
      : '${Uri.encodeComponent(leftKey)}/${Uri.encodeComponent(rightKey)}';

  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(
        name: '/nba/history/player-comparisons/$routeSuffix',
        arguments: {
          'leftPlayerKey': leftKey,
          'rightPlayerKey': rightKey,
          'league': normalizedLeague,
          'seasonType': initialSeasonType,
        },
      ),
      builder: (comparisonContext) {
        final seasonCallback = onOpenSeason ??
            (String seasonId) => openHistoricalNbaSeasonPage(
                  comparisonContext,
                  seasonId: seasonId,
                  league: normalizedLeague,
                  seasonType: initialSeasonType,
                  onOpenPlayer: onOpenPlayer,
                );
        return Scaffold(
          backgroundColor: nbaPlayerCareerComparisonBackground,
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F151C),
            foregroundColor: const Color(0xFFE8EDF3),
            title: Text(
              rightKey.isEmpty
                  ? '${leftPlayerName.trim().isEmpty ? leftKey : leftPlayerName} · Career Compare'
                  : '${leftPlayerName.trim().isEmpty ? leftKey : leftPlayerName} vs ${rightPlayerName.trim().isEmpty ? rightKey : rightPlayerName}',
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1700),
                child: ProductNbaPlayerCareerComparisonScreen(
                  leftPlayerKey: leftKey,
                  leftPlayerName: leftPlayerName,
                  rightPlayerKey: rightKey,
                  rightPlayerName: rightPlayerName,
                  league: normalizedLeague,
                  initialSeasonType: initialSeasonType,
                  loadPlayer: loadPlayer,
                  loadTeam: loadTeam,
                  searchLoader: searchLoader,
                  onOpenPlayer: onOpenPlayer,
                  onOpenSeason: seasonCallback,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
