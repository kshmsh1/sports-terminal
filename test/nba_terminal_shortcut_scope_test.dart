import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/widgets/nba_terminal_shortcut_scope.dart';

void main() {
  testWidgets('Ctrl+K invokes the global NBA Terminal callback', (tester) async {
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: NbaTerminalShortcutScope(
          onOpen: () => opens += 1,
          child: const Scaffold(body: Text('Terminal host')),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(opens, 1);
  });
}
