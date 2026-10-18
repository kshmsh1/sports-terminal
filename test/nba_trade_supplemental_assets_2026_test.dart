import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_trade_supplemental_assets_2026.dart';
import 'package:sports_terminal/services/nba_two_way_contract_reference_2026.dart';
import 'package:sports_terminal/services/nba_exhibit_contract_reference_2026.dart';

void main() {
  test('supplied draft-rights ledger is broadly installed', () {
    expect(NbaTradeSupplementalAssets202627.draftRights.length, 49);

    final knicks =
        NbaTradeSupplementalAssets202627.draftRightsFor('NYK');
    expect(knicks.length, 18);
    expect(knicks.any((item) => item.player == 'Sergio Llull'), isTrue);

    final celtics =
        NbaTradeSupplementalAssets202627.draftRightsFor('BOS');
    expect(celtics.map((item) => item.player),
        containsAll(<String>['Juhann Begarin', 'Yam Madar']));

    final sixers =
        NbaTradeSupplementalAssets202627.draftRightsFor('PHI');
    expect(sixers.single.player, 'Justinian Jessup');

    expect(
      NbaTradeSupplementalAssets202627.draftRightsCertifiedForTeam('SAS'),
      isTrue,
    );
    expect(
      NbaTradeSupplementalAssets202627.draftRightsCertifiedForTeam('ATL'),
      isFalse,
    );
  });

  test('October two-way refresh matches supplied source examples', () {
    expect(
      NbaTwoWayContractReference202627.forTeam('DEN')
          .any((item) => item.player == 'Ryan Nembhard'),
      isTrue,
    );
    expect(
      NbaTwoWayContractReference202627.forTeam('GSW')
          .any((item) => item.player == 'Graham Ike'),
      isTrue,
    );
    expect(
      NbaTwoWayContractReference202627.forTeam('TOR')
          .any((item) => item.player == 'Malachi Smith'),
      isTrue,
    );
  });

  test('Exhibit 9 and 10 source table is installed', () {
    expect(NbaExhibitContractReference202627.records, isNotEmpty);
    expect(
      NbaExhibitContractReference202627.forTeam('NYK')
          .any((item) => item.player == 'Tony Bradley' && item.exhibit == 9),
      isTrue,
    );
    expect(
      NbaExhibitContractReference202627.forTeam('BOS')
          .any((item) => item.player == 'Hayden Gray' && item.exhibit == 10),
      isTrue,
    );
  });
}
