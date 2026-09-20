import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_team_salary_position_2026.dart';
import 'package:sports_terminal/services/nba_trade_kicker_reference_2026.dart';

void main() {
  test('team salary positions cover all 30 NBA teams', () {
    expect(NbaTeamSalaryPosition202627.positions.length, 30);
    expect(
      NbaTeamSalaryPosition202627.forTeam('OKC')!.totalSalary,
      235297492,
    );
    expect(
      NbaTeamSalaryPosition202627.forTeam('DET')!.totalSalary,
      154139633,
    );
  });

  test('active, max-voided, future and waived kickers remain distinct', () {
    expect(
      NbaTradeKickerReference202627.forPlayer('OG Anunoby')!.affects202627,
      isTrue,
    );
    expect(
      NbaTradeKickerReference202627.forPlayer('Stephen Curry')!.status,
      NbaTradeKickerStatus.voidedAtMaxSalary,
    );
    expect(
      NbaTradeKickerReference202627.forPlayer('Victor Wembanyama')!.status,
      NbaTradeKickerStatus.futureExtension,
    );
    expect(
      NbaTradeKickerReference202627.forPlayer('Kawhi Leonard')!.status,
      NbaTradeKickerStatus.waivedOnTrade,
    );
  });
}
