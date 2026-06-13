import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/controllers/auth_controller.dart';
import 'package:sports_terminal/controllers/internal_workspace_controller.dart';
import 'package:sports_terminal/screens/internal_spreadsheet_screen.dart';
import 'package:sports_terminal/screens/login_screen.dart';
import 'package:sports_terminal/screens/safe_sql_screen.dart';
import 'package:sports_terminal/widgets/app_entry_gate.dart';
import 'package:sports_terminal/widgets/user_terminal_shell.dart';

void main() {
  test('user product surfaces instantiate', () {
    final auth = AuthController();
    final workspaces = InternalWorkspaceController();
    final analyst = auth.demoSessions.first;

    expect(LoginScreen(controller: auth), isA<LoginScreen>());
    expect(
      AppEntryGate(
        authController: auth,
        workspaceController: workspaces,
      ),
      isA<AppEntryGate>(),
    );
    expect(
      UserTerminalShell(
        session: analyst,
        workspaceController: workspaces,
        onSignOut: () {},
      ),
      isA<UserTerminalShell>(),
    );
    expect(
      InternalSpreadsheetScreen(
        session: analyst,
        workspaceController: workspaces,
      ),
      isA<InternalSpreadsheetScreen>(),
    );
    expect(const SafeSqlScreen(), isA<SafeSqlScreen>());
  });
}
