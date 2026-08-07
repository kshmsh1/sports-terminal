import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/screens/product_nba_historical_intelligence_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSurface(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductNbaHistoricalIntelligenceScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('historical intelligence mounts at desktop width', (tester) async {
    await pumpSurface(tester, const Size(1440, 1000));

    expect(find.text('NBA HISTORICAL INTELLIGENCE'), findsOneWidget);
    expect(find.text('All-Time Records'), findsOneWidget);
    expect(find.text('Cross-Era Compare'), findsOneWidget);
    expect(find.text('Franchise Lineage'), findsOneWidget);
    expect(find.text('Games & PBP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('historical intelligence mounts at narrow width', (tester) async {
    await pumpSurface(tester, const Size(820, 1000));

    expect(find.text('NBA HISTORICAL INTELLIGENCE'), findsOneWidget);
    expect(find.text('All-Time Records'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
