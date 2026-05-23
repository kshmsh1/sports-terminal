import '../data/immediate_release_items.dart';
import 'registry_screen_factory.dart';

class CoreMvpGapsScreen extends RegistryScreenFactory {
  const CoreMvpGapsScreen({super.key}) : super(
    title: 'Immediate Release Payloads',
    subtitle: 'First working route payloads for Teams, Seasons, Workspace, Compare, Reports, Saved Views, Export, Alerts, Dashboard, Search, and Action Center.',
    items: immediateReleaseItems,
    searchHint: 'Search immediate release payload...',
    leadTitle: 'First Workflow Release',
    leadBody: 'Use connected Teams, Seasons, and operations rows as the first real workflow payloads before importing player and stat data.',
  );
}
