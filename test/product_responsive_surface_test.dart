import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/screens/product_nba_stats_center_screen.dart';
import 'package:sports_terminal/screens/product_trade_machine_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSurface(
    WidgetTester tester,
    Widget surface,
    Size size,
  ) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: surface,
            ),
          ),
        ),
      ),
    );

    // The product surfaces load several bundled JSON files through Future.wait.
    // pumpAndSettle alone can return while that real asynchronous asset work is
    // still pending because no new frame has yet been scheduled.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('trade machine has no narrow-width render overflow',
      (tester) async {
    await pumpSurface(
      tester,
      const ProductTradeMachineScreen(),
      const Size(820, 1000),
    );

    expect(find.text('Scenario control center'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trade machine has no desktop render overflow',
      (tester) async {
    await pumpSurface(
      tester,
      const ProductTradeMachineScreen(),
      const Size(1440, 1100),
    );

    expect(find.text('Scenario validation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NBA stats center has no narrow-width render overflow',
      (tester) async {
    await pumpSurface(
      tester,
      const ProductNbaStatsCenterScreen(),
      const Size(820, 1000),
    );

    expect(find.text('Command query'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NBA stats center has no desktop render overflow',
      (tester) async {
    await pumpSurface(
      tester,
      const ProductNbaStatsCenterScreen(),
      const Size(1440, 1100),
    );

    expect(find.text('Interpreted query plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
