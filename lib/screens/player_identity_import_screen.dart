import '../data/player_identity_import_items.dart';
import '../data/source_backed_nba_data_wave_items.dart';
import 'registry_screen_factory.dart';

class PlayerIdentityImportScreen extends RegistryScreenFactory {
  const PlayerIdentityImportScreen({
    super.key,
  }) : super(
          title: 'Player Identity Import + NBA Data Wave',
          subtitle: 'Execution plan for turning source-pending player identity into real validated NBA player rows, then unlocking traditional stats, team stats, standings, playoffs, MVP voting, games, rosters, draft, and transactions.',
          items: const [...playerIdentityImportItems, ...sourceBackedNbaDataWaveItems],
          searchHint: 'Search player import, source path, identity, aliases, stats, MVP, games...',
          leadTitle: 'Player Identity and Data Wave Principle',
          leadBody: 'Player identity should come before player statistics. Freeze the route payload layer first, then publish stable player IDs, then import traditional stats, then add standings, playoffs, MVP voting, games, rosters, draft, and transactions. Do not fake rows while sources are pending.',
        );
}
