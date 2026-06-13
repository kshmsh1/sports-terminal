import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/controllers/auth_controller.dart';
import 'package:sports_terminal/controllers/internal_workspace_controller.dart';
import 'package:sports_terminal/controllers/route_payload_controller.dart';
import 'package:sports_terminal/screens/login_screen.dart';
import 'package:sports_terminal/widgets/user_terminal_shell.dart';

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

  testWidgets('user shell renders at 820 pixel width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(820, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = AuthController();
    final session = auth.demoSessions.first;
    final routes = RoutePayloadController();

    await tester.pumpWidget(
      RoutePayloadScope(
        controller: routes,
        child: MaterialApp(
          home: UserTerminalShell(
            session: session,
            workspaceController: InternalWorkspaceController(),
            onSignOut: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Dashboard'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
