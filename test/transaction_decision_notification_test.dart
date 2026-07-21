import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/models/transaction_case.dart';
import 'package:sports_terminal/services/transaction_case_repository.dart';
import 'package:sports_terminal/services/transaction_workflow_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('organization approval notifies the case owner and records activity', () async {
    const cases = TransactionCaseRepository();
    const workflow = TransactionWorkflowRepository();
    const pending = TransactionCase(
      id: 'case-1',
      title: 'Two-team trade review',
      organizationId: 'org-1',
      organizationName: 'Example Basketball Operations',
      ownerUserId: 'analyst-1',
      ownerName: 'Analyst One',
      operatingSeason: '2026-27',
      teams: <String>['BOS', 'PHI'],
      status: TransactionCaseStatus.review,
      priority: TransactionCasePriority.high,
      createdAtIso: '2026-07-21T12:00:00Z',
      updatedAtIso: '2026-07-21T12:00:00Z',
      approvals: <TransactionApproval>[
        TransactionApproval(
          approverId: 'reviewer-1',
          approverName: 'Reviewer One',
          decision: TransactionApprovalDecision.pending,
          updatedAtIso: '2026-07-21T12:00:00Z',
        ),
      ],
      isOrganizationVisible: true,
    );

    await cases.upsertOrganization('org-1', pending);
    await cases.upsertOrganization(
      'org-1',
      pending.copyWith(
        status: TransactionCaseStatus.approved,
        updatedAtIso: '2026-07-21T13:00:00Z',
        approvals: const <TransactionApproval>[
          TransactionApproval(
            approverId: 'reviewer-1',
            approverName: 'Reviewer One',
            decision: TransactionApprovalDecision.approved,
            updatedAtIso: '2026-07-21T13:00:00Z',
          ),
        ],
      ),
    );

    final notices = await workflow.loadNotifications('analyst-1');
    final activity = await workflow.loadActivities('org-1');
    expect(notices, hasLength(1));
    expect(notices.single.title, 'Transaction case approved');
    expect(notices.single.body, contains('Reviewer One'));
    expect(activity, hasLength(1));
    expect(activity.single.message, contains('approved'));
  });
}
