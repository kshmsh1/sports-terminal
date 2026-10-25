import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sports_terminal/models/app_session.dart';
import 'package:sports_terminal/screens/website_nba_advanced_stats_v4_screen.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';
import 'package:sports_terminal/services/website_nba_api_service.dart';
import 'package:sports_terminal/services/nba_stats_metric_catalog.dart';
import 'package:sports_terminal/widgets/nba_percentage_heat_cell.dart';
import 'package:sports_terminal/widgets/website_sticky_stats_table.dart';
import 'package:sports_terminal/widgets/sports_workspace_design.dart';

class _AdvancedArchive extends WebsiteNbaApiService {
  const _AdvancedArchive();
  @override
  Future<List<WebsiteNbaSeason>> seasons() async => const [
    WebsiteNbaSeason(id: '2025-26', label: '2025-26',
      startYear: 2025, rowCount: 1),
  ];

  @override
  Future<NbaTerminalSeedSnapshot> seasonSnapshot(String season, {
    String seasonType = 'regular', bool includeGameLogs = false,
  }) async => NbaTerminalSeedSnapshot.fromMap({
    'players': [],
    'player_season_totals': [
      {
        'player_id': 'test_simons',
        'player_label': 'Anfernee Simons',
        'team_ids': '2TM',
        'teams_played_for': ['BOS', 'POR'],
        'position': 'SG',
        'season_type': seasonType,
        'games': 70,
        'minutes': 2200,
        'points': 1450,
        'rebounds': 210,
        'assists': 350,
        'two_pm': 250,
        'two_pa': 450,
      },
    ],
  });

  @override
  Future<Map<String, dynamic>> playerDossier(
    String playerKey, {String seasonType = 'combined', int recentGames = 30,
  }) async => {
    'profile': {'primary_position': 'SG'},
    'seasons': [
      {
        'season_id': '2025-26', 'season_type': 'regular',
        'team_abbreviation': 'BOS', 'games': 30, 'minutes': 960,
        'pts': 600, 'reb': 100, 'ast': 150,
      },
      {
        'season_id': '2025-26', 'season_type': 'regular',
        'team_abbreviation': 'POR', 'games': 40, 'minutes': 1240,
        'pts': 850, 'reb': 110, 'ast': 200,
      },
    ],
  };
}

const _session = AppSession(
  userId: 'advanced-ui-fixture', email: 'fixture@example.invalid',
  displayName: 'Advanced Reviewer', organizationId: 'fixture-org',
  organizationName: 'Fixture', role: UserRole.analyst,
);

void main() {
  test('catalog drilldowns and requested metric aliases', () {
    final playmaking = nbaTerminalFamily('playmaking');
    expect(nbaVisibleMetricKeys(playmaking, {'apg'}),
      containsAllInOrder(['apg', 'ast_pct']));
    expect(nbaVisibleMetricKeys(playmaking, {'tpg'}),
      containsAllInOrder(['tpg', 'tov_pct']));
    expect(playmaking.metrics, isNot(contains('ast_pct')));
    expect(playmaking.metrics, isNot(contains('tov_pct')));
    final rebounding = nbaTerminalFamily('rebounding');
    expect(nbaVisibleMetricKeys(rebounding, {'tap_outs_pg'}),
      containsAllInOrder(['tap_outs_pg', 'tap_outs_pct']));
    expect(nbaVisibleMetricKeys(rebounding, {'deferred_rebounds_pg'}),
      containsAllInOrder(['deferred_rebounds_pg', 'deferred_rebounds_pct']));
    final defense = nbaTerminalFamily('defense_hustle');
    expect(nbaVisibleMetricKeys(defense, {'deflections_pg'}),
      containsAllInOrder(['deflections_pg', 'deflections_pct']));
    expect(nbaTerminalMetricByKey['obpm']?.shortLabel, 'OBPM');
    expect(nbaTerminalMetricByKey['dbpm']?.shortLabel, 'DBPM');
    expect(nbaTerminalMetricByKey['ows']?.shortLabel, 'OWS');
    expect(nbaTerminalMetricByKey['dws']?.shortLabel, 'DWS');
    expect(nbaTerminalMetricByKey['ftr']?.shortLabel, 'FT Rate');
    expect(nbaTerminalMetricByKey['three_par']?.shortLabel, '3PA Rate');
    expect(nbaTerminalMetricByKey['clutch_pf_pg']?.shortLabel, 'Clutch PF');
    expect(nbaTerminalFamily('aggregate').metrics, contains('ws_48'));
  });

  testWidgets('reference shooting tier cutoffs are monotone and distinct',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('tier test'))),
    ));
    final context = tester.element(find.text('tier test'));
    for (final example in <(NbaPercentageHeatMetric, List<double>)>[
      (NbaPercentageHeatMetric.twoPoint, [.61, .57, .52, .48]),
      (NbaPercentageHeatMetric.rimFieldGoal, [.72, .67, .61, .55]),
      (NbaPercentageHeatMetric.midrangeFieldGoal, [.50, .45, .39, .33]),
    ]) {
      final colors = [
        for (final value in example.$2)
          nbaPercentageHeatColor(context, example.$1, value),
      ];
      expect(colors.every((color) => color != null), isTrue);
      expect(colors.toSet().length, 4);
    }
  });

  testWidgets('Boston filter includes 2TM players and expands their stints',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: SportsWorkspaceDesign.theme(true),
      home: Scaffold(
        body: SingleChildScrollView(
          child: WebsiteNbaAdvancedStatsScreen(
            session: _session, api: const _AdvancedArchive()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Advanced Stats'), findsOneWidget);
    expect(find.text('Copy CSV'), findsNothing);
    expect(find.text('Stat group'), findsNothing);
    expect(find.byTooltip('Expand Anfernee Simons team stats'), findsOneWidget);

    // Column sizing should follow rendered header widths, not broad
    // character-count estimates. Preserve the original table typography.
    final overview = tester.widget<WebsiteStickyStatsTable>(
      find.byType(WebsiteStickyStatsTable),
    );
    expect(overview.columns[3].width, lessThan(78)); // GP
    expect(overview.columns[4].width, lessThan(78)); // MPG
    expect(overview.columns[5].width, lessThan(78)); // PPG
    await tester.tap(find.text('Defensive / Hustle'));
    await tester.pumpAndSettle();
    final defense = tester.widget<WebsiteStickyStatsTable>(
      find.byType(WebsiteStickyStatsTable),
    );
    final contestedShots = defense.columns.singleWhere(
      (column) => column.label is Text &&
          (column.label as Text).data == 'Contested Shots PG',
    );
    expect(contestedShots.width, lessThan(166));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    // Franchise filters must include full-season 2TM records whose
    // source-provided teams_played_for contains the selected franchise.
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'All').first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('BOS').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Expand Anfernee Simons team stats'), findsOneWidget);

    await tester.tap(find.byTooltip('Expand Anfernee Simons team stats'));
    await tester.pumpAndSettle();
    expect(find.text('BOS'), findsNWidgets(2));
    expect(find.text('POR'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse Anfernee Simons team stats'));
    await tester.pumpAndSettle();
    expect(find.text('BOS'), findsOneWidget);
    expect(find.text('POR'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
