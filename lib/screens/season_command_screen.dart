import '../data/season_command_items.dart';
import 'registry_screen_factory.dart';

class SeasonCommandScreen extends RegistryScreenFactory {
  const SeasonCommandScreen({
    super.key,
  }) : super(
          title: 'Season Command Plan',
          subtitle: 'Core product plan for turning each NBA season into a central command object with identity, era, standings, teams, playoffs, awards, draft, and reports.',
          items: seasonCommandItems,
          searchHint: 'Search season command, standings, playoffs, awards...',
          leadTitle: 'Season Command Principle',
          leadBody: 'A season is one of the most important terminal objects because it connects teams, players, standings, awards, playoffs, draft context, era context, and reports.',
        );
}
