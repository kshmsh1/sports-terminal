import 'dart:convert';

import '../models/transaction_case.dart';
import '../models/transaction_workflow.dart';
import 'launch_backend_transport.dart';
import 'product_local_store.dart';
import 'transaction_workflow_repository.dart';

class TransactionCaseRepository {
  const TransactionCaseRepository({
    ProductLocalStore store = const ProductLocalStore(),
    TransactionWorkflowRepository workflow =
        const TransactionWorkflowRepository(),
    LaunchBackendTransport transport = const LaunchBackendTransport(),
  })  : _store = store,
        _workflow = workflow,
        _transport = transport;

  final ProductLocalStore _store;
  final TransactionWorkflowRepository _workflow;
  final LaunchBackendTransport _transport;

  String personalKey(String userId) =>
      'sports_terminal.transaction_cases.personal.$userId.v1';

  String organizationKey(String organizationId) =>
      'sports_terminal.transaction_cases.organization.$organizationId.v1';

  Future<List<TransactionCase>> loadPersonal(String userId) async {
    final remote = await _transport.getJson(
      '/v2/transaction-cases',
      query: {
        'owner_user_id': userId,
        'scope': 'personal',
      },
    );
    final decoded = _decodeRemote(remote);
    if (decoded != null) {
      await _saveLocal(personalKey(userId), decoded);
      return decoded;
    }
    return _loadLocal(personalKey(userId));
  }

  Future<List<TransactionCase>> loadOrganization(String organizationId) async {
    final remote = await _transport.getJson(
      '/v2/transaction-cases',
      query: {
        'organization_id': organizationId,
        'scope': 'organization',
      },
    );
    final decoded = _decodeRemote(remote);
    if (decoded != null) {
      await _saveLocal(organizationKey(organizationId), decoded);
      return decoded;
    }
    return _loadLocal(organizationKey(organizationId));
  }

  Future<void> savePersonal(
    String userId,
    List<TransactionCase> cases,
  ) async {
    await _saveLocal(personalKey(userId), cases);
    for (final item in cases) {
      await _remoteUpsert(item, scope: 'personal', actorUserId: userId);
    }
  }

  Future<void> saveOrganization(
    String organizationId,
    List<TransactionCase> cases,
  ) async {
    await _saveLocal(organizationKey(organizationId), cases);
    for (final item in cases) {
      await _remoteUpsert(
        item.copyWith(isOrganizationVisible: true),
        scope: 'organization',
        actorUserId: _actorFor(item),
      );
    }
  }

  Future<void> upsertPersonal(
    String userId,
    TransactionCase transactionCase,
  ) async {
    final cases = await loadPersonal(userId);
    final next = _upsert(cases, transactionCase);
    await _saveLocal(personalKey(userId), next);
    await _remoteUpsert(
      transactionCase,
      scope: 'personal',
      actorUserId: userId,
    );
  }

  Future<void> upsertOrganization(
    String organizationId,
    TransactionCase transactionCase,
  ) async {
    final cases = await loadOrganization(organizationId);
    final previous = _findCase(cases, transactionCase.id);
    final shared = transactionCase.copyWith(isOrganizationVisible: true);
    await _saveLocal(organizationKey(organizationId), _upsert(cases, shared));
    await _remoteUpsert(
      shared,
      scope: 'organization',
      actorUserId: _actorFor(shared),
    );
    await _recordDecisionChange(previous: previous, current: shared);
  }

  Future<void> publishToOrganization(TransactionCase transactionCase) async {
    final shared = transactionCase.copyWith(isOrganizationVisible: true);
    await upsertOrganization(shared.organizationId, shared);
    await upsertPersonal(shared.ownerUserId, shared);
  }

  Future<void> removePersonal(String userId, String caseId) async {
    final cases = await loadPersonal(userId);
    await _saveLocal(
      personalKey(userId),
      cases.where((item) => item.id != caseId).toList(),
    );
    await _transport.deleteJson(
      '/v2/transaction-cases/$caseId',
      query: {
        'actor_user_id': userId,
        'owner_user_id': userId,
        'scope': 'personal',
      },
    );
  }

  Future<void> removeOrganization(
    String organizationId,
    String caseId,
  ) async {
    final cases = await loadOrganization(organizationId);
    final existing = _findCase(cases, caseId);
    await _saveLocal(
      organizationKey(organizationId),
      cases.where((item) => item.id != caseId).toList(),
    );
    await _transport.deleteJson(
      '/v2/transaction-cases/$caseId',
      query: {
        'actor_user_id': existing == null ? '' : _actorFor(existing),
        'organization_id': organizationId,
        'scope': 'organization',
      },
    );
  }

  Future<void> _remoteUpsert(
    TransactionCase item, {
    required String scope,
    required String actorUserId,
  }) async {
    await _transport.putJson(
      '/v2/transaction-cases/${Uri.encodeComponent(item.id)}',
      {
        'actor_user_id': actorUserId.isEmpty ? item.ownerUserId : actorUserId,
        'scope': scope,
        'case': item.toJson(),
      },
    );
  }

