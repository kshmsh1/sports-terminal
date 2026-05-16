import '../data/nba_mvp_completion_items.dart';
import 'registry_screen_factory.dart';

class NbaMvpCompletionScreen extends RegistryScreenFactory {
  const NbaMvpCompletionScreen({
    super.key,
  }) : super(
          title: 'NBA MVP Completion',
          subtitle: 'Exit criteria for the first working NBA prototype: reference data, player identity, traditional stats, team context, search, players, stats, compare, reports, and local ship state.',
          items: nbaMvpCompletionItems,
          searchHint: 'Search MVP gate, exit criteria, player data...',
          leadTitle: 'End Platform Principle',
          leadBody: 'The goal is not endless Build Lab expansion. The target is a local NBA-first terminal that works with real historical data, no fake records, strong joins, source metadata, usable search, detail pages, comparisons, and report generation.',
        );
}
