import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authenticated product entry uses canonical product shell', () {
    final source = File('lib/widgets/app_entry_gate.dart').readAsStringSync();

    expect(source, contains('CanonicalProductShell('));
    expect(source, isNot(contains('RoleResearchAugmentedShell(')));
    expect(source, isNot(contains('child: const TerminalShell()')));
  });

  test('canonical desktop chrome keeps the approved five primary destinations', () {
    final source =
        File('lib/widgets/canonical_product_shell.dart').readAsStringSync();

    for (final label in const [
      'Home',
      'Stats',
      'Advanced Stats',
      'Lineup Analysis',
      'Trade Machine',
    ]) {
      expect(source, contains("'$label'"));
    }

    expect(source, contains('Search players & teams'));
    expect(source, contains("'More'"));
    expect(source, contains('ProductTradeMachineScreen()'));
    expect(source, isNot(contains('NBA OPERATING TERMINAL')));
    expect(source, isNot(contains('Find terminal function')));
  });
}
