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
    expect(screen, contains('Compare any NBA regular season or playoff run from 1946-47 through 2025-26'));
    expect(screen, contains("_slots.length >= 5"));
    expect(screen, contains("_slots.length < 5"));
    expect(screen, contains('Add player'));
    expect(screen, contains('Remove player'));
    expect(screen, contains('Cross-era mode'));
    expect(screen, contains('Season-relative fingerprints'));
    expect(screen, contains('winnerIndexes'));
    expect(screen, contains("winner ? '★ \$text' : text"));
    expect(screen, contains('most favorable available value'));

    expect(screen, contains('NbaStatsBasis.perGame'));
    expect(screen, contains('NbaStatsBasis.values'));
    expect(screen, contains('Regular Season'));
    expect(screen, contains('Playoffs'));
    expect(screen, contains("'Basic'"));
    expect(screen, contains("'Shooting'"));
    expect(screen, contains("'Playmaking'"));
    expect(screen, contains("'Rebounding'"));
    expect(screen, contains("'Defense'"));
    expect(screen, contains("'Impact'"));
    expect(screen, contains("'Custom'"));
    expect(screen, contains('Edit custom metrics'));

    expect(screen, contains('SharedPreferences'));
    expect(screen, contains('Saved views'));
    expect(screen, contains('Save As'));
    expect(screen, contains('_maxSavedViews = 5'));
    expect(screen, contains('PLAYER IMAGE PLACEHOLDER'));

    expect(screen, contains('WebsiteNbaApiService'));
    expect(screen, contains('seasonSnapshot('));
    expect(screen, isNot(contains('http://')));
    expect(screen, isNot(contains('/v2/nba/history')));
  });
}
