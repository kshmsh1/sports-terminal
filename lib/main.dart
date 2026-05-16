import 'package:flutter/material.dart';

import 'widgets/terminal_shell.dart';

void main() {
  runApp(const SportsTerminalApp());
}

class SportsTerminalApp extends StatelessWidget {
  const SportsTerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const TerminalShell(),
    );
  }
}
