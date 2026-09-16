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

  test('with-without keeps a source-backed empty state until lineup data exists', () {
    final screen = File(
      'lib/screens/website_nba_with_without_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/services/nba_with_without_repository.dart',
    ).readAsStringSync();

    expect(screen, contains("String _season = '2025-26';"));
    expect(screen, contains('Stat Line Shift'));
    expect(screen, contains('_playerOne'));
    expect(screen, contains('_playerTwo'));
    expect(screen, contains('Select exactly two players'));
    expect(screen, contains('Customize Stats'));
    expect(screen, contains('NbaWithWithoutRepository'));
    expect(screen, contains('lineup stints or play-by-play'));
    expect(repository, contains('with_without.json'));
    expect(repository, contains('available: false'));
    expect(repository, isNot(contains('Math.random')));
  });

  test('visualization studio exposes multiple configurable chart families', () {
    final source = File(
      'lib/screens/website_nba_visualizations_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Visualization Studio'));
    expect(source, contains("scatter('Scatterplot')"));
    expect(source, contains("bubble('Bubble chart')"));
    expect(source, contains("bar('Bar chart')"));
    expect(source, contains("line('Line chart')"));
    expect(source, contains("area('Area chart')"));
    expect(source, contains("pie('Pie chart')"));
    expect(source, contains("histogram('Histogram')"));
    expect(source, contains("radar('Radar chart')"));
    expect(source, contains('CustomPaint'));
    expect(source, contains('WebsiteNbaApiService'));
    expect(source, contains('seasonSnapshot('));
  });

  test('rankings supports drag-drop tiers and durable saved boards', () {
    final source = File(
      'lib/screens/website_nba_rankings_screen.dart',
    ).readAsStringSync();

    expect(source, contains("_tiers = ['S', 'A', 'B', 'C', 'D', 'E', 'F']"));
    expect(source, contains('Draggable<String>'));
    expect(source, contains('DragTarget<String>'));
    expect(source, contains('SharedPreferences'));
    expect(source, contains('Save As'));
    expect(source, contains("'Guards'"));
    expect(source, contains("'Wings'"));
    expect(source, contains("'Bigs'"));
    expect(source, contains('nba_custom_rankings_v1'));
  });
}
