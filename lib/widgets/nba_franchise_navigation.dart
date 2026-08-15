import 'package:flutter/material.dart';

import '../screens/product_nba_franchise_screen.dart';
import 'nba_game_navigation.dart';

/// Opens the permanent canonical historical NBA Franchise route.
///
/// The route identity is the canonical franchise key. Team/Player callbacks are
/// supplied by the caller so Franchise remains decoupled from public page
/// implementations and can be reused from Terminal, Team, research, or tests.
Future<void> openNbaFranchisePage(
  BuildContext context, {
  required String franchiseKey,
  String franchiseName = 'NBA Franchise',
  String league = 'NBA',
  NbaFranchisePayloadLoader? loadFranchise,
  NbaFranchiseTeamDossierLoader? loadTeamDossier,
  ValueChanged<String>? onOpenTeam,
  NbaFranchisePlayerOpenCallback? onOpenPlayer,
}) {
  final normalizedKey = franchiseKey.trim();
  if (normalizedKey.isEmpty) return Future.value();
  final normalizedLeague = league.trim().isEmpty ? 'NBA' : league.trim().toUpperCase();

  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(
        name: '/nba/franchises/${Uri.encodeComponent(normalizedKey)}',
        arguments: {
          'franchiseKey': normalizedKey,
          'league': normalizedLeague,
        },
      ),
      builder: (franchiseContext) => Scaffold(
        backgroundColor: nbaFranchiseBackground,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F151C),
          foregroundColor: const Color(0xFFE8EDF3),
          title: Text(franchiseName.trim().isEmpty ? 'NBA Franchise' : franchiseName.trim()),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: ProductNbaFranchiseScreen(
                franchiseKey: normalizedKey,
                league: normalizedLeague,
                loadFranchise: loadFranchise,
                loadTeamDossier: loadTeamDossier,
                onOpenTeam: onOpenTeam,
                onOpenPlayer: onOpenPlayer,
                onOpenSeason: (seasonId) => openHistoricalNbaSeasonPage(
                  franchiseContext,
                  seasonId: seasonId,
                  league: normalizedLeague,
                  seasonType: 'regular',
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
