import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/controllers/internal_workspace_controller.dart';
import 'package:sports_terminal/models/app_session.dart';
import 'package:sports_terminal/widgets/connected_role_terminal_shell.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders the connected Individual Terminal', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ConnectedRoleTerminalShell(
          session: const AppSession(
            userId: 'analyst-1',
            email: 'analyst@example.com',
            displayName: 'Analyst One',
            organizationId: 'org-1',
            organizationName: 'Example Basketball Operations',
            role: UserRole.analyst,
          ),
          workspaceController: InternalWorkspaceController(),
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Work'), findsWidgets);
    expect(find.text('INDIVIDUAL TRANSACTION COMMAND'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the connected Organization Terminal', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ConnectedRoleTerminalShell(
          session: const AppSession(
            userId: 'admin-1',
            email: 'admin@example.com',
            displayName: 'Operations Admin',
            organizationId: 'org-1',
            organizationName: 'Example Basketball Operations',
            role: UserRole.organizationAdmin,
          ),
          workspaceController: InternalWorkspaceController(),
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Organization'), findsWidgets);
    expect(find.text('ORGANIZATION TRANSACTION COMMAND'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
