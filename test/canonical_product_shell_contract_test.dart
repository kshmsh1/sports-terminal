import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authenticated product entry uses canonical product shell', () {
    final source = File('lib/widgets/app_entry_gate.dart').readAsStringSync();

    expect(source, contains('CanonicalProductShell('));
    expect(source, isNot(contains('RoleResearchAugmentedShell(')));
    expect(source, isNot(contains('child: const TerminalShell()')));
  });

  test('login lands on cross-sport home with NBA as the enabled league', () {
    final shell =
        File('lib/widgets/canonical_product_shell.dart').readAsStringSync();
    final sportsHome =
        File('lib/screens/website_sports_home_screen.dart').readAsStringSync();

    expect(shell, contains("String _selected = 'sports';"));
    expect(shell, contains('WebsiteSportsHomeScreen('));
    expect(shell, contains("_select('nba-home')"));

    for (final league in const [
      'NBA',
      'NFL',
      'NHL',
      'MLB',
      'MLS',
      'F1',
      'Premier League',
      'WNBA',
      'ATP',
      'WTA',
      'PGA',
      'IPL',
    ]) {
      expect(sportsHome, contains("'$league'"));
    }
    expect(sportsHome, contains("'NBA', 'Basketball'"));
    expect(sportsHome, contains('COMING SOON'));
  });

  test('canonical NBA navigation uses static website surfaces', () {
    final source =
        File('lib/widgets/canonical_product_shell.dart').readAsStringSync();

    for (final label in const [
      'NBA Home',
      'Stats',
      'Advanced Stats',
      'Trade Machine',
      'Front Office',
      'Research',
      'Community',
      'Python Lab',
      'Excel Workspace',
    ]) {
      expect(source, contains("'$label'"));
    }

    expect(source, contains('WebsiteNbaHomeDashboard(session: widget.session)'));
    expect(source, contains('WebsiteNbaStatsScreen(session: widget.session)'));
    expect(
      source,
      contains('WebsiteNbaAdvancedStatsScreen(session: widget.session)'),
    );
    expect(source, contains('ProductTradeMachineScreen.new'));
    expect(source, contains('ProductFrontOfficeRegistryScreen('));
    expect(source, contains('ProductCommunityV2Screen('));
    expect(source, contains('WebsiteNbaResearchScreen.new'));

    expect(source, isNot(contains('ProductArenaHomeScreen(')));
    expect(source, isNot(contains('ProductNbaStatsCenterScreen(')));
    expect(source, isNot(contains('ProductNbaStatsWorkstationScreen(')));
    expect(source, isNot(contains('ProductAnalyticsSuiteScreen(')));
  });

  test('Python and Excel are visible navigation placeholders only', () {
    final source =
        File('lib/widgets/canonical_product_shell.dart').readAsStringSync();

    expect(
      source,
      contains("id: 'python-lab',\n          label: 'Python Lab'"),
    );
    expect(
      source,
      contains("id: 'excel-workspace',\n          label: 'Excel Workspace'"),
    );
    expect(source, contains('enabled: false'));
    expect(source, contains('Display only — not connected'));
  });

  test('normal header has canonical static player and team search', () {
    final source =
        File('lib/widgets/canonical_product_shell.dart').readAsStringSync();

    expect(source, contains('Search players & teams'));
    expect(source, contains('WebsiteNbaApiService'));
    expect(source, contains('searchEntities(query)'));
    expect(source, contains('openWebsiteNbaPlayerPage('));
    expect(source, contains('openWebsiteNbaTeamPage('));
  });

  test('historical website facade reads static corpus rather than history API', () {
    final source =
        File('lib/services/website_nba_api_service.dart').readAsStringSync();

    expect(source, contains('WebsiteNbaStaticRepository'));
    expect(source, contains('No FastAPI request or runtime SQLite query'));
    expect(source, isNot(contains("'/v2/nba/history")));
    expect(source, isNot(contains('127.0.0.1:8000')));
  });
}
