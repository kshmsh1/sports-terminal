import '../data/player_identity_contract_items.dart';
import '../data/player_identity_source_items.dart';
import '../data/player_identity_validation_items.dart';
import '../data/pre_data_cutover_items.dart';
import '../models/registry_item.dart';
import 'nba_asset_repository.dart';
import 'player_identity_validator.dart';

class PlayerIdentityImportReadinessSummary {
  const PlayerIdentityImportReadinessSummary({
    required this.currentPlayerRows,
    required this.contractDone,
    required this.validationImplemented,
    required this.sourceRequired,
    required this.cutoverDone,
    required this.validatorBlockers,
    required this.validatorWarnings,
  });

  final int currentPlayerRows;
  final int contractDone;
  final int validationImplemented;
  final int sourceRequired;
  final int cutoverDone;
  final int validatorBlockers;
  final int validatorWarnings;

  bool get localAssetIsClean => validatorBlockers == 0;
  bool get sourceDecisionStillNeeded => sourceRequired > 0;
  bool get canBeginSourceSelection => localAssetIsClean && contractDone == playerIdentityContractItems.length && validationImplemented == playerIdentityValidationItems.length;
  bool get canImportRealRows => canBeginSourceSelection && !sourceDecisionStillNeeded;
}

class PlayerIdentityImportReadinessService {
  const PlayerIdentityImportReadinessService({
    this.repository = const NbaAssetRepository(),
    this.validator = const PlayerIdentityValidator(),
  });

  final NbaAssetRepository repository;
  final PlayerIdentityValidator validator;

  Future<PlayerIdentityImportReadinessSummary> evaluate() async {
    final players = await repository.loadPlayerProfiles();
    final validation = validator.validate(players: players);
    return PlayerIdentityImportReadinessSummary(
      currentPlayerRows: players.length,
      contractDone: _countStatus(playerIdentityContractItems, 'Locked'),
      validationImplemented: _countStatus(playerIdentityValidationItems, 'Implemented'),
      sourceRequired: playerIdentitySourceItems.where((item) => item.status == 'Required').length,
      cutoverDone: _countStatus(preDataCutoverItems, 'Done'),
      validatorBlockers: validation.blockers,
      validatorWarnings: validation.warnings,
    );
  }

  int _countStatus(List<RegistryItem> items, String status) => items.where((item) => item.status == status).length;
}
