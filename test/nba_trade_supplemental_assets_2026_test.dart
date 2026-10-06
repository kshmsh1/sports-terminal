import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_trade_supplemental_assets_2026.dart';

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
}
