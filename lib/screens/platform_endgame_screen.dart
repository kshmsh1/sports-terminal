import '../data/platform_endgame_items.dart';
import 'registry_screen_factory.dart';

class PlatformEndgameScreen extends RegistryScreenFactory {
  const PlatformEndgameScreen({super.key}) : super(
    title: 'Platform Endgame',
    subtitle: 'North-star architecture for making Sports Terminal an operating system for sports rather than a searchable reference site.',
    items: platformEndgameItems,
    searchHint: 'Search endgame, workspace, network, UI...',
    leadTitle: 'Endgame Principle',
    leadBody: 'The platform should not become a glorified sports encyclopedia. The target is a terminal where users search, manipulate data, build workspaces, compare entities, generate reports, save views, monitor alerts, play fantasy, publish analysis, and collaborate around source-backed sports information.',
  );
}
