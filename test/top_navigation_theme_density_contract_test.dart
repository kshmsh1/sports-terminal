import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical product uses top navigation and a command palette', () {
    final shell = File('lib/widgets/canonical_product_shell.dart').readAsStringSync();
    final chrome = File('lib/widgets/sports_workspace_chrome.dart').readAsStringSync();
    expect(shell, contains('SportsWorkspaceChrome('));
    expect(shell, contains('SportsWorkspaceDesign.maxContentWidth'));
    expect(chrome, contains('class _WorkspaceTopNavigation'));
    expect(chrome, contains('class _WorkspaceCommandDialog'));
    expect(chrome, contains('final full = box.maxWidth >= 1500'));
    expect(chrome, contains("tooltip: 'Navigation'"));
    expect(chrome, contains('LogicalKeyboardKey.keyK'));
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
    expect(File('lib/widgets/sports_workspace_chrome.dart').readAsStringSync(), contains("'Search players & teams'"));
    expect(File('lib/widgets/sports_workspace_chrome.dart').readAsStringSync(), contains("'More'"));
    expect(File('lib/widgets/role_research_augmented_shell.dart').existsSync(), isFalse);
    expect(File('lib/widgets/launch_role_product_shell.dart').existsSync(), isFalse);
  });
}
