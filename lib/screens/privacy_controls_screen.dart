import '../data/privacy_control_items.dart';
import 'registry_screen_factory.dart';

class PrivacyControlsScreen extends RegistryScreenFactory {
  const PrivacyControlsScreen({
    super.key,
  }) : super(
          title: 'Privacy Controls',
          subtitle: 'Privacy and rights boundary planning for local-first development, user notes, source citations, licensed data, and exports.',
          items: privacyControlItems,
          searchHint: 'Search privacy, rights, storage, export...',
          leadTitle: 'Privacy Principle',
          leadBody: 'The prototype should stay local-first, avoid user tracking, and clearly separate user-created content from source-backed sports data and restricted third-party materials.',
        );
}
