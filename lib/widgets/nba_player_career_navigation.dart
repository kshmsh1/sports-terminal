import 'package:flutter/material.dart';

import '../screens/product_nba_player_career_screen.dart';
import '../services/nba_entity_intelligence_repository.dart';
import '../services/nba_terminal_seed_repository.dart';
import 'nba_franchise_navigation.dart';
import 'nba_game_navigation.dart';

/// Opens the permanent canonical historical Player career route.
Future<void> openNbaPlayerCareerPage(
  BuildContext context, {
  required String playerKey,
  String playerName = 'NBA Player',
  String league = 'NBA',
  String initialSeasonType = 'regular',
  NbaPlayerCareerPayloadLoader? loadPlayer,
  NbaPlayerCareerTeamDossierLoader? loadTeamDossier,
  ValueChanged<String>? onOpenTeam,
  ValueChanged<String>? onOpenFranchise,
  ValueChanged<String>? onOpenSeason,
  NbaPlayerCareerGameOpenCallback? onOpenGame,
}) {
  final normalizedKey = playerKey.trim();
  if (normalizedKey.isEmpty) return Future.value();
  final normalizedLeague =
      league.trim().isEmpty ? 'NBA' : league.trim().toUpperCase();
  final normalizedName = playerName.trim().isEmpty ? 'NBA Player' : playerName.trim();

  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(
        name: '/nba/history/players/${Uri.encodeComponent(normalizedKey)}',
        arguments: {
          'playerKey': normalizedKey,
          'league': normalizedLeague,
          'seasonType': initialSeasonType,
        },
      ),
      builder: (careerContext) {
        void openCareerPlayer(String key, String name) {
          openNbaPlayerCareerPage(
            careerContext,
            playerKey: key,
            playerName: name,
            league: normalizedLeague,
            onOpenTeam: onOpenTeam,
          );
        }

        final franchiseCallback = onOpenFranchise ??
            (String franchiseKey) => openNbaFranchisePage(
                  careerContext,
                  franchiseKey: franchiseKey,
                  league: normalizedLeague,
                  onOpenTeam: onOpenTeam,
                  onOpenPlayer: openCareerPlayer,
                );
        final seasonCallback = onOpenSeason ??
            (String seasonId) => openHistoricalNbaSeasonPage(
                  careerContext,
                  seasonId: seasonId,
                  league: normalizedLeague,
                  seasonType: 'regular',
                  onOpenTeam: onOpenTeam,
                  onOpenPlayer: openCareerPlayer,
                );
        final gameCallback = onOpenGame ??
            (String gameKey, String gameLabel, String seasonId) {
              if (seasonId.trim().isEmpty) {
                ScaffoldMessenger.maybeOf(careerContext)?.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Historical Game route requires an explicit source-backed season.',
                    ),
                  ),
                );
                return;
              }
              openNbaGamePage(
                careerContext,
                gameId: gameKey,
                gameLabel: gameLabel,
                loadSeed: () => const NbaTerminalSeedRepository().loadHistoricalSeason(
                  seasonId,
                  league: normalizedLeague,
                  seasonType: 'regular',
                ),
                onOpenTeam: onOpenTeam,
                onOpenPlayer: openCareerPlayer,
              );
            };

        return Scaffold(
          backgroundColor: nbaPlayerCareerBackground,
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F151C),
            foregroundColor: const Color(0xFFE8EDF3),
            title: Text('$normalizedName · Career'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: ProductNbaPlayerCareerScreen(
                  playerKey: normalizedKey,
                  playerLabel: normalizedName,
                  league: normalizedLeague,
                  initialSeasonType: initialSeasonType,
                  loadPlayer: loadPlayer,
                  loadTeamDossier: loadTeamDossier,
                  onOpenTeam: onOpenTeam,
                  onOpenFranchise: franchiseCallback,
                  onOpenSeason: seasonCallback,
                  onOpenGame: gameCallback,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Resolves a current-release Player to the canonical historical Player key
/// without assuming that release IDs and historical warehouse keys are equal.
Future<void> openResolvedNbaPlayerCareerPage(
  BuildContext context, {
  required String playerId,
  required String playerName,
  String league = 'NBA',
  ValueChanged<String>? onOpenTeam,
}) async {
  const repository = NbaEntityIntelligenceRepository();
  final normalizedId = playerId.trim();
  final normalizedName = playerName.trim();
  String historicalKey = '';
  String historicalName = normalizedName;

  if (normalizedId.isNotEmpty) {
    try {
      final direct = await repository.playerDossier(
        normalizedId,
        league: league,
        seasonType: 'regular',
        recentGames: 0,
      );
      final profile = _navMap(direct['profile']);
      historicalKey = profile['player_key']?.toString().trim() ?? '';
      historicalName = profile['canonical_name']?.toString().trim().isNotEmpty == true
          ? profile['canonical_name'].toString().trim()
          : historicalName;
    } catch (_) {
      // Release IDs are not assumed to equal historical player keys.
    }
  }

  if (historicalKey.isEmpty && normalizedName.isNotEmpty) {
    try {
      final search = await repository.search(
        normalizedName,
        league: league,
        kinds: const {'player'},
        limitPerKind: 20,
      );
      final groups = _navMap(search['groups']);
      final players = groups['players'];
      if (players is List) {
        final candidates = [
          for (final raw in players)
            if (raw is Map) raw.map((key, value) => MapEntry(key.toString(), value)),
        ];
        Map<String, dynamic>? match;
        for (final candidate in candidates) {
          final candidateKey = candidate['player_key']?.toString().trim() ?? '';
          final candidateNbaId = candidate['nba_id']?.toString().trim() ?? '';
          final candidateName = candidate['canonical_name']?.toString().trim() ?? '';
          if (normalizedId.isNotEmpty &&
              (candidateKey == normalizedId || candidateNbaId == normalizedId)) {
            match = candidate;
            break;
          }
          if (candidateName.toLowerCase() == normalizedName.toLowerCase()) {
            match ??= candidate;
          }
        }
        if (match != null) {
          historicalKey = match['player_key']?.toString().trim() ?? '';
          historicalName = match['canonical_name']?.toString().trim().isNotEmpty == true
              ? match['canonical_name'].toString().trim()
              : historicalName;
        }
      }
    } catch (_) {
      // The caller receives an explicit unavailable state below.
    }
  }

  if (!context.mounted) return;
  if (historicalKey.isEmpty) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          'No canonical historical Player identity was resolved for ${normalizedName.isEmpty ? normalizedId : normalizedName}.',
        ),
      ),
    );
    return;
  }
  await openNbaPlayerCareerPage(
    context,
    playerKey: historicalKey,
    playerName: historicalName,
    league: league,
    onOpenTeam: onOpenTeam,
  );
}

Map<String, dynamic> _navMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}
