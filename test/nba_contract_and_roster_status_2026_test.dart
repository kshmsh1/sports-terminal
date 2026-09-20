import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_contract_status_reference_2026.dart';
import 'package:sports_terminal/services/nba_draft_asset_status_2026.dart';
import 'package:sports_terminal/services/nba_extension_reference_2026.dart';
import 'package:sports_terminal/services/nba_league_environment_2026.dart';
import 'package:sports_terminal/services/nba_two_way_contract_reference_2026.dart';

void main() {
  test('two-way roster exposes open slots', () {
    expect(NbaTwoWayContractReference202627.forTeam('ATL').length, 3);
    expect(NbaTwoWayContractReference202627.openSlots('ATL'), 0);
    expect(NbaTwoWayContractReference202627.openSlots('NYK'), 3);
  });

  test('cash trade tracker preserves separate send and receive limits', () {
    expect(NbaCashTradeReference202627.teams['CLE']!.availableToSend, 1145000);
    expect(NbaCashTradeReference202627.teams['UTA']!.availableToReceive, 4495000);
    expect(
      NbaCashTradeReference202627.teams['DEN']!.sendRestrictedAboveSecondApron,
      isTrue,
    );
  });

  test('January 15 restrictions and guarantees are structured', () {
    expect(
      NbaContractStatusReference202627.january15
          .any((item) => item.player == 'Austin Reaves'),
      isTrue,
    );
    expect(
      NbaContractStatusReference202627.guaranteeTriggers
          .any((item) => item.player == 'Moussa Cisse'),
      isTrue,
    );
  });

  test('draft status preserves frozen picks and Stepien flag', () {
    expect(NbaDraftAssetStatus202627.frozenFirsts.length, 4);
    expect(
      NbaDraftAssetStatus202627.firstRound2027['PHI']!.stepienRestricted,
      isTrue,
    );
  });

  test('extension reference preserves options and kickers', () {
    final victor = NbaExtensionReference202627.records
        .firstWhere((item) => item.player == 'Victor Wembanyama');
    expect(victor.playerOption, isTrue);
    expect(victor.tradeKickerPercent, 15);
  });
}
