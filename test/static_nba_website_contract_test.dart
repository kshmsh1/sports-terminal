import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Stats and Advanced Stats use the static website facade', () {
    final stats =
        File('lib/screens/website_nba_stats_v2_screen.dart').readAsStringSync();
    final advanced = File(
      'lib/screens/website_nba_advanced_stats_v4_screen.dart',
    ).readAsStringSync();

    for (final source in [stats, advanced]) {
      expect(source, contains('WebsiteNbaApiService'));
      expect(source, contains('seasonSnapshot('));
      expect(source, isNot(contains('NbaTerminalSeedRepository().load')));
      expect(source, isNot(contains('/v2/nba/history')));
    }
  });

  test('historical website transport is same-origin static JSON', () {
    final repository = File(
      'lib/services/website_nba_static_repository.dart',
    ).readAsStringSync();
    final facade =
        File('lib/services/website_nba_api_service.dart').readAsStringSync();

    expect(repository, contains("basePath = 'data/nba_static'"));
    expect(repository, contains('Uri.base.resolve'));
    expect(facade, contains('WebsiteNbaStaticRepository'));
    expect(facade, isNot(contains('LaunchBackendTransport')));
    expect(facade, isNot(contains('http://127.0.0.1')));
  });

  test('NBA Home exposes the requested leader categories', () {
    final source =
        File('lib/screens/website_nba_home_dashboard.dart').readAsStringSync();

    for (final marker in const [
      "_LeaderSpec('points', 'Scoring', 'PPG')",
      "_LeaderSpec('rebounds', 'Rebounding', 'RPG')",
      "_LeaderSpec('assists', 'Assists', 'APG')",
      "_LeaderSpec('steals', 'Steals', 'SPG')",
      "_LeaderSpec('blocks', 'Blocks', 'BPG')",
      "_LeaderSpec('deflections', 'Deflections', 'DEF/G')",
      "_LeaderSpec('personal_fouls', 'Personal Fouls', 'PF/G')",
      "_LeaderSpec('turnovers', 'Turnovers', 'TPG')",
      "_LeaderSpec('three_pointers_made', 'Three-Pointers Made', '3PM/G')",
    ]) {
      expect(source, contains(marker));
    }
  });

  test('local launcher builds static data before Flutter starts', () {
    final source = File('scripts/open_terminal.sh').readAsStringSync();

    expect(source, contains('build_static_nba_website_data_v2_core.py'));
    expect(source, contains('nba_com_static_enrichment.py'));
    expect(source, contains('rebuild_static_nba_dashboards.py'));
    expect(source, contains('build_static_front_office_snapshot.py'));
    expect(source, contains('flutter run -d chrome'));
    expect(source, contains('deliberately does not scrape or download'));
  });
}
