import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('role terminal uses horizontal top navigation instead of desktop sidebar', () {
    final source = File(
      'lib/widgets/connected_role_terminal_shell.dart',
    ).readAsStringSync();

    expect(source, contains('class _TerminalTopNavigation'));
    expect(source, contains('scrollDirection: Axis.horizontal'));
    expect(source, isNot(contains('width: 288')));
    expect(source, isNot(contains('class _TerminalNavigation')));
    expect(source, isNot(contains('drawer: compact')));
  });

  test('dark mode is the first-run default while saved preference is preserved', () {
    final source = File(
      'lib/widgets/connected_role_terminal_shell.dart',
    ).readAsStringSync();

    expect(source, contains('bool darkMode = true;'));
    expect(source, contains('ProductLocalStore.darkModeKey'));
    expect(source, contains('fallback: true'));
    expect(source, contains('await store.saveBool(ProductLocalStore.darkModeKey, next)'));
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

  test('research launchers no longer reserve deleted sidebar width', () {
    final source = File(
      'lib/widgets/role_research_augmented_shell.dart',
    ).readAsStringSync();

    expect(source, contains('const left = 18.0;'));
    expect(source, isNot(contains('306.0')));
  });
}
