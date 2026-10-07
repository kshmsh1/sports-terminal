import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical navigation exposes the new NBA analysis surfaces', () {
    final shell = File(
      'lib/widgets/canonical_product_shell.dart',
    ).readAsStringSync();

    expect(shell, contains("id: 'visualizations'"));
    expect(shell, contains("id: 'with-without'"));
    expect(shell, contains("id: 'rankings'"));
    expect(shell, contains('WebsiteNbaVisualizationsScreen'));
    expect(shell, contains('WebsiteNbaWithWithoutScreen'));
    expect(shell, contains('WebsiteNbaRankingsScreen'));
  });

  test('canonical team links open the full 2026-27 team hub', () {
    final router = File(
      'lib/screens/website_nba_entity_pages.dart',
    ).readAsStringSync();
    final team = File(
      'lib/screens/website_nba_team_detail_screen.dart',
    ).readAsStringSync();

    expect(router, contains('WebsiteNbaTeamDetailScreen'));
    expect(router, contains("name: '/nba/teams/"));
    expect(team, contains('2026–27 depth chart'));
    expect(team, contains('2026–27 roster'));
    expect(team, contains("_SectionTitle('Injuries')"));
    expect(team, contains("_SectionTitle('Transactions')"));
    expect(team, contains('2026–27 schedule'));
    expect(team, contains('NbaTradeContractRepository'));
    expect(team, contains('NbaLiveGameService'));
    expect(team, contains('onOpenPlayer'));
  });

  test('with-without keeps a source-backed boundary and exposes pair analysis polish', () {
    final alias = File(
      'lib/screens/website_nba_with_without_screen.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/screens/website_nba_with_without_v2_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/services/nba_with_without_repository.dart',
    ).readAsStringSync();

    expect(alias, contains("export 'website_nba_with_without_v2_screen.dart'"));
    expect(screen, contains("String _season = '2025-26';"));
    expect(screen, contains('Stat Line Shift'));
    expect(screen, contains('_playerOne'));
    expect(screen, contains('_playerTwo'));
    expect(screen, contains('Select exactly two distinct players'));
    expect(screen, contains('Customize Stats'));
    expect(screen, contains('NbaWithWithoutRepository'));
    expect(screen, contains('lineup stints or play-by-play'));
    expect(screen, contains('Swap'));
    expect(screen, contains('STAT / Δ'));
    expect(screen, contains('With minus Without'));
    expect(screen, contains('Small sample'));
    expect(screen, contains(r'Season $formattedBaseline'));
    expect(repository, contains('with_without.json'));
    expect(repository, contains('available: false'));
    expect(repository, isNot(contains('Math.random')));
  });

  test('visualization studio supports interactive analytical workflows', () {
    final alias = File(
      'lib/screens/website_nba_visualizations_screen.dart',
    ).readAsStringSync();
    final source = File(
      'lib/screens/website_nba_visualizations_v2_screen.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/widgets/canonical_product_shell.dart',
    ).readAsStringSync();

    expect(alias, contains("export 'website_nba_visualizations_v2_screen.dart'"));
    expect(source, contains('Visualization Studio'));
    expect(source, contains("scatter('Scatter')"));
    expect(source, contains("bubble('Bubble')"));
    expect(source, contains("bar('Player ranking')"));
    expect(source, contains("histogram('Distribution')"));
    expect(source, contains("radar('Player profile')"));
    expect(source, isNot(contains("line('Line chart')")));
    expect(source, isNot(contains("pie('Pie chart')")));
    expect(source, contains('_InteractiveChartPanel'));
    expect(source, contains('Hover to inspect · click to pin'));
    expect(source, contains('Swap axes'));
    expect(source, contains('_ChartLegend'));
    expect(source, contains('_visualGroupColor'));
    expect(source, contains('WebsiteNbaApiService'));
    expect(source, contains('seasonSnapshot('));
    expect(source, contains('nba_visualization_presets_v1'));
    expect(source, contains('SharedPreferences'));
    expect(source, contains('Save as'));
    expect(source, contains('Best-fit line'));
    expect(source, contains('Mean reference lines'));
    expect(source, contains('CORRELATION'));
    expect(source, contains('R²'));
    expect(source, contains('_RegressionSummary'));
    expect(shell, contains("_selected == 'visualizations'"));
    expect(shell, contains('? 1880'));
  });

  test('rankings supports ordered drag-drop tiers and durable saved boards', () {
    final alias = File(
      'lib/screens/website_nba_rankings_screen.dart',
    ).readAsStringSync();
    final source = File(
      'lib/screens/website_nba_rankings_v2_screen.dart',
    ).readAsStringSync();

    expect(alias, contains("export 'website_nba_rankings_v2_screen.dart'"));
    expect(source, contains("_tiers = ['S', 'A', 'B', 'C', 'D', 'E', 'F']"));
    expect(source, contains('Draggable<String>'));
    expect(source, contains('DragTarget<String>'));
    expect(source, contains('beforeId'));
    expect(source, contains('Move earlier'));
    expect(source, contains('Move later'));
    expect(source, contains(r"'#$rank'"));
    expect(source, contains('Sort pool'));
    expect(source, contains('SharedPreferences'));
    expect(source, contains('Save As'));
    expect(source, contains("'Guards'"));
    expect(source, contains("'Wings'"));
    expect(source, contains("'Bigs'"));
    expect(source, contains('nba_custom_rankings_v1'));
  });
}
