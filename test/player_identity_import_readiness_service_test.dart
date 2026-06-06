import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/data/player_identity_contract_items.dart';
import 'package:sports_terminal/data/player_identity_validation_items.dart';
import 'package:sports_terminal/services/player_identity_import_readiness_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('player identity import readiness evaluates current assets', () async {
    final summary = await const PlayerIdentityImportReadinessService().evaluate();

    expect(summary.currentPlayerRows, greaterThanOrEqualTo(0));
    expect(summary.currentAliasRows, greaterThanOrEqualTo(0));
    expect(summary.validatorBlockers, 0);
    expect(summary.contractDone, playerIdentityContractItems.length);
    expect(summary.validationImplemented, playerIdentityValidationItems.length);
    expect(summary.canBeginSourceSelection, isTrue);
  });
}