  List<TransactionCase>? _decodeRemote(LaunchBackendResponse response) {
    if (!response.available || response.data is! List) return null;
    final cases = <TransactionCase>[];
    for (final item in response.data! as List) {
      if (item is Map) {
        cases.add(
          TransactionCase.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
    }
    cases.sort((a, b) => b.updatedAtIso.compareTo(a.updatedAtIso));
    return cases;
  }

  String _actorFor(TransactionCase item) {
    for (final approval in item.approvals.reversed) {
      if (approval.approverId.isNotEmpty) return approval.approverId;
    }
    return item.ownerUserId;
  }

  Future<void> _recordDecisionChange({
    required TransactionCase? previous,
    required TransactionCase current,
  }) async {
    final currentDecision = _latestResolvedApproval(current);
    if (currentDecision == null) return;
    final previousDecision =
        previous == null ? null : _latestResolvedApproval(previous);
    if (previousDecision?.decision == currentDecision.decision &&
        previousDecision?.updatedAtIso == currentDecision.updatedAtIso) {
      return;
    }

    final approved =
        currentDecision.decision == TransactionApprovalDecision.approved;
    final rejected =
        currentDecision.decision == TransactionApprovalDecision.rejected;
    final decisionLabel = approved
        ? 'approved'
        : rejected
            ? 'rejected'
            : 'returned for changes';
    final title = approved
        ? 'Transaction case approved'
        : rejected
            ? 'Transaction case rejected'
            : 'Changes requested';
    final now = currentDecision.updatedAtIso.isEmpty
        ? DateTime.now().toUtc().toIso8601String()
        : currentDecision.updatedAtIso;
    final actorName = currentDecision.approverName.isEmpty
        ? current.organizationName
        : currentDecision.approverName;

    await _workflow.addActivity(
      TransactionActivity(
        id: 'decision_${current.id}_${currentDecision.decision.name}_$now',
        caseId: current.id,
        organizationId: current.organizationId,
        actorUserId: currentDecision.approverId,
        actorName: actorName,
        kind: TransactionActivityKind.approval,
        message: '$actorName $decisionLabel “${current.title}”.',
        createdAtIso: now,
        recipientUserId: current.ownerUserId,
      ),
    );
    await _workflow.addNotification(
      TransactionNotification(
        id: 'decision_notice_${current.id}_${currentDecision.decision.name}_$now',
        caseId: current.id,
        organizationId: current.organizationId,
        recipientUserId: current.ownerUserId,
        title: title,
        body: '$actorName $decisionLabel ${current.title}.',
        createdAtIso: now,
      ),
    );
  }

  TransactionApproval? _latestResolvedApproval(TransactionCase item) {
    for (final approval in item.approvals.reversed) {
      if (approval.decision != TransactionApprovalDecision.pending) {
        return approval;
      }
    }
    return null;
  }

  TransactionCase? _findCase(List<TransactionCase> cases, String caseId) {
    for (final item in cases) {
      if (item.id == caseId) return item;
    }
    return null;
  }

  Future<List<TransactionCase>> _loadLocal(String key) async {
    final raw = await _store.loadString(key);
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final cases = <TransactionCase>[
        for (final item in decoded)
          if (item is Map)
            TransactionCase.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
      ];
      cases.sort((a, b) => b.updatedAtIso.compareTo(a.updatedAtIso));
      return cases;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveLocal(String key, List<TransactionCase> cases) async {
    final sorted = [...cases]
      ..sort((a, b) => b.updatedAtIso.compareTo(a.updatedAtIso));
    await _store.saveString(
      key,
      jsonEncode([for (final item in sorted.take(100)) item.toJson()]),
    );
  }

  List<TransactionCase> _upsert(
    List<TransactionCase> cases,
    TransactionCase transactionCase,
  ) {
    return [
      transactionCase,
      for (final item in cases)
        if (item.id != transactionCase.id) item,
    ];
  }
}

class TransactionCaseMetrics {
  const TransactionCaseMetrics({
    required this.total,
    required this.drafts,
    required this.inReview,
    required this.approved,
    required this.blocked,
    required this.urgent,
  });

  final int total;
  final int drafts;
  final int inReview;
  final int approved;
  final int blocked;
  final int urgent;

  factory TransactionCaseMetrics.fromCases(List<TransactionCase> cases) {
    return TransactionCaseMetrics(
      total: cases.length,
      drafts: cases
          .where((item) => item.status == TransactionCaseStatus.draft)
          .length,
      inReview: cases
          .where((item) => item.status == TransactionCaseStatus.review)
          .length,
      approved: cases
          .where((item) => item.status == TransactionCaseStatus.approved)
          .length,
      blocked: cases.where((item) => item.hasBlockingDecision).length,
      urgent: cases
          .where((item) => item.priority == TransactionCasePriority.urgent)
          .length,
    );
  }
}
