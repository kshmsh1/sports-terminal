import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_trade_machine_reference_2026.dart';

void main() {
  test('Trade Machine team picker exposes all 30 teams and conferences', () {
    expect(NbaTradeMachineReference202627.teams.length, 30);
    expect(
      NbaTradeMachineReference202627.teams.where((item) => item.conference == 'East').length,
      15,
    );
    expect(
      NbaTradeMachineReference202627.teams.where((item) => item.conference == 'West').length,
      15,
    );
    expect(
      NbaTradeMachineReference202627.team('BOS')?.displayName,
      'Boston Celtics',
    );
  });

  test('recording-backed reacquisition restrictions are preserved', () {
    final george = NbaTradeMachineReference202627.reacquisition(
      'Paul George',
      'BOS',
      'PHI',
    );
    expect(george, isNotNull);
    expect(george?.eligibleDate, '2027-07-01');

    final brown = NbaTradeMachineReference202627.reacquisition(
      'Jaylen Brown',
      'PHI',
      'BOS',
    );
    expect(brown, isNotNull);
  });

  test('recording-backed Boston free-agent rights include Kyle Lowry S&T range', () {
    final rows = NbaTradeMachineReference202627.freeAgentsFor('BOS');
    expect(rows.map((item) => item.player), contains('Kyle Lowry'));
    final lowry = rows.singleWhere((item) => item.player == 'Kyle Lowry');
    expect(lowry.rights, 'UFA · Early Bird');
    expect(lowry.capHold, 2449421);
    expect(lowry.minimumFirstYearSalary, 3876529);
    expect(lowry.maximumFirstYearSalary, 27678571);
    expect(lowry.defaultFirstYearSalary, 5500000);
  });
}
