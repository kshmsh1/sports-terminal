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
    expect(report.passedCount, greaterThanOrEqualTo(20));
  });

  testWidgets('Trade Machine renders a deal-first workspace', (tester) async {
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
    expect(
      find.text('Build the deal first. The cap rules update as you go.'),
      findsOneWidget,
    );
    expect(find.text('OUTGOING PACKAGE'), findsNWidgets(2));
    expect(find.text('BOS'), findsWidgets);
    expect(find.text('PHI'), findsWidgets);
    expect(find.text('Players'), findsWidgets);
    expect(find.text('Picks'), findsWidgets);
    expect(find.text('Cash / Exceptions'), findsWidgets);
    expect(find.text('Cap'), findsWidgets);
    expect(find.text('Select assets above to start building a trade.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trade Machine supports one-click asset selection', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1700, 2200));
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

    final searchFields = find.byType(TextField);
    expect(searchFields, findsWidgets);
    await tester.enterText(searchFields.first, 'Jayson');
    await tester.pumpAndSettle();
    expect(find.text('Jayson Tatum'), findsOneWidget);

    final addButtons = find.byTooltip('Add to trade');
    expect(addButtons, findsWidgets);
    await tester.ensureVisible(addButtons.first);
    await tester.tap(addButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('Jayson Tatum'), findsWidgets);
    expect(find.byTooltip('Remove from trade'), findsWidgets);
    expect(find.text('Trade does not work'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final reset = find.text('Reset');
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('Select assets above to start building a trade.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trade Machine supports team, pick, and exception flows',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 2200));
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

    await tester.tap(find.text('Add team'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ATL').last);
    await tester.pumpAndSettle();
    expect(find.text('ATL'), findsWidgets);

    await tester.tap(find.text('Picks').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('1st'), findsWidgets);

    await tester.tap(find.text('Cash / Exceptions').first);
    await tester.pumpAndSettle();
    expect(find.text('CASH CONSIDERATIONS'), findsWidgets);
    expect(find.text('TRADED PLAYER EXCEPTIONS'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
