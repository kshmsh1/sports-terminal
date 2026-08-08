import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NbaTerminalShortcutScope extends StatelessWidget {
  const NbaTerminalShortcutScope({
    super.key,
    required this.onOpen,
    required this.child,
  });

  final VoidCallback onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): onOpen,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): onOpen,
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }
}
