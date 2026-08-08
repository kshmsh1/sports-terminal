import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('future-backed state updates use block-bodied setState callbacks', () {
    const forbiddenByFile = <String, List<String>>{
      'lib/screens/product_nba_terminal_screen.dart': [
        'setState(() => _terminalStateFuture =',
      ],
      'lib/screens/product_nba_research_command_center_screen.dart': [
        'setState(() => _workspaceFuture =',
      ],
      'lib/screens/product_connected_network_screens.dart': [
        'setState(() => future = _load())',
        'setState(() => conversationsFuture = service.conversations',
      ],
      'lib/screens/product_launch_center_screen.dart': [
        'setState(() => future = service.load',
      ],
      'lib/screens/product_connected_workspace_screen.dart': [
        'setState(() => future = widget.service.permissions',
      ],
      'lib/screens/product_front_office_registry_screen.dart': [
        'setState(() => future = _load())',
      ],
      'lib/screens/product_nba_entity_command_center_screen.dart': [
        'setState(() => _seasonFuture =',
        'setState(() => _contextFuture =',
        'setState(() => _watchlistFuture =',
      ],
      'lib/screens/product_nba_historical_intelligence_screen.dart': [
        'setState(() => _contextFuture =',
      ],
      'lib/widgets/launch_role_product_shell.dart': [
        'setState(() => _statusFuture =',
      ],
    };

    for (final entry in forbiddenByFile.entries) {
      final source = File(entry.key).readAsStringSync();
      for (final forbidden in entry.value) {
        expect(
          source,
          isNot(contains(forbidden)),
          reason:
              '${entry.key} must not use a Future-valued expression as the return value of a setState callback: $forbidden',
        );
      }
    }
  });
}
