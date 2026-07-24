import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/cba_transaction_rules_engine.dart';

void main() {
  const engine = CbaTransactionRulesEngine();
  const cap = 154647000.0;
  const firstApron = 195945000.0;
  const secondApron = 207824000.0;

  test('cap room team can use room created after outgoing salary', () {
    final report = engine.evaluate(
      const TransactionRuleInput(
        currentTeamSalary: 145000000,
        outgoingSalary: 5000000,
        incomingSalary: 14000000,
        salaryCap: cap,
        firstApron: firstApron,
        secondApron: secondApron,
      ),
    );

    expect(report.salaryMatchingMode, TransactionSalaryMatchingMode.capRoom);
    expect(report.maximumIncomingSalary, closeTo(14897000, 0.01));
    expect(report.hasBlockers, isFalse);
  });

  test('expanded below first apron matching calculates scaled allowance', () {
    final report = engine.evaluate(
      const TransactionRuleInput(
        currentTeamSalary: 180000000,
        outgoingSalary: 10000000,
        incomingSalary: 18500000,
        salaryCap: cap,
        firstApron: firstApron,
        secondApron: secondApron,
      ),
    );

    expect(report.salaryMatchingMode, TransactionSalaryMatchingMode.expanded);
    expect(report.maximumIncomingSalary, greaterThan(18500000));
    expect(report.hasBlockers, isFalse);
  });

  test('incoming salary above calculated expanded limit is blocked', () {
    final report = engine.evaluate(
      const TransactionRuleInput(
        currentTeamSalary: 180000000,
        outgoingSalary: 10000000,
        incomingSalary: 19000000,
        salaryCap: cap,
        firstApron: firstApron,
        secondApron: secondApron,
      ),
    );

    expect(report.hasBlockers, isTrue);
    expect(
      report.findings.any(
        (finding) => finding.code == 'SALARY_MATCHING_EXCEEDED',
      ),
      isTrue,
    );
  });

  test('team above first apron receives no additional allowance', () {
    final report = engine.evaluate(
      const TransactionRuleInput(
        currentTeamSalary: 200000000,
        outgoingSalary: 20000000,
        incomingSalary: 20100000,
        salaryCap: cap,
        firstApron: firstApron,
        secondApron: secondApron,
      ),
    );

    expect(report.salaryMatchingMode, TransactionSalaryMatchingMode.standard);
    expect(report.maximumIncomingSalary, 20000000);
    expect(report.hasBlockers, isTrue);
  });

  test('recently acquired aggregation is date aware', () {
    final report = engine.evaluate(
      const TransactionRuleInput(
        currentTeamSalary: 180000000,
        outgoingSalary: 20000000,
        incomingSalary: 20000000,
        salaryCap: cap,
        firstApron: firstApron,
        secondApron: secondApron,
        aggregatesMultiplePlayers: true,
        transactionDateIso: '2026-01-15',
        recentlyAcquiredViaExceptionDateIso: '2025-12-20',
        tradeDeadlineIso: '2026-02-05',
      ),
    );

    expect(
      report.findings.any(
        (finding) => finding.code == 'RECENTLY_ACQUIRED_AGGREGATION',
      ),
      isTrue,
    );
  });
}
