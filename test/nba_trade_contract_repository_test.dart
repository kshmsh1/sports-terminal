import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_trade_contract_repository.dart';

void main() {
  test('loads the uploaded 2026-27 salary universe', () async {
    final snapshot = await const NbaTradeContractRepository().load();

    expect(snapshot.records.length, 475);
    expect(snapshot.teams.length, 30);
    expect(snapshot.asOf, '2026-09-11');
  });

  test('preserves known player salaries and current-team deduping', () async {
    final snapshot = await const NbaTradeContractRepository().load();

    final curry = snapshot.records.singleWhere((row) => row.player == 'Stephen Curry');
    expect(curry.team, 'GSW');
    expect(curry.salaryFor('2026-27'), 62587158);

    final beal = snapshot.records.singleWhere((row) => row.player == 'Bradley Beal');
    expect(beal.team, 'LAC');
    expect(beal.salaryFor('2026-27'), 25807810);
  });
}
