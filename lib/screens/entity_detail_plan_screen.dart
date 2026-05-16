import '../data/entity_detail_plan_items.dart';
import 'registry_screen_factory.dart';

class EntityDetailPlanScreen extends RegistryScreenFactory {
  const EntityDetailPlanScreen({
    super.key,
  }) : super(
          title: 'Entity Detail Plan',
          subtitle: 'Detail-page planning for player, team, season, game, draft class, and transaction pages.',
          items: entityDetailPlanItems,
          searchHint: 'Search entity detail, player, team, season...',
          leadTitle: 'Detail Page Principle',
          leadBody: 'The terminal becomes valuable when lists turn into connected detail pages with source-backed data, reports, comparisons, and missing-data visibility.',
        );
}
