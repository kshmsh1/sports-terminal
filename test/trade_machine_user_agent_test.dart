import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/screens/product_trade_machine_complete_screen.dart';
import 'package:sports_terminal/services/trade_machine_user_agent.dart';

Future<void> _openBuilder(WidgetTester tester) async {
  await tester.tap(find.text('Boston Celtics'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Philadelphia 76ers'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Build Trade'));
  await tester.pumpAndSettle();
}

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

  testWidgets('Trade Machine opens with the video-directed team picker',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1700, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductTradeMachineCompleteScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NBA Trade Machine'), findsOneWidget);
    expect(find.text('BUILD A TRADE'), findsOneWidget);
    expect(find.text('Build a Trade'), findsOneWidget);
    expect(find.text('Recent Trades'), findsOneWidget);
    expect(find.text('All teams'), findsOneWidget);
    expect(find.text('East'), findsOneWidget);
    expect(find.text('West'), findsOneWidget);
    expect(find.text('Boston Celtics'), findsOneWidget);
    expect(find.text('Philadelphia 76ers'), findsOneWidget);
    expect(find.text('Minnesota Timberwolves'), findsOneWidget);

    final build = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Build Trade'),
    );
    expect(build.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trade Machine builds BOS-PHI with all requested asset tabs',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1700, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductTradeMachineCompleteScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openBuilder(tester);

    expect(find.text('Active Roster'), findsOneWidget);
    expect(find.text('Draft Picks'), findsOneWidget);
    expect(find.text('Draft Rights'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Free Agents'), findsOneWidget);
    expect(find.text('Restrictions On'), findsOneWidget);
    expect(find.text('Restrictions Off'), findsOneWidget);
    expect(find.text('Deadline Trade'), findsOneWidget);
    expect(find.text('TEAM ACQUIRE'), findsOneWidget);
    expect(find.textContaining('CBA / STRUCTURAL VALIDATION'), findsOneWidget);
    expect(find.text('POST-TRADE FINANCIALS'), findsOneWidget);
    expect(find.text('Jayson Tatum'), findsOneWidget);
    expect(find.text('Paul George'), findsOneWidget);
    expect(find.textContaining('PHI CANNOT REACQUIRE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trade Machine routes players and marks one-sided flow incomplete',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1700, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductTradeMachineCompleteScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openBuilder(tester);

    final route = find.text('Route to…').first;
    await tester.ensureVisible(route);
    await tester.tap(route);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PHI').last);
    await tester.pumpAndSettle();

    expect(find.text('INCOMPLETE TRADE'), findsOneWidget);
    expect(find.text('INCOMPLETE'), findsWidgets);
    expect(find.textContaining('Jayson Tatum'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trade Machine supports cash, free-agent S&T, and third teams',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 3600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductTradeMachineCompleteScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openBuilder(tester);

    await tester.tap(find.text('Free Agents'));
    await tester.pumpAndSettle();
    expect(find.text('Kyle Lowry'), findsOneWidget);
    expect(find.textContaining('UFA · Early Bird'), findsOneWidget);
    expect(find.textContaining(r'$5.50M'), findsWidgets);
    expect(find.text('Renounce all holds'), findsOneWidget);

    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    expect(find.text('CASH CONSIDERATIONS'), findsOneWidget);
    expect(find.text('TRADED PLAYER EXCEPTIONS'), findsOneWidget);

    await tester.tap(find.text('Add team'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minnesota Timberwolves'));
    await tester.pumpAndSettle();
    expect(find.text('Minnesota Timberwolves'), findsOneWidget);
    expect(find.textContaining('Timberwolves Acquire'), findsOneWidget);

    await tester.tap(find.text('Restrictions Off'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Restriction mode is OFF for exploration'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Recent Trades can seed a multi-team scenario', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1700, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductTradeMachineCompleteScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recent Trades'));
    await tester.pumpAndSettle();
    expect(find.text('Recent NBA Trades'), findsOneWidget);
    expect(find.textContaining('BOS/PHI'), findsWidgets);

    final loadButtons = find.text('Load teams');
    expect(loadButtons, findsWidgets);
    await tester.tap(loadButtons.first);
    await tester.pumpAndSettle();
    expect(find.text('Active Roster'), findsOneWidget);
    expect(find.text('TEAM ACQUIRE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
