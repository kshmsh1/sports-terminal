import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/screens/product_trade_machine_video_screen.dart';
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

  testWidgets('Trade Machine opens on the 2-5 team build selector',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1700, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: ProductTradeMachineVideoScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NBA Trade Machine'), findsOneWidget);
    expect(find.text('Build a Trade'), findsWidgets);
    expect(find.text('Recent Trades'), findsOneWidget);
    expect(find.text('Boston Celtics'), findsOneWidget);
    expect(find.text('Philadelphia 76ers'), findsOneWidget);
    expect(find.textContaining('Choose 2-5 teams'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trade Machine builds a two-team asset-routing workspace',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1700, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: ProductTradeMachineVideoScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Boston Celtics'));
    await tester.tap(find.text('Philadelphia 76ers'));
    await tester.pumpAndSettle();

    final buildButtons = find.widgetWithText(FilledButton, 'Build a Trade');
    expect(buildButtons, findsOneWidget);
    await tester.tap(buildButtons);
    await tester.pumpAndSettle();

    expect(find.text('Active Roster'), findsOneWidget);
    expect(find.text('Draft Picks'), findsOneWidget);
    expect(find.text('Draft Rights'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Free Agents'), findsOneWidget);
    expect(find.text('Jayson Tatum'), findsOneWidget);
    expect(find.text('Financials'), findsOneWidget);
    expect(find.text('Snapshot'), findsOneWidget);

    final tatumRow = find.ancestor(
      of: find.text('Jayson Tatum'),
      matching: find.byType(Row),
    ).first;
    final tradeButton = find.descendant(
      of: tatumRow,
      matching: find.widgetWithText(OutlinedButton, 'Trade'),
    );
    expect(tradeButton, findsOneWidget);
    await tester.tap(tradeButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Philadelphia 76ers Acquire'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trade Machine exposes rights, cash, free-agent and saved-trade flows',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1700, 2800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: ProductTradeMachineVideoScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Boston Celtics'));
    await tester.tap(find.text('Philadelphia 76ers'));
    await tester.tap(find.widgetWithText(FilledButton, 'Build a Trade'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Draft Rights'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Juhann Begarin'), findsOneWidget);

    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    expect(find.text('Cash considerations'), findsOneWidget);

    final phillyChip = find.text('76ers');
    expect(phillyChip, findsOneWidget);
    await tester.tap(phillyChip);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Free Agents'));
    await tester.pumpAndSettle();
    expect(find.text('Kyle Lowry'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);

    await tester.tap(find.text('Active Roster'));
    await tester.pumpAndSettle();
    final embiidRow = find.ancestor(
      of: find.text('Joel Embiid'),
      matching: find.byType(Row),
    ).first;
    final tradeButton = find.descendant(
      of: embiidRow,
      matching: find.widgetWithText(OutlinedButton, 'Trade'),
    );
    await tester.tap(tradeButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Snapshot'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Trade snapshot saved'), findsOneWidget);

    await tester.tap(find.text('Recent Trades').first);
    await tester.pumpAndSettle();
    expect(find.text('Load a copy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
