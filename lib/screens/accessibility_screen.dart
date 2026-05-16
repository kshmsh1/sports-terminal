import '../data/accessibility_items.dart';
import 'registry_screen_factory.dart';

class AccessibilityScreen extends RegistryScreenFactory {
  const AccessibilityScreen({
    super.key,
  }) : super(
          title: 'Accessibility',
          subtitle: 'Accessibility planning for contrast, keyboard navigation, semantics, table overflow, empty-state clarity, and responsive guardrails.',
          items: accessibilityItems,
          searchHint: 'Search contrast, keyboard, labels, responsive...',
          leadTitle: 'Accessibility Principle',
          leadBody: 'A dense terminal can still be readable and navigable if accessibility is planned from the beginning rather than retrofitted later.',
        );
}
