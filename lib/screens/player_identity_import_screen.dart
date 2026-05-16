import '../data/player_identity_import_items.dart';
import 'registry_screen_factory.dart';

class PlayerIdentityImportScreen extends RegistryScreenFactory {
  const PlayerIdentityImportScreen({
    super.key,
  }) : super(
          title: 'Player Identity Import',
          subtitle: 'Execution plan for turning the source-pending player profile asset into real, validated, source-backed NBA player identity records.',
          items: playerIdentityImportItems,
          searchHint: 'Search player import, source, fields, validation...',
          leadTitle: 'Player Identity Principle',
          leadBody: 'Player identity should come before player statistics. Every player stat, award, roster entry, draft pick, injury, transaction, and G League assignment depends on stable player IDs.',
        );
}
