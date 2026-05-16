import '../data/advanced_stat_taxonomy_items.dart';
import 'registry_screen_factory.dart';

class AdvancedStatTaxonomyScreen extends RegistryScreenFactory {
  const AdvancedStatTaxonomyScreen({
    super.key,
  }) : super(
          title: 'Advanced Stat Taxonomy',
          subtitle: 'Stat-family architecture for traditional, rate-adjusted, efficiency, advanced, defensive, tracking, lineup, proprietary, regular-season, and playoff views.',
          items: advancedStatTaxonomyItems,
          searchHint: 'Search PF, per 36, TS%, EPM, DARKO, lineup...',
          leadTitle: 'Stat Taxonomy Principle',
          leadBody: 'The terminal should not dump every metric into one table. Stats need families, view modes, source labels, regular-season/playoff splits, and a clear separation between official, derived, tracking, and third-party metrics.',
        );
}
