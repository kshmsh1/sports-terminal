import 'package:flutter/material.dart';

import '../models/app_session.dart';
import 'website_nba_entity_pages_legacy.dart' as legacy;
import 'website_nba_team_detail_screen.dart';

export 'website_nba_entity_pages_legacy.dart'
    hide openWebsiteNbaTeamPage;

Future<void> openWebsiteNbaTeamPage(
  BuildContext context, {
  required AppSession session,
  required String teamKey,
  required String teamName,
}) => Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: RouteSettings(
          name: '/nba/teams/${Uri.encodeComponent(teamKey)}',
        ),
        builder: (_) => WebsiteNbaTeamDetailScreen(
          session: session,
          teamKey: teamKey,
          teamName: teamName,
          onOpenPlayer: (playerContext, playerKey, playerName) {
            legacy.openWebsiteNbaPlayerPage(
              playerContext,
              session: session,
              playerKey: playerKey,
              playerName: playerName,
            );
          },
        ),
      ),
    );
