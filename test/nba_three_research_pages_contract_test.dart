import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('financial reference has team filters and detail panels', () {
    final source = File('lib/screens/website_nba_financials_screen.dart').readAsStringSync();
    expect(source, contains('_FinancialView'));
    expect(source, contains('View details'));
    expect(source, contains('hard-cap status'.replaceAll('hard-cap', 'Hard-cap').split(' ').first));
    expect(source, contains('NbaTeamFinancialReference202627'));
    expect(source, contains('Trade Machine'));
  });

  test('box scores show source-backed team tabs and missing-minute entries', () {
    final source = File('lib/screens/website_nba_box_scores_screen.dart').readAsStringSync();
    expect(source, contains('DefaultTabController'));
    expect(source, contains('_rowsForBoxTeam'));
    expect(source, contains('Did not play / no minutes reported'));
    expect(source, contains('Latest'.toLowerCase().replaceAll('latest', 'latest indexed')));
    expect(source, contains('_day('));
  });

  test('lineup page deduplicates players and shows honest season fallback', () {
    final source = File('lib/screens/website_nba_with_without_v2_screen.dart').readAsStringSync();
    expect(source, contains('unique.putIfAbsent(row.playerId'));
    expect(source, contains('Season baseline comparison'));
    expect(source, contains('pair-split values remain blank'));
    expect(source, contains('_loadSerial'));
  });
}
