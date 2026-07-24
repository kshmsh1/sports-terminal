import 'package:flutter/material.dart';

import 'controllers/auth_controller.dart';
import 'controllers/internal_workspace_controller.dart';
import 'controllers/route_payload_controller.dart';
import 'widgets/app_entry_gate.dart';

void main() {
  runApp(const SportsTerminalApp());
}

class SportsTerminalApp extends StatefulWidget {
  const SportsTerminalApp({super.key});

  @override
  State<SportsTerminalApp> createState() => _SportsTerminalAppState();
}

class _SportsTerminalAppState extends State<SportsTerminalApp> {
  final routePayloadController = RoutePayloadController();
  final authController = AuthController();
  final workspaceController = InternalWorkspaceController();

  @override
  void initState() {
    super.initState();
    routePayloadController.hydrate();
    authController.hydrate();
  }

  @override
  void dispose() {
    routePayloadController.dispose();
    authController.dispose();
    workspaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RoutePayloadScope(
      controller: routePayloadController,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Sports Terminal',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8AB4F8),
            brightness: Brightness.dark,
          ),
          fontFamily: 'SF Pro Display',
          useMaterial3: true,
        ),
        home: AppEntryGate(
          authController: authController,
          workspaceController: workspaceController,
        ),
      ),
    );
  }
}
