import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/widgets/terminal_filter_dropdown.dart';

void main() {
  testWidgets('long selected values remain constrained without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TerminalFilterDropdown(
              label: 'Route Intent',
              value: 'Open a deeply nested analytics workflow with an intentionally long label',
              values: const [
                'All',
                'Open a deeply nested analytics workflow with an intentionally long label',
              ],
              width: 230,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('terminal-filter-Route Intent')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty values render safely', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalFilterDropdown(
            label: 'Empty',
            value: 'All',
            values: const [],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
