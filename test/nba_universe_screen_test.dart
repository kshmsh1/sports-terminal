import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/screens/product_nba_universe_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpUniverse(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductNbaUniverseScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('NBA Universe mounts at desktop width', (tester) async {
    await pumpUniverse(tester, const Size(1440, 1000));

    expect(find.text('NBA UNIVERSE'), findsOneWidget);
    expect(find.text('Players'), findsOneWidget);
    expect(find.text('Teams'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NBA Universe mounts at narrow width without overflow',
      (tester) async {
    await pumpUniverse(tester, const Size(820, 1000));

    expect(find.text('NBA UNIVERSE'), findsOneWidget);
    expect(find.text('Search the NBA universe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
