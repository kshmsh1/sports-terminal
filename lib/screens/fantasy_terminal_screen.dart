import '../data/fantasy_product_items.dart';
import 'registry_screen_factory.dart';

class FantasyTerminalScreen extends RegistryScreenFactory {
  const FantasyTerminalScreen({super.key}) : super(
    title: 'Fantasy Terminal',
    subtitle: 'Fantasy product architecture for leagues, scoring, rosters, waivers, trades, matchups, projections, alerts, and shareable fantasy analysis.',
    items: fantasyProductItems,
    searchHint: 'Search waiver, trade, scoring, matchup...',
    leadTitle: 'Fantasy Principle',
    leadBody: 'Fantasy should be built as a terminal-native workflow that consumes the same player, game, roster, schedule, stat, report, alert, and workspace layers. The first version can start manual before league integrations exist.',
  );
}
