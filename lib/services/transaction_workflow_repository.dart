import 'dart:convert';

import '../models/transaction_workflow.dart';
import 'launch_backend_transport.dart';
import 'product_local_store.dart';

class TransactionWorkflowRepository {
  const TransactionWorkflowRepository({
    ProductLocalStore store = const ProductLocalStore(),
    LaunchBackendTransport transport = const LaunchBackendTransport(),
  })  : _store = store,
        _transport = transport;

  final ProductLocalStore _store;
  final LaunchBackendTransport _transport;

  String activityKey(String organizationId) =>
      'sports_terminal.transaction_activity.organization.$organizationId.v1';
  String notificationKey(String userId) =>
      'sports_terminal.transaction_notifications.user.$userId.v1';
  String memberKey(String organizationId) =>
      'sports_terminal.organization_members.$organizationId.v1';

  Future<List<TransactionActivity>> loadActivities(
    String organizationId,
  ) async {
    final remote = await _transport.getJson(
      '/v2/organizations/${Uri.encodeComponent(organizationId)}/activities',
    );
    final decoded = _decodeRemote(remote, TransactionActivity.fromJson);
    if (decoded != null) {
      await _saveList(
        activityKey(organizationId),
        [for (final item in decoded) item.toJson()],
        250,
      );
      return decoded;
    }
    final raw = await _store.loadString(activityKey(organizationId));
    return _decodeList(raw, TransactionActivity.fromJson);
  }

  Future<void> addActivity(TransactionActivity activity) async {
    final raw = await _store.loadString(activityKey(activity.organizationId));
    final items = _decodeList(raw, TransactionActivity.fromJson);
    final next = [
      activity,
      for (final item in items)
        if (item.id != activity.id) item,
    ];
    await _saveList(
      activityKey(activity.organizationId),
      [for (final item in next) item.toJson()],
      250,
    );
    await _transport.putJson(
      '/v2/activities/${Uri.encodeComponent(activity.id)}',
      {'payload': activity.toJson()},
    );
  }

  Future<List<TransactionNotification>> loadNotifications(
    String userId,
  ) async {
    final remote = await _transport.getJson(
      '/v2/users/${Uri.encodeComponent(userId)}/notifications',
    );
    final decoded = _decodeRemote(remote, TransactionNotification.fromJson);
    if (decoded != null) {
      await _saveList(
        notificationKey(userId),
        [for (final item in decoded) item.toJson()],
        100,
      );
      return decoded;
    }
    final raw = await _store.loadString(notificationKey(userId));
    return _decodeList(raw, TransactionNotification.fromJson);
  }

  Future<void> addNotification(TransactionNotification notification) async {
    if (notification.recipientUserId.isEmpty) return;
    final raw = await _store.loadString(
      notificationKey(notification.recipientUserId),
    );
    final items = _decodeList(raw, TransactionNotification.fromJson);
    final next = [
      notification,
      for (final item in items)
        if (item.id != notification.id) item,
    ];
    await _saveList(
      notificationKey(notification.recipientUserId),
      [for (final item in next) item.toJson()],
      100,
    );
    await _transport.putJson(
      '/v2/notifications/${Uri.encodeComponent(notification.id)}',
      {'payload': notification.toJson()},
    );
  }

  Future<void> markAllNotificationsRead(String userId) async {
    final items = await loadNotifications(userId);
    await _saveList(
      notificationKey(userId),
      [for (final item in items) item.copyWith(isRead: true).toJson()],
      100,
    );
    await _transport.postJson(
      '/v2/users/${Uri.encodeComponent(userId)}/notifications/read-all',
      const {},
    );
  }

  Future<List<OrganizationMemberRecord>> loadMembers(
    String organizationId,
  ) async {
    final remote = await _transport.getJson(
      '/v2/organizations/${Uri.encodeComponent(organizationId)}/member-records',
    );
    final decoded = _decodeRemote(remote, OrganizationMemberRecord.fromJson);
    if (decoded != null) {
      await _saveList(
        memberKey(organizationId),
        [for (final item in decoded) item.toJson()],
        100,
      );
      return decoded;
    }
    final raw = await _store.loadString(memberKey(organizationId));
    return _decodeList(raw, OrganizationMemberRecord.fromJson);
  }

  Future<void> upsertMember(
    String organizationId,
    OrganizationMemberRecord member,
  ) async {
    final raw = await _store.loadString(memberKey(organizationId));
    final items = _decodeList(raw, OrganizationMemberRecord.fromJson);
    final next = [
      member,
      for (final item in items)
        if (item.userId != member.userId) item,
    ];
    await _saveList(
      memberKey(organizationId),
      [for (final item in next) item.toJson()],
      100,
    );
    await _transport.putJson(
      '/v2/organizations/${Uri.encodeComponent(organizationId)}/member-records/${Uri.encodeComponent(member.userId)}',
      {'payload': member.toJson()},
    );
  }

  Future<void> removeMember(String organizationId, String userId) async {
    final raw = await _store.loadString(memberKey(organizationId));
    final items = _decodeList(raw, OrganizationMemberRecord.fromJson);
    await _saveList(
      memberKey(organizationId),
      [
        for (final item in items)
          if (item.userId != userId) item.toJson(),
      ],
      100,
    );
    await _transport.deleteJson(
      '/v2/organizations/${Uri.encodeComponent(organizationId)}/member-records/${Uri.encodeComponent(userId)}',
    );
  }

  List<T>? _decodeRemote<T>(
    LaunchBackendResponse response,
    T Function(Map<String, dynamic>) decode,
  ) {
    if (!response.available || response.data is! List) return null;
    return [
      for (final item in response.data! as List)
        if (item is Map)
          decode(item.map((key, value) => MapEntry(key.toString(), value))),
    ];
  }

  Future<void> _saveList(
    String key,
    List<Map<String, dynamic>> values,
    int limit,
  ) {
    return _store.saveString(key, jsonEncode(values.take(limit).toList()));
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
