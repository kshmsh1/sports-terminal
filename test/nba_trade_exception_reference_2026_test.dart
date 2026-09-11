import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_trade_exception_reference_2026.dart';

void main() {
  test('full TPE ledger contains source transaction and expiration metadata', () {
    final charlotte = NbaTradeExceptionReference202627.forTeam('CHA', asOfIso: '2026-09-11');
    expect(charlotte, isNotEmpty);
    expect(charlotte.first.available, 40770520);
    expect(charlotte.first.expires, '2027-07-10');
    expect(charlotte.first.sourceTransaction, contains('LaMelo Ball'));
  });

  test('partially used TPE preserves original and remaining balance', () {
    final dallas = NbaTradeExceptionReference202627.tpes.firstWhere((e) => e.id == 'DAL-davis-2027');
    expect(dallas.original, 20830154);
    expect(dallas.available, 7004114);
    expect(dallas.note, contains('Risacher'));
  });

  test('exhausted TPE is excluded from live team list', () {
    final dallas = NbaTradeExceptionReference202627.forTeam('DAL', asOfIso: '2026-09-11');
    expect(dallas.any((e) => e.id == 'DAL-exum-2027'), isFalse);
  });

  test('2026-27 MLE limits match supplied reference', () {
    expect(NbaMleRules202627.room, 9366000);
    expect(NbaMleRules202627.nonTaxpayer, 15044000);
    expect(NbaMleRules202627.taxpayer, 6064000);
    expect(NbaMleRules202627.biAnnual, 5477000);
  });
}
