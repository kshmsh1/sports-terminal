import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sports_terminal/main.dart';

void main() {
  testWidgets('app restores session state and opens the account product', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SportsTerminalApp());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sports Terminal'), findsWidgets);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Create account'), findsWidgets);
  });
}
