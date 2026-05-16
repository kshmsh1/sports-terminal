import '../data/performance_budget_items.dart';
import 'registry_screen_factory.dart';

class PerformanceBudgetScreen extends RegistryScreenFactory {
  const PerformanceBudgetScreen({
    super.key,
  }) : super(
          title: 'Performance Budget',
          subtitle: 'Planning surface for startup load, screen load, table rows, search responsiveness, navigation scale, asset size, and future charting performance.',
          items: performanceBudgetItems,
          searchHint: 'Search startup, screen, table, search, asset...',
          leadTitle: 'Performance Principle',
          leadBody: 'The local JSON MVP can stay fast if screens load only what they need and large datasets are split before they become too heavy.',
        );
}
