import 'dart:convert';

import '../models/transaction_case.dart';
import 'product_local_store.dart';

class TransactionCaseRepository {
  const TransactionCaseRepository({
    ProductLocalStore store = const ProductLocalStore(),
  }) : _store = store;

  final ProductLocalStore _store;

  String personalKey(String userId) =>
      'sports_terminal.transaction_cases.personal.$userId.v1';

  String organizationKey(String organizationId) =>
      'sports_terminal.transaction_cases.organization.$organizationId.v1';

  Future<List<TransactionCase>> loadPersonal(String userId) {
    return _load(personalKey(userId));
  }

  Future<List<TransactionCase>> loadOrganization(String organizationId) {
    return _load(organizationKey(organizationId));
  }

  Future<void> savePersonal(
    String userId,
    List<TransactionCase> cases,
  ) {
    return _save(personalKey(userId), cases);
  }

  Future<void> saveOrganization(
    String organizationId,
    List<TransactionCase> cases,
  ) {
    return _save(organizationKey(organizationId), cases);
  }

  Future<void> upsertPersonal(
    String userId,
    TransactionCase transactionCase,
  ) async {
    final cases = await loadPersonal(userId);
    await savePersonal(userId, _upsert(cases, transactionCase));
  }

  Future<void> upsertOrganization(
    String organizationId,
    TransactionCase transactionCase,
  ) async {
    final cases = await loadOrganization(organizationId);
    await saveOrganization(
      organizationId,
      _upsert(cases, transactionCase.copyWith(isOrganizationVisible: true)),
    );
  }

  Future<void> publishToOrganization(TransactionCase transactionCase) async {
    await upsertOrganization(
      transactionCase.organizationId,
      transactionCase.copyWith(isOrganizationVisible: true),
    );
    await upsertPersonal(
      transactionCase.ownerUserId,
      transactionCase.copyWith(isOrganizationVisible: true),
    );
  }

  Future<void> removePersonal(String userId, String caseId) async {
    final cases = await loadPersonal(userId);
    await savePersonal(
      userId,
      cases.where((item) => item.id != caseId).toList(),
    );
  }

  Future<void> removeOrganization(
    String organizationId,
    String caseId,
  ) async {
    final cases = await loadOrganization(organizationId);
    await saveOrganization(
      organizationId,
      cases.where((item) => item.id != caseId).toList(),
    );
  }

  Future<List<TransactionCase>> _load(String key) async {
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

  Future<void> _save(String key, List<TransactionCase> cases) async {
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
