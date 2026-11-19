import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sports_terminal/widgets/terminal_filter_dropdown.dart';
import 'package:sports_terminal/widgets/terminal_product_design.dart';

void main() {
  test('every enabled public destination belongs to a navigation section', () {
    final shell = File('lib/widgets/canonical_product_shell.dart').readAsStringSync();
    final start = shell.indexOf('const groups = <String, List<String>>{');
    final end = shell.indexOf('for (final entry in groups.entries)', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final categories = shell.substring(start, end);
    final routes = RegExp("id: '([^']+)'")
        .allMatches(shell.substring(0, shell.indexOf('class _AboutRoute')))
        .map((match) => match.group(1)!)
        .toSet();
    expect(routes.length, greaterThanOrEqualTo(25));
    for (final route in routes) {
      expect(categories, contains("'$route'"),
          reason: '$route must be discoverable in the workspace navigator');
    }
    expect(shell, contains("ValueKey('route-scroll-\$_selected')"));
    expect(shell, contains('SingleActivator(LogicalKeyboardKey.keyK'));
  });

  test('dark and light themes share readable semantic surface colors', () {
    final dark = TerminalProductDesign.theme(dark: true);
    final light = TerminalProductDesign.theme(dark: false);
    expect(dark.brightness, Brightness.dark);
    expect(light.brightness, Brightness.light);
    expect(dark.scaffoldBackgroundColor, isNot(light.scaffoldBackgroundColor));
    expect(dark.colorScheme.onSurface, isNot(light.colorScheme.onSurface));
    expect(TerminalProductDesign.pagePadding(
      viewportWidth: 420, route: 'stats').left,
      lessThan(TerminalProductDesign.pagePadding(
        viewportWidth: 1440, route: 'stats').left));
  });

  testWidgets('a controlled filter responds to parent updates without assertion',
      (tester) async {
    var season = '2025-26';
    await tester.pumpWidget(MaterialApp(
      theme: TerminalProductDesign.theme(dark: true),
      home: Scaffold(body: Center(
        child: StatefulBuilder(builder: (context, update) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TerminalFilterDropdown(
              label: 'Season',
              value: season,
              values: const ['2025-26', '2024-25', '2024-25'],
              onChanged: (next) => update(() => season = next),
            ),
            Text('Selected $season'),
          ],
        )),
      )),
    ));

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2024-25').last);
    await tester.pumpAndSettle();
    expect(find.text('Selected 2024-25'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
