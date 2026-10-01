import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/services/trade_machine_saved_trade_store.dart';

void main() {
  test('saved Trade Machine snapshots round-trip and preserve latest-first order',
      () async {
    SharedPreferences.setMockInitialValues({});
    const store = TradeMachineSavedTradeStore();

    const first = TradeMachineSavedTrade(
      id: 'one',
      savedAtIso: '2026-09-30T12:00:00',
      teams: ['BOS', 'PHI'],
      routes: {'BOS:jayson-tatum': 'PHI'},
      routeLabels: {'BOS:jayson-tatum': 'Jayson Tatum'},
      cashAmounts: {},
      cashDestinations: {},
      signAndTradeDestinations: {},
      signAndTradeSalaries: {},
      acquisitionMechanisms: {'BOS:jayson-tatum': 'tpe:BOS-demo'},
      renouncedFreeAgentRights: ['fa-right:PHI:kyle-lowry'],
      incomingAssets: {
        'BOS': [],
        'PHI': ['Jayson Tatum'],
      },
      passed: true,
      restrictionMode: 'on',
    );
    const second = TradeMachineSavedTrade(
      id: 'two',
      savedAtIso: '2026-09-30T12:05:00',
      teams: ['MEM', 'BOS', 'PHI'],
      routes: {},
      routeLabels: {},
      cashAmounts: {'MEM': 1000000},
      cashDestinations: {'MEM': 'BOS'},
      signAndTradeDestinations: {},
      signAndTradeSalaries: {},
      incomingAssets: {
        'MEM': [],
        'BOS': ['Cash considerations'],
        'PHI': [],
      },
      passed: false,
      restrictionMode: 'off',
    );

    await store.save(first);
    await store.save(second);

    final rows = await store.load();
    expect(rows.map((item) => item.id), ['two', 'one']);
    expect(rows.first.cashAmounts['MEM'], 1000000);
    expect(rows.last.routes['BOS:jayson-tatum'], 'PHI');
    expect(rows.last.acquisitionMechanisms['BOS:jayson-tatum'], 'tpe:BOS-demo');
    expect(rows.last.renouncedFreeAgentRights, ['fa-right:PHI:kyle-lowry']);
    expect(rows.last.incomingAssets['PHI'], ['Jayson Tatum']);

    final afterDelete = await store.delete('two');
    expect(afterDelete.single.id, 'one');
  });
}
