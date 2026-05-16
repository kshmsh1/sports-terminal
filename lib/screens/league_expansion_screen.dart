import '../data/league_expansion_items.dart';
import 'registry_screen_factory.dart';

class LeagueExpansionScreen extends RegistryScreenFactory {
  const LeagueExpansionScreen({
    super.key,
  }) : super(
          title: 'League Expansion',
          subtitle: 'Expansion roadmap for NBA-first development, G League bridge, WNBA, college basketball, NFL, and global football later.',
          items: leagueExpansionItems,
          searchHint: 'Search league, sport, expansion, G League...',
          leadTitle: 'Expansion Principle',
          leadBody: 'The product should become sport-agnostic eventually, but the first working system should be NBA-first and complete enough to prove the architecture.',
        );
}
