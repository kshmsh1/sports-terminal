import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical navigation exposes the NBA comparison lab', () {
    final shell = File('lib/widgets/canonical_product_shell.dart').readAsStringSync();
    final screen = File(
      'lib/screens/website_nba_player_comparison_screen.dart',
    ).readAsStringSync();

    expect(shell, contains("id: 'compare'"));
    expect(shell, contains("label: 'Compare'"));
    expect(shell, contains('WebsiteNbaPlayerComparisonScreen'));
    expect(shell, contains('navItems.take(6)'));

    expect(screen, contains('Player Comparison Lab'));
    expect(screen, contains('Cross-era mode'));
    expect(screen, contains('Season-relative fingerprint'));
    expect(screen, contains('WebsiteNbaApiService'));
    expect(screen, contains('seasonSnapshot('));
    expect(screen, isNot(contains('http://')));
    expect(screen, isNot(contains('/v2/nba/history')));
  });
}
