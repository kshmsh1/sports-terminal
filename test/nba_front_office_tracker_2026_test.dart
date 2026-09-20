import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_front_office_tracker_2026.dart';
import 'package:sports_terminal/services/nba_transaction_history_2026.dart';

void main() {
  test('DPE tracker preserves current 2026-27 exceptions', () {
    expect(NbaFrontOfficeTracker202627.dpe['HOU']!.available, 12500000);
    expect(NbaFrontOfficeTracker202627.dpe['IND']!.available, 15044000);
  });

  test('hard-cap trigger history distinguishes first and second apron caps', () {
    expect(NbaFrontOfficeTracker202627.hardCaps['ATL']!.capLevel, 'first');
    expect(NbaFrontOfficeTracker202627.hardCaps['HOU']!.capLevel, 'second');
    expect(
      NbaFrontOfficeTracker202627.hardCaps['PHO']!.secondApronTriggers,
      isNotEmpty,
    );
  });

  test('luxury tax tracker preserves repeater flags', () {
    expect(NbaFrontOfficeTracker202627.luxuryTax['GSW']!.repeater, isTrue);
    expect(NbaFrontOfficeTracker202627.luxuryTax['NYK']!.taxedAmount, 30231337);
  });

  test('offseason transaction history exposes recent acquisition dates', () {
    expect(
      NbaTransactionHistory2026.mostRecentAcquisitionDate('Kawhi Leonard'),
      '2026-09-14',
    );
    expect(
      NbaTransactionHistory2026.mostRecentAcquisitionDate('Ja Morant'),
      '2026-06-29',
    );
  });
}
