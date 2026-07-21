import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/models/app_session.dart';
import 'package:sports_terminal/models/transaction_workflow.dart';
import 'package:sports_terminal/services/product_local_store.dart';
import 'package:sports_terminal/services/transaction_case_convergence_service.dart';
import 'package:sports_terminal/services/transaction_case_repository.dart';
import 'package:sports_terminal/services/transaction_workflow_repository.dart';

void main() {
  const session = AppSession(
    userId: 'analyst-1',
    email: 'analyst@example.com',
    displayName: 'Analyst One',
    organizationId: 'org-1',
    organizationName: 'Example Basketball Operations',
    role: UserRole.analyst,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('discovers saved Trade Machine and Front Office product state', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      ProductLocalStore.tradeMachineStateKey,
      jsonEncode({
        'year': '2026-27',
        'teams': 'BOS|PHI',
        'name': 'Two-team scenario',
        'destinations': 'BOS%3Aplayer_1=PHI',
        'selectedOnly': 'true',
      }),
    );
    await preferences.setString(
      'sports_terminal.front_office.ledger_v1',
      jsonEncode({
        'season': '2026-27',
        'teamId': 'BOS',
        'deadMoney': '1',
        'capHolds': '2',
        'draftHolds': '0',
        'rosterCharges': '0',
        'contracts': [
          {
            'id': 'contract-1',
            'playerLabel': 'Player One',
            'teamId': 'BOS',
            'season': '2026-27',
            'salary': 25000000,
            'guaranteedAmount': 25000000,
            'noTradeClause': true,
          },
        ],
        'draftAssets': [
          {
            'id': 'pick-1',
            'currentOwner': 'BOS',
            'originalTeam': 'BOS',
            'year': 2028,
            'round': 1,
            'protections': 'Unspecified',
          },
        ],
      }),
    );

    final candidates = await const TransactionCaseConvergenceService().discover();

    expect(candidates.map((item) => item.source), contains('Trade Machine'));
    expect(candidates.map((item) => item.source), contains('Front Office Ledger'));
    final trade = candidates.firstWhere((item) => item.source == 'Trade Machine');
    expect(trade.teams, ['BOS', 'PHI']);
    expect(trade.summary, contains('1 routed assets'));
    final ledger = candidates.firstWhere((item) => item.source == 'Front Office Ledger');
    expect(ledger.currentTeamSalary, 28000000);
    expect(ledger.assumptions, contains('Non-contract charges: \$3.0M.'));
    expect(ledger.findings.any((item) => item.contains('NO_TRADE_CONSENT')), isTrue);
    expect(ledger.findings.any((item) => item.contains('PICK_TERMS_UNVERIFIED')), isTrue);
  });

  test('normalizes saved Cap Lab values from millions to dollars', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      ProductLocalStore.capLabStateKey,
      jsonEncode({
        'team': 'BOS',
        'season': '2026-27',
        'teamSalary': '200',
        'firstApron': '209.015',
        'secondApron': '221.686',
      }),
    );

    final candidates = await const TransactionCaseConvergenceService().discover();
    final cap = candidates.firstWhere((item) => item.source == 'Cap Lab');
    expect(cap.currentTeamSalary, 200000000);
    expect(cap.firstApron, 209015000);
    expect(cap.secondApron, 221686000);
  });

  test('imports a shared candidate into personal and organization cases', () async {
    const candidate = TransactionImportCandidate(
      id: 'candidate-1',
      source: 'Trade Machine',
      title: 'Imported scenario',
      operatingSeason: '2026-27',
      teams: ['BOS', 'PHI'],
      summary: 'Modeled transaction.',
      assumptions: ['Source values are modeled.'],
      sourcePayloadId: 'trade-machine:BOS-PHI:2026-27',
    );

    final item = await const TransactionCaseConvergenceService().importCandidate(
      candidate: candidate,
      session: session,
      organizationVisible: true,
    );

    const cases = TransactionCaseRepository();
    final personal = await cases.loadPersonal(session.userId);
    final organization = await cases.loadOrganization(session.organizationId);
    expect(personal.single.id, item.id);
    expect(organization.single.id, item.id);
    expect(personal.single.isOrganizationVisible, isTrue);
    expect(organization.single.needsApproval, isTrue);
    expect(personal.single.sourcePayloadId, candidate.sourcePayloadId);
  });

  test('persists activities, notifications and organization members', () async {
    const repository = TransactionWorkflowRepository();
    const activity = TransactionActivity(
      id: 'activity-1',
      caseId: 'case-1',
      organizationId: 'org-1',
      actorUserId: 'analyst-1',
      actorName: 'Analyst One',
      kind: TransactionActivityKind.comment,
      message: 'Added context.',
      createdAtIso: '2026-07-21T12:00:00Z',
      recipientUserId: 'reviewer-1',
    );
    const notification = TransactionNotification(
      id: 'notification-1',
      caseId: 'case-1',
      organizationId: 'org-1',
      recipientUserId: 'reviewer-1',
      title: 'Assignment',
      body: 'Review case-1.',
      createdAtIso: '2026-07-21T12:00:00Z',
    );
    const member = OrganizationMemberRecord(
      userId: 'reviewer-1',
      displayName: 'Reviewer One',
      roleLabel: 'Reviewer',
      createdAtIso: '2026-07-21T12:00:00Z',
    );

    await repository.addActivity(activity);
    await repository.addNotification(notification);
    await repository.upsertMember('org-1', member);

    expect((await repository.loadActivities('org-1')).single.message, 'Added context.');
    expect((await repository.loadNotifications('reviewer-1')).single.isRead, isFalse);
    await repository.markAllNotificationsRead('reviewer-1');
    expect((await repository.loadNotifications('reviewer-1')).single.isRead, isTrue);
    expect((await repository.loadMembers('org-1')).single.displayName, 'Reviewer One');
  });
}
