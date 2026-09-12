import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical product shell owns desktop top navigation', () {
    final source = File(
      'lib/widgets/canonical_product_shell.dart',
    ).readAsStringSync();

    expect(source, contains('class _TopNav'));
    expect(source, contains('height: 68'));
    expect(source, contains('for (final entry in primary)'));
    expect(source, contains('drawer: compact'));
    expect(source, isNot(contains('width: 288')));
    expect(File('lib/widgets/connected_role_terminal_shell.dart').existsSync(), isFalse);
  });

  test('dark mode is the first-run default while saved preference is preserved', () {
    final source = File(
      'lib/widgets/canonical_product_shell.dart',
    ).readAsStringSync();

    expect(source, contains('bool _darkMode = true;'));
    expect(source, contains('ProductLocalStore.darkModeKey'));
    expect(source, contains('fallback: true'));
    expect(
      source,
      contains('await _store.saveBool(ProductLocalStore.darkModeKey, value);'),
    );
  });

  test('stats table density is modestly tighter without becoming ultra compact', () {
    final source = File(
      'lib/screens/product_nba_stats_workstation_v2_screen.dart',
    ).readAsStringSync();

    expect(source, contains('const playerWidth = 226.0;'));
    expect(source, contains('const metricWidth = 86.0;'));
    expect(source, contains('height: 58,'));
    expect(source, contains('height: 41,'));
    expect(source, isNot(contains('const metricWidth = 72.0;')));
    expect(source, isNot(contains('height: 32,')));
  });

  test('deleted research sidebar shell stays out of the canonical product', () {
    final source = File(
      'lib/widgets/canonical_product_shell.dart',
    ).readAsStringSync();

    expect(source, contains("'Search players & teams'"));
    expect(source, contains("'More'"));
    expect(File('lib/widgets/role_research_augmented_shell.dart').existsSync(), isFalse);
    expect(File('lib/widgets/launch_role_product_shell.dart').existsSync(), isFalse);
  });
}
