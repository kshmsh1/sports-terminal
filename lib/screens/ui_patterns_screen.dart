import '../data/ux_pattern_items.dart';
import 'registry_screen_factory.dart';

class UiPatternsScreen extends RegistryScreenFactory {
  const UiPatternsScreen({
    super.key,
  }) : super(
          title: 'UI Patterns',
          subtitle: 'Reusable interface patterns for empty states, metric cards, tables, detail panels, filters, sidebar navigation, and readiness language.',
          items: uxPatternItems,
          searchHint: 'Search UI pattern, layout, table, navigation...',
          leadTitle: 'UI Principle',
          leadBody: 'The terminal should feel consistent even while expanding quickly. Reusable patterns keep the interface understandable before visual polish becomes the priority.',
        );
}
