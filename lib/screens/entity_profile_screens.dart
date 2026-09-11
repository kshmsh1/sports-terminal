import 'package:flutter/material.dart';

import 'entity_profile_screens_legacy.dart' as legacy;
import 'team_front_office_profile_screen.dart';

export 'entity_profile_screens_legacy.dart' hide openTeamProfile, TeamProfileScreen;

/// Canonical team-profile route. All screens that already import this module
/// now land on the front-office-capable team profile without needing per-screen
/// navigation rewrites.
Future<void> openTeamProfile(BuildContext context, String teamId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TeamProfileScreen(teamId: teamId),
    ),
  );
}

/// Keeps the public TeamProfileScreen API stable while promoting the new
/// front-office profile as the canonical team page.
class TeamProfileScreen extends StatelessWidget {
  const TeamProfileScreen({super.key, required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context) => TeamFrontOfficeProfileScreen(teamId: teamId);
}
