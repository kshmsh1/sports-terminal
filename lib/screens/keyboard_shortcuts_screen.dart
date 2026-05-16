import '../data/keyboard_shortcut_items.dart';
import 'registry_screen_factory.dart';

class KeyboardShortcutsScreen extends RegistryScreenFactory {
  const KeyboardShortcutsScreen({
    super.key,
  }) : super(
          title: 'Keyboard Shortcuts',
          subtitle: 'Future power-user shortcut map for search, navigation, reports, tables, and selected-row actions.',
          items: keyboardShortcutItems,
          searchHint: 'Search shortcut, navigation, table, report...',
          leadTitle: 'Shortcut Principle',
          leadBody: 'A terminal-style product should eventually support keyboard-first workflows. For now this screen captures the intended shortcut map before implementation.',
        );
}
