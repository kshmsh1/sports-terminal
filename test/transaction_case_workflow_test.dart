import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/transaction_case.dart';
import 'package:sports_terminal/services/cba_transaction_rules_engine.dart';

void main() {
  test('transaction case round trips with approvals and comments', () {
    const transactionCase = TransactionCase(
      id: 'case-1',
      title: 'BOS PHI modeled trade',
      organizationId: 'org-1',
      organizationName: 'Example Organization',
      ownerUserId: 'user-1',
      ownerName: 'Analyst One',
      operatingSeason: '2026-27',
      teams: ['BOS', 'PHI'],
      status: TransactionCaseStatus.review,
      priority: TransactionCasePriority.high,
      createdAtIso: '2026-07-21T00:00:00Z',
      updatedAtIso: '2026-07-21T00:00:00Z',
      approvals: [
        TransactionApproval(
          approverId: 'admin-1',
          approverName: 'Admin One',
          decision: TransactionApprovalDecision.pending,
          updatedAtIso: '2026-07-21T00:00:00Z',
        ),
      ],
      comments: [
        TransactionCaseComment(
          authorId: 'user-1',
          authorName: 'Analyst One',
          body: 'Initial modeled case.',
          createdAtIso: '2026-07-21T00:00:00Z',
        ),
      ],
      isOrganizationVisible: true,
    );
    final decoded = TransactionCase.fromJson(transactionCase.toJson());
    expect(decoded.title, transactionCase.title);
    expect(decoded.teams, ['BOS', 'PHI']);
    expect(decoded.approvals.single.decision,
        TransactionApprovalDecision.pending);
    expect(decoded.comments.single.body, 'Initial modeled case.');
    expect(decoded.needsApproval, isTrue);
  });

  test('second apron aggregation and cash create blockers', () {
    final report = const CbaTransactionRulesEngine().evaluate(
      const TransactionRuleInput(
        currentTeamSalary: 225000000,
        outgoingSalary: 20000000,
        incomingSalary: 22000000,
        salaryCap: 164961000,
        firstApron: 209015000,
        secondApron: 221686000,
        aggregatesMultiplePlayers: true,
        usesCash: true,
      ),
    );
    expect(report.hasBlockers, isTrue);
    expect(report.outcome, 'Blocked');
    expect(
      report.findings.any(
        (finding) => finding.code == 'SECOND_APRON_AGGREGATION',
      ),
      isTrue,
    );
    expect(
      report.findings.any(
        (finding) => finding.code == 'SECOND_APRON_CASH',
      ),
      isTrue,
    );
  });

  test('preliminary clear still carries final review disclaimer', () {
    final report = const CbaTransactionRulesEngine().evaluate(
      const TransactionRuleInput(
        currentTeamSalary: 150000000,
        outgoingSalary: 20000000,
        incomingSalary: 18000000,
        salaryCap: 164961000,
        firstApron: 209015000,
        secondApron: 221686000,
      ),
    );
    expect(report.hasBlockers, isFalse);
    expect(report.outcome, 'Preliminary clear');
    expect(report.findings.single.code, 'PRELIMINARY_CLEAR');
  });
}
