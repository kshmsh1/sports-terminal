import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/login_screen.dart';
import 'role_terminal_shell.dart';
import 'terminal_shell.dart';

class AppEntryGate extends StatelessWidget {
  const AppEntryGate({
    super.key,
    required this.authController,
    required this.workspaceController,
  });

  final AuthController authController;
  final InternalWorkspaceController workspaceController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authController,
      builder: (context, _) {
        final session = authController.session;
        if (session == null) {
          return LoginScreen(controller: authController);
        }
        if (session.role.canAccessPlatformAdmin) {
          return const TerminalShell();
        }
        return RoleTerminalShell(
          session: session,
          workspaceController: workspaceController,
          onSignOut: authController.signOut,
        );
      },
    );
  }
}
