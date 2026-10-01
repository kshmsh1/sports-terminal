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

    expect(find.text('BUILD A TRADE'), findsOneWidget);
    expect(find.text('RECENT TRADES'), findsOneWidget);
    expect(find.text('BOS'), findsOneWidget);
    expect(find.text('PHI'), findsOneWidget);
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

    await tester.tap(find.text('BOS'));
    await tester.tap(find.text('PHI'));
    await tester.pumpAndSettle();

    final buildButtons = find.widgetWithText(FilledButton, 'Build a Trade');
    expect(buildButtons, findsOneWidget);
    await tester.tap(buildButtons);
    await tester.pumpAndSettle();

    expect(find.text('ACTIVE ROSTER'), findsOneWidget);
    expect(find.text('DRAFT PICKS'), findsOneWidget);
    expect(find.text('DRAFT RIGHTS'), findsOneWidget);
    expect(find.text('CASH'), findsOneWidget);
    expect(find.text('FREE AGENTS'), findsOneWidget);
    expect(find.text('Jayson Tatum'), findsOneWidget);
    expect(find.text('Financials'), findsOneWidget);
    expect(find.text('Snapshot'), findsOneWidget);

    final tradeButton = find.widgetWithText(OutlinedButton, 'Trade').first;
    await tester.tap(tradeButton);
    await tester.pumpAndSettle();

    expect(find.text('This is an incomplete trade.'), findsOneWidget);
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

    await tester.tap(find.text('BOS'));
    await tester.tap(find.text('PHI'));
    await tester.tap(find.widgetWithText(FilledButton, 'Build a Trade'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DRAFT RIGHTS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Justinian Jessup'), findsOneWidget);

    await tester.tap(find.text('CASH'));
    await tester.pumpAndSettle();
    expect(find.text('Cash considerations'), findsOneWidget);

    final phillyChip = find.text('76ers');
    expect(phillyChip, findsOneWidget);
    await tester.tap(phillyChip);
    await tester.pumpAndSettle();

    await tester.tap(find.text('FREE AGENTS'));
    await tester.pumpAndSettle();
    expect(find.text('Kyle Lowry'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);

    await tester.tap(find.text('ACTIVE ROSTER'));
    await tester.pumpAndSettle();
    final phillyTradeButton =
        find.widgetWithText(OutlinedButton, 'Trade').first;
    await tester.tap(phillyTradeButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Celtics'));
    await tester.pumpAndSettle();
    final bostonTradeButton =
        find.widgetWithText(OutlinedButton, 'Trade').first;
    await tester.tap(bostonTradeButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Snapshot'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Trade snapshot saved'), findsOneWidget);

    await tester.tap(find.text('RECENT TRADES'));
    await tester.pumpAndSettle();
    expect(find.text('Load a copy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
