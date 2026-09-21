import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/screens/product_trade_machine_complete_screen.dart';
import 'package:sports_terminal/services/trade_machine_user_agent.dart';

void main() {
  test('Trade Machine user agent plays deterministic scenarios', () async {
    final report = await const TradeMachineUserAgent().play();

    for (final result in report.cases) {
      expect(
        result.passed,
        isTrue,
        reason: '${result.name}: ${result.detail}',
      );
    }
    expect(report.failedCount, 0);
    expect(report.passedCount, greaterThanOrEqualTo(5));
  });

  testWidgets('Trade Machine UI renders as a usable front-office surface',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: ProductTradeMachineCompleteScreen(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('NBA Trade Machine'), findsOneWidget);
    expect(find.text('TRADE SETUP'), findsOneWidget);
    expect(find.text('CBA / STRUCTURAL VALIDATION'), findsOneWidget);
    expect(find.text('POST-TRADE FINANCIALS'), findsOneWidget);
    expect(find.text('BOS'), findsWidgets);
    expect(find.text('PHI'), findsWidgets);
    expect(find.text('Players'), findsWidgets);
    expect(find.text('Draft Picks'), findsWidgets);
    expect(find.text('Money / Exceptions'), findsWidgets);
    expect(find.text('Cap Table'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
