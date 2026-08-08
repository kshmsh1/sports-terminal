import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/screens/product_nba_entity_command_center_screen.dart';
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
    await tester.pump();
  }

  testWidgets('trade machine mounts at narrow width without render overflow',
      (tester) async {
    await pumpSurface(
      tester,
      const ProductTradeMachineScreen(),
      const Size(820, 1000),
    );

    expect(find.byType(ProductTradeMachineScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trade machine mounts at desktop width without render overflow',
      (tester) async {
    await pumpSurface(
      tester,
      const ProductTradeMachineScreen(),
      const Size(1440, 1100),
    );

    expect(find.byType(ProductTradeMachineScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NBA stats center mounts at narrow width without render overflow',
      (tester) async {
    await pumpSurface(
      tester,
      const ProductNbaStatsCenterScreen(),
      const Size(820, 1000),
    );

    expect(find.byType(ProductNbaStatsCenterScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NBA stats center mounts at desktop width without render overflow',
      (tester) async {
    await pumpSurface(
      tester,
      const ProductNbaStatsCenterScreen(),
      const Size(1440, 1100),
    );

    expect(find.byType(ProductNbaStatsCenterScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entity command center mounts at narrow width', (tester) async {
    await pumpSurface(
      tester,
      const ProductNbaEntityCommandCenterScreen(),
      const Size(820, 1000),
    );

    expect(find.byType(ProductNbaEntityCommandCenterScreen), findsOneWidget);
    expect(find.text('NBA ENTITY & SEASON INTELLIGENCE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entity command center mounts at desktop width', (tester) async {
    await pumpSurface(
      tester,
      const ProductNbaEntityCommandCenterScreen(),
      const Size(1440, 1100),
    );

    expect(find.byType(ProductNbaEntityCommandCenterScreen), findsOneWidget);
    expect(find.text('NBA ENTITY & SEASON INTELLIGENCE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
