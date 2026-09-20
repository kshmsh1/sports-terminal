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

  test('PDF supplement fills the three earliest NBA seasons statically', () {
    final supplement = File(
      'data/reference/nba_regular_totals_1946_49.csv.gz.b64',
    );
    final source = File(
      'tools/enrich_static_nba_pdf_early_totals.py',
    ).readAsStringSync();

    expect(supplement.existsSync(), isTrue);
    expect(supplement.lengthSync(), greaterThan(1000));
    expect(source, contains("{'1946-47', '1947-48', '1948-49'}"));
    expect(source, contains('MIN_PLAYER_LEADER_GAMES = 50'));
    expect(source, contains("'known_missing_seasons'] = []"));
    expect(source, contains("'network_requests': 0"));
    expect(source, contains("'player_season_totals': totals"));
  });

  test('Basketball Reference 3P and 3PA aliases are normalized', () {
    final source = File(
      'tools/normalize_static_nba_three_point_fields.py',
    ).readAsStringSync();

    expect(source, contains('"3P"'));
    expect(source, contains('"3PA"'));
    expect(source, contains('"3P%"'));
    expect(source, contains('"three_pointers_made"'));
    expect(source, contains('"three_point_attempts"'));
    expect(source, contains('"three_point_percentage"'));
    expect(source, contains('"network_requests": 0'));
  });

  test('local launcher builds static data before Flutter starts', () {
    final source = File('scripts/open_terminal.sh').readAsStringSync();

    expect(source, contains('build_static_nba_website_data_v2_core.py'));
    expect(source, contains('normalize_static_nba_three_point_fields.py'));
    expect(source, contains('nba_com_static_enrichment.py'));
    expect(source, contains('rebuild_static_nba_dashboards.py'));
    expect(source, contains('enrich_static_nba_pdf_early_totals.py'));
    expect(source, contains('build_static_front_office_snapshot.py'));
    expect(source, contains('flutter run -d chrome'));
    expect(source, contains('deliberately do not scrape, poll or'));
    expect(source, isNot(contains('--refresh-live')));
  });
}
