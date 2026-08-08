import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary stats workstation defaults to regular season and exposes only postseason split', () {
    final source = File(
      'lib/screens/product_nba_stats_workstation_v2_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('_seasonType = NbaStatsSeasonType.regular;'),
      reason: 'Regular season must remain the default stats segment.',
    );
    expect(source, contains("label: 'REGULAR SEASON'"));
    expect(source, contains("label: 'PLAYOFFS'"));
    expect(
      source,
      isNot(contains('NbaStatsSeasonType.combined')),
      reason: 'The Stats Workstation must not expose a combined regular/playoff mode.',
    );
  });

  test('historical stats defaults to regular season and never exposes combined mode', () {
    final source = File(
      'lib/screens/product_historical_nba_workstation_screen.dart',
    ).readAsStringSync();

    expect(source, contains("String _seasonType = 'regular';"));
    expect(source, contains("values: const ['regular', 'playoffs']"));
    expect(source, contains("'regular' => 'Regular Season'"));
    expect(source, contains("'playoffs' => 'Playoffs'"));
    expect(
      source,
      isNot(contains("'combined'")),
      reason: 'Historical stats must preserve the same regular/playoffs split.',
    );
  });
}
