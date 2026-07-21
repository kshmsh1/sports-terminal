import 'dart:convert';

import '../models/transaction_workflow.dart';
import 'product_local_store.dart';

class TransactionWorkflowRepository {
  const TransactionWorkflowRepository({
    ProductLocalStore store = const ProductLocalStore(),
  }) : _store = store;

  final ProductLocalStore _store;

  String activityKey(String organizationId) =>
      'sports_terminal.transaction_activity.organization.$organizationId.v1';
  String notificationKey(String userId) =>
      'sports_terminal.transaction_notifications.user.$userId.v1';
  String memberKey(String organizationId) =>
      'sports_terminal.organization_members.$organizationId.v1';

  Future<List<TransactionActivity>> loadActivities(String organizationId) async {
    final raw = await _store.loadString(activityKey(organizationId));
    return _decodeList(raw, TransactionActivity.fromJson);
  }

  Future<void> addActivity(TransactionActivity activity) async {
    final items = await loadActivities(activity.organizationId);
    final next = [
      activity,
      for (final item in items)
        if (item.id != activity.id) item,
    ];
    await _store.saveString(
      activityKey(activity.organizationId),
      jsonEncode([for (final item in next.take(250)) item.toJson()]),
    );
  }

  Future<List<TransactionNotification>> loadNotifications(String userId) async {
    final raw = await _store.loadString(notificationKey(userId));
    return _decodeList(raw, TransactionNotification.fromJson);
  }

  Future<void> addNotification(TransactionNotification notification) async {
    if (notification.recipientUserId.isEmpty) return;
    final items = await loadNotifications(notification.recipientUserId);
    final next = [
      notification,
      for (final item in items)
        if (item.id != notification.id) item,
    ];
    await _store.saveString(
      notificationKey(notification.recipientUserId),
      jsonEncode([for (final item in next.take(100)) item.toJson()]),
    );
  }

  Future<void> markAllNotificationsRead(String userId) async {
    final items = await loadNotifications(userId);
    await _store.saveString(
      notificationKey(userId),
      jsonEncode([for (final item in items) item.copyWith(isRead: true).toJson()]),
    );
  }

  Future<List<OrganizationMemberRecord>> loadMembers(
    String organizationId,
  ) async {
    final raw = await _store.loadString(memberKey(organizationId));
    return _decodeList(raw, OrganizationMemberRecord.fromJson);
  }

  Future<void> upsertMember(
    String organizationId,
    OrganizationMemberRecord member,
  ) async {
    final items = await loadMembers(organizationId);
    final next = [
      member,
      for (final item in items)
        if (item.userId != member.userId) item,
    ];
    await _store.saveString(
      memberKey(organizationId),
      jsonEncode([for (final item in next.take(100)) item.toJson()]),
    );
  }

  Future<void> removeMember(String organizationId, String userId) async {
    final items = await loadMembers(organizationId);
    await _store.saveString(
      memberKey(organizationId),
      jsonEncode([
        for (final item in items)
          if (item.userId != userId) item.toJson(),
      ]),
    );
  }

  List<T> _decodeList<T>(
    String raw,
    T Function(Map<String, dynamic>) decode,
  ) {
    if (raw.trim().isEmpty) return <T>[];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return <T>[];
      return [
        for (final item in parsed)
          if (item is Map)
            decode(item.map((key, value) => MapEntry(key.toString(), value))),
      ];
    } catch (_) {
      return <T>[];
    }
  }
}
