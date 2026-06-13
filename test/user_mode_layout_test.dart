import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/controllers/auth_controller.dart';
import 'package:sports_terminal/screens/login_screen.dart';

void main() {
  testWidgets('login renders at 720 pixel width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(720, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(controller: AuthController())),
    );
    await tester.pump();

    expect(find.text('Sports Terminal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
