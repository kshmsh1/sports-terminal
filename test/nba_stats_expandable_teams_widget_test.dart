import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sports_terminal/models/app_session.dart';
import 'package:sports_terminal/screens/website_nba_stats_v2_screen.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';
import 'package:sports_terminal/services/website_nba_api_service.dart';
import 'package:sports_terminal/widgets/sports_workspace_design.dart';

class _StatsArchive extends WebsiteNbaApiService {
  const _StatsArchive();

  @override
  Future<List<WebsiteNbaSeason>> seasons() async => [
    const WebsiteNbaSeason(id: '2025-26', label: '2025-26',
      startYear: 2025, rowCount: 1),
  ];

  @override
  Future<NbaTerminalSeedSnapshot> seasonSnapshot(String season, {
    String seasonType = 'regular', bool includeGameLogs = false,
  }) async => NbaTerminalSeedSnapshot.fromMap({
    'players': [],
    'player_season_totals': [
      {
        'player_id': 'test_harden',
        'player_label': 'James Harden',
        'team_ids': '2TM',
        'teams_played_for': ['CLE', 'LAC'],
        'position': 'PG',
        'season_type': seasonType,
        'games': 70,
        'minutes': 2100,
        'points': 1750,
        'rebounds': 350,
        'offensive_rebounds': 70,
        'defensive_rebounds': 280,
        'assists': 630,
      },
    ],
  });

  @override
  Future<Map<String, dynamic>> playerDossier(
    String playerKey, {String seasonType = 'combined', int recentGames = 30,
  }) async => {
    'profile': {'primary_position': 'PG'},
    'seasons': [
      {
        'season_id': '2025-26',
        'season_type': 'regular',
        'team_abbreviation': 'LAC',
        'games': 40, 'minutes': 1200, 'pts': 1000,
        'orb': 40, 'drb': 160, 'reb': 200, 'ast': 360,
        'position': 'PG',
      },
      {
        'season_id': '2025-26',
        'season_type': 'regular',
        'team_abbreviation': 'CLE',
        'games': 30, 'minutes': 900, 'pts': 750,
        'orb': 30, 'drb': 120, 'reb': 150, 'ast': 270,
        'position': 'PG',
      },
    ],
  };
}

const _session = AppSession(
  userId: 'stats-ui-fixture',
  email: 'fixture@example.invalid',
  displayName: 'Stats Reviewer',
  organizationId: 'fixture-org',
  organizationName: 'Fixture',
  role: UserRole.analyst,
);

void main() {
  testWidgets('Stats page expands traded season into authentic team rows',
      (tester) async {
    tester.view.physicalSize = const Size(1450, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: SportsWorkspaceDesign.theme(true),
      home: Scaffold(
        body: SingleChildScrollView(
          child: WebsiteNbaStatsScreen(session: _session,
            api: const _StatsArchive()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Copy CSV'), findsNothing);
    expect(find.textContaining('Conventional NBA'), findsNothing);
    expect(find.textContaining('Default qualification'), findsNothing);
    expect(find.textContaining('Historical rows are served'), findsNothing);

    expect(find.byTooltip('Expand James Harden team stats'), findsOneWidget);
    await tester.tap(find.byTooltip('Expand James Harden team stats'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Collapse James Harden team stats'), findsOneWidget);
    expect(find.text('LAC'), findsOneWidget);
    expect(find.text('CLE'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse James Harden team stats'));
    await tester.pumpAndSettle();
    expect(find.text('LAC'), findsNothing);
    expect(find.text('CLE'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
