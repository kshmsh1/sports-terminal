import '../data/context_data_validation_items.dart';
import '../data/detail_data_validation_items.dart';
import '../data/early_wave_gate_items.dart';
import '../data/import_acceptance_gate_items.dart';
import '../data/player_identity_contract_items.dart';
import '../data/player_identity_import_items.dart';
import '../data/player_identity_schema_gate_items.dart';
import '../data/player_identity_source_items.dart';
import '../data/player_identity_validation_items.dart';
import '../data/player_season_stat_validation_items.dart';
import '../data/pre_data_completion_items.dart';
import '../data/pre_data_cutover_items.dart';
import '../data/pre_data_rc_items.dart';
import '../data/pre_data_readiness_items.dart';
import '../data/pre_player_stats_gate_items.dart';
import '../data/real_data_import_stage_items.dart';
import '../data/source_backed_nba_data_wave_items.dart';
import '../data/source_review_gate_items.dart';
import '../data/team_season_stat_validation_items.dart';
import 'registry_screen_factory.dart';

class PlayerIdentityImportScreen extends RegistryScreenFactory {
  const PlayerIdentityImportScreen({super.key}) : super(
    title: 'Player Identity Import + Pre-Data Gate',
    subtitle: 'Execution plan for finishing the pre-data phase, locking player identity, validating import acceptance, and then unlocking the first real NBA data wave.',
    items: const [
      ...preDataRcItems,
      ...preDataCompletionItems,
      ...realDataImportStageItems,
      ...preDataCutoverItems,
      ...preDataReadinessItems,
      ...sourceReviewGateItems,
      ...earlyWaveGateItems,
      ...playerIdentitySourceItems,
      ...playerIdentityContractItems,
      ...playerIdentitySchemaGateItems,
      ...playerIdentityValidationItems,
      ...importAcceptanceGateItems,
      ...playerIdentityImportItems,
      ...prePlayerStatsGateItems,
      ...playerSeasonStatValidationItems,
      ...teamSeasonStatValidationItems,
      ...contextDataValidationItems,
      ...detailDataValidationItems,
      ...sourceBackedNbaDataWaveItems,
    ],
    searchHint: 'Search RC, completion, real data stage, cutover, early wave, source decision, validation, standings, playoffs, awards, games, rosters, draft, transactions, pre-data gate, source review, player contract, import acceptance, aliases...',
    leadTitle: 'Pre-Data Finish Line Principle',
    leadBody: 'The terminal should not endlessly add architecture. The pre-data phase ends when route payload consumers, player identity schema, source posture, validators, import tools, and no-fake-data gates are strong enough for real NBA source rows to become the main blocker.',
  );
}
