import '../data/integration_plan_items.dart';
import 'registry_screen_factory.dart';

class IntegrationPlanScreen extends RegistryScreenFactory {
  const IntegrationPlanScreen({
    super.key,
  }) : super(
          title: 'Integration Plan',
          subtitle: 'Integration path from local JSON assets to official snapshots, manual curation, local persistence, future APIs, and licensed feeds.',
          items: integrationPlanItems,
          searchHint: 'Search integration, backend, source, persistence...',
          leadTitle: 'Integration Principle',
          leadBody: 'Build the zero-cost local MVP first. Keep the architecture ready for APIs and licensed feeds later, but do not introduce paid or complex dependencies before the product proves useful.',
        );
}
