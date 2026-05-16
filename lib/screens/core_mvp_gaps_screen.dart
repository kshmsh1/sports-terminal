import '../data/core_mvp_gap_items.dart';
import 'registry_screen_factory.dart';

class CoreMvpGapsScreen extends RegistryScreenFactory {
  const CoreMvpGapsScreen({
    super.key,
  }) : super(
          title: 'Core MVP Gaps',
          subtitle: 'Open gaps between the current architecture-heavy terminal prototype and a genuinely useful NBA-first MVP.',
          items: coreMvpGapItems,
          searchHint: 'Search MVP gap, players, stats, reports...',
          leadTitle: 'MVP Gap Principle',
          leadBody: 'The project should stay honest about what is already real, what is source-pending, and what still needs to be built before the terminal becomes useful to an end user.',
        );
}
