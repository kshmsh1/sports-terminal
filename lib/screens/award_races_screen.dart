import '../data/award_race_items.dart';
import 'registry_screen_factory.dart';

class AwardRacesScreen extends RegistryScreenFactory {
  const AwardRacesScreen({super.key}) : super(
    title: 'Award Races',
    subtitle: 'Award race architecture for winners, finalists, vote rank, points, first place votes, vote share, season context, and player or team links.',
    items: awardRaceItems,
    searchHint: 'Search MVP, DPOY, voting, finalists...',
    leadTitle: 'Award Race Principle',
    leadBody: 'Awards should preserve the full race context. The terminal should show who won, who finished behind, how voting broke down, what team context mattered, and how each race links back to player and season pages.',
  );
}
