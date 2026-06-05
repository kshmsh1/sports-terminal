import '../data/import_acceptance_gate_items.dart';
import '../data/player_identity_contract_items.dart';
import '../data/player_identity_import_items.dart';
import '../data/player_identity_schema_gate_items.dart';
import '../data/pre_data_readiness_items.dart';
import '../data/source_backed_nba_data_wave_items.dart';
import 'registry_screen_factory.dart';

class PlayerIdentityImportScreen extends RegistryScreenFactory {
  const PlayerIdentityImportScreen({
    super.key,
  }) : super(
          title: 'Player Identity Import + Pre-Data Gate',
          subtitle: 'Execution plan for finishing the pre-data phase, locking player identity, validating import acceptance, and then unlocking the first real NBA data wave.',
          items: const [
            ...preDataReadinessItems,
            ...playerIdentityContractItems,
            ...playerIdentitySchemaGateItems,
            ...importAcceptanceGateItems,
            ...playerIdentityImportItems,
            ...sourceBackedNbaDataWaveItems,
          ],
          searchHint: 'Search pre-data gate, player contract, player schema, import acceptance, source path, aliases, stats, MVP, games...',
          leadTitle: 'Pre-Data Finish Line Principle',
          leadBody: 'The terminal should not endlessly add architecture. The pre-data phase ends when route payload consumers, player identity schema, source posture, and import acceptance checks are strong enough for player identity to become the first real source-backed NBA data unlock.',
        );
}
