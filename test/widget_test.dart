import 'package:flutter_test/flutter_test.dart';

import 'package:sports_terminal/main.dart';

void main() {
  testWidgets('app restores session state and opens the account product', (
    tester,
  ) async {
    await tester.pumpWidget(const SportsTerminalApp());
    await tester.pumpAndSettle();

    expect(find.text('Sports Terminal'), findsWidgets);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Create account'), findsWidgets);
  });
}
