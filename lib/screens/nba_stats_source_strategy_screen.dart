import '../data/nba_stats_source_strategy_items.dart';
import 'registry_screen_factory.dart';

class NbaStatsSourceStrategyScreen extends RegistryScreenFactory {
  const NbaStatsSourceStrategyScreen({
    super.key,
  }) : super(
          title: 'NBA Stats Source Strategy',
          subtitle: 'Source strategy for using NBA.com/stats as the preferred statistical source while preserving rights posture, local snapshots, validation, and zero-cost MVP architecture.',
          items: nbaStatsSourceStrategyItems,
          searchHint: 'Search NBA stats source, scraping, API, terms...',
          leadTitle: 'NBA.com/stats Principle',
          leadBody: 'NBA.com/stats should be treated as the preferred statistical source target, but the app should not depend on live scraping. The correct path is source discovery, permitted-use review, raw local snapshots, normalization, validation, then app-ready JSON assets.',
        );
}
