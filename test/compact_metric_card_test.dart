import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/widgets/compact_metric_card.dart';

void main() {
  testWidgets('CompactMetricCard renders in a tight grid-sized box without overflow exceptions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 140,
            height: 86,
            child: CompactMetricCard(
              label: 'Connected Empty',
              value: '123456789',
              detail: 'Honest source-pending shells with a long label',
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Connected Empty'), findsOneWidget);
  });
}
