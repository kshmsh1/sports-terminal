import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/widgets/nba_percentage_heat_cell.dart';
import 'package:sports_terminal/services/nba_stats_metric_catalog.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';

void main() {
  testWidgets('Free throw heat marks 90.0% dark green for both FT% labels',
      (tester) async {
    Color? colorAt(double value, String key) {
      final element = tester.element(find.byType(MaterialApp));
      return nbaPercentageHeatColor(
          element, nbaPercentageHeatMetricForKey(key)!, value);
    }
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Stats'))));
    const dark = Color(0xFF14532D);
    expect(colorAt(.90, 'ft_pct'), dark);
    expect(colorAt(.90, 'clutch_ft_pct'), dark);
    expect(colorAt(.899, 'ft_pct'), isNot(dark));
    expect(colorAt(.899, 'clutch_ft_pct'), isNot(dark));
  });

  test('APG and TPG expose source-backed AST% and TO% in their metric metadata', () {
    expect(nbaTerminalMetricByKey['apg']!.children, contains('ast_pct'));
    expect(nbaTerminalMetricByKey['tpg']!.children, contains('tov_pct'));
    expect(nbaTerminalMetricByKey['trb_pct']!.shortLabel, 'REB%');
    expect(nbaTerminalMetricByKey['ortg']!.shortLabel, 'ORTG');
    expect(nbaTerminalMetricByKey['drtg']!.shortLabel, 'DRTG');
    expect(nbaTerminalMetricByKey['net_rating']!.shortLabel, 'NRTG');

    const resolver = NbaTerminalMetricResolver();
    const row = NbaStatsRow(
      playerId: 'player-1', player: 'Player', team: 'CHI', position: 'G',
      values: <String, double?>{}, percentiles: <String, double>{},
      raw: <String, dynamic>{'ast_pct': .364, 'tov_pct': .116},
      possessionsEstimated: false,
    );
    expect(resolver.format(row, 'ast_pct'), '36.4%');
    expect(resolver.format(row, 'tov_pct'), '11.6%');
  });

  test('Advanced Stats category chips wrap and all stat tables use inspectors', () {
    final advanced = File('lib/screens/website_nba_advanced_stats_v4_screen.dart')
        .readAsStringSync();
    final regular = File('lib/screens/website_nba_stats_v2_screen.dart')
        .readAsStringSync();
    expect(advanced, contains('Wrap(spacing: 7, runSpacing: 8'));
    expect(advanced, isNot(contains('Deep player statistics organized by basketball questions')));
    expect(advanced, contains("countMetric('ast','APG','Assists','AST','Assists.',children:"));
    expect(advanced, contains("countMetric('tov','TPG','Turnovers','TOV','Turnovers.',children:"));
    expect(advanced, isNot(contains("'PF PG','Personal Fouls'")));
    for (final source in [advanced, regular]) {
      expect(source, contains('NbaPlayerInspector('));
      expect(source, contains('_inspectedPlayerId'));
      expect(source, contains('LayoutBuilder(builder: (context, bounds)'));
    }
    expect(regular, contains("_StatColumn('ast_pct', 'AST%'"));
    expect(regular, contains("_StatColumn('tov_pct', 'TO%'"));
  });

  test('Box Score calendar and game/player drilldown are internal to page', () {
    final source = File('lib/screens/website_nba_box_scores_screen.dart')
        .readAsStringSync();
    expect(source, contains('showDatePicker('));
    expect(source, contains('_dateKey(date)'));
    expect(source, contains('class _GameTile'));
    expect(source, contains('class _GameInspector'));
    expect(source, contains('class _PlayerSpotlight'));
    expect(source, isNot(contains('showDialog<void>')));
  });

  test('Finance and visual outputs visibly retain Arcside attribution', () {
    final financial = File('lib/screens/website_nba_financials_screen.dart')
        .readAsStringSync();
    final chart = File('lib/screens/website_nba_visualizations_v2_screen.dart')
        .readAsStringSync();
    expect(financial, contains('class _TeamFinancialInspector'));
    expect(financial, contains("DataRow("));
    expect(financial, contains("Text('ARCSIDE · 2026–27'"));
    expect(chart, contains("text: 'ARCSIDE'"));
    expect(chart, contains('mark.paint(canvas'));
  });

  test('With Without missing-data UI shows source-backed baselines', () {
    final source = File('lib/screens/website_nba_with_without_v2_screen.dart')
        .readAsStringSync();
    expect(source, contains('class _SeasonBaselineCard'));
    expect(source, contains('if (firstSplit == null && secondSplit == null)'));
    final loader = File('lib/services/nba_with_without_repository.dart')
        .readAsStringSync();
    expect(loader, contains("response.headers['content-type']"));
    expect(loader, contains('Lineup split data has not been published'));
  });

  test('Research links to active tools and keeps planned labs disabled', () {
    final shell = File('lib/widgets/canonical_product_shell.dart')
        .readAsStringSync();
    expect(shell, contains("builder: () => WebsiteNbaResearchScreen(onNavigate: _select)"));
    expect(shell, contains("id: 'python-lab'"));
    expect(shell, contains("id: 'excel-workspace'"));
  });
}
