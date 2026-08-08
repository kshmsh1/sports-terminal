import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/models/app_session.dart';
import 'package:sports_terminal/screens/product_nba_terminal_screen.dart';
import 'package:sports_terminal/services/product_local_store.dart';

void main() {
  const session = AppSession(
    userId: 'debug-runtime-user',
    email: 'debug@example.com',
    displayName: 'Debug Runtime',
    organizationId: '',
    organizationName: '',
    role: UserRole.analyst,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ProductLocalStore.launchRemoteSyncEnabledKey: false,
    });
  });

  testWidgets('terminal state mutations remain synchronous inside setState',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductNbaTerminalScreen(session: session),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 's');
    await tester.tap(find.widgetWithText(FilledButton, 'GO'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.star_border_rounded).first);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('NBA Terminal Home').first);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
