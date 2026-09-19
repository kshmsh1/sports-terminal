import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new NBA workspaces are surfaced as first-class navigation groups', () {
    final shell =
        File('lib/widgets/canonical_product_shell.dart').readAsStringSync();

    expect(shell, contains("label: 'Games'"));
    expect(shell, contains("label: 'Analysis'"));
    expect(shell, contains('NbaWorkspaceLauncher(onSelect: _select)'));
    expect(shell, contains('NbaWorkspaceContextBar('));

    for (final id in const [
      'player-compare',
      'team-compare',
      'live-games',
      'box-scores',
      'media-feed',
      'visualizations',
      'with-without',
      'rankings',
      'trade',
      'front-office',
      'research',
    ]) {
      expect(shell, contains("id: '$id'"));
    }
  });

  test('workspace catalog documents every new customer-facing tool', () {
    final source =
        File('lib/widgets/nba_workspace_navigation.dart').readAsStringSync();

    for (final label in const [
      'Player Compare',
      'Team Compare',
      'Live Games',
      'Box Scores',
      'Media Feed',
      'Visualizations',
      'With / Without',
      'Rankings',
      'Trade Machine',
      'Front Office',
      'Research',
    ]) {
      expect(source, contains("label: '$label'"));
    }

    expect(source, contains("group: 'Compare'"));
    expect(source, contains("group: 'Games'"));
    expect(source, contains("group: 'Analysis'"));
    expect(source, contains("group: 'Front Office'"));
    expect(source, contains('Static historical data'));
    expect(source, contains('Local schedule + live overlay'));
    expect(source, contains('Live public embeds'));
  });

  test('workspace launcher and context bar remain local shell UX only', () {
    final source =
        File('lib/widgets/nba_workspace_navigation.dart').readAsStringSync();

    expect(source, isNot(contains('http://')));
    expect(source, isNot(contains('https://')));
    expect(source, isNot(contains('dart:io')));
    expect(source, contains('ValueChanged<String> onSelect'));
  });
}
