import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../controllers/internal_workspace_controller.dart';
import '../screens/login_screen.dart';
import 'traditional_website_shell.dart';

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
        if (!authController.hydrated && authController.busy) {
          return const _SessionRestoreScreen();
        }
        final session = authController.session;
        if (session == null) {
          return LoginScreen(controller: authController);
        }

        return TraditionalWebsiteShell(
          session: session,
          workspaceController: workspaceController,
          onSignOut: authController.signOut,
        );
      },
    );
  }
}

class _SessionRestoreScreen extends StatelessWidget {
  const _SessionRestoreScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A1019),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_basketball_rounded,
              color: Color(0xFFFF7A1A),
              size: 44,
            ),
            SizedBox(height: 18),
            CircularProgressIndicator(color: Color(0xFF2563EB)),
            SizedBox(height: 14),
            Text(
              'Loading Sports Terminal…',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
