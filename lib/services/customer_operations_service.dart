import 'dart:convert';

import '../models/app_session.dart';
import 'launch_backend_transport.dart';
import 'product_local_store.dart';

class CustomerOperationsSnapshot {
  const CustomerOperationsSnapshot({
    required this.scope,
    required this.onboarding,
    required this.entitlement,
    required this.notificationPreferences,
    required this.notifications,
    required this.supportCases,
    required this.incidents,
    required this.usage,
    required this.remoteAvailable,
    required this.error,
  });

  final String scope;
  final Map<String, dynamic> onboarding;
  final Map<String, dynamic> entitlement;
  final Map<String, dynamic> notificationPreferences;
  final List<Map<String, dynamic>> notifications;
  final List<Map<String, dynamic>> supportCases;
  final List<Map<String, dynamic>> incidents;
  final Map<String, dynamic> usage;
  final bool remoteAvailable;
  final String error;

  int get unreadNotifications => _integer(usage['unread_notifications']);
  int get openSupportCases => _integer(usage['open_support_cases']);
  int get activeIncidents => _integer(usage['active_incidents']);
  int get activeMembers => _integer(usage['active_members']);
  int get seatLimit => _integer(usage['seat_limit']);

  static int _integer(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

class CustomerOperationsService {
  const CustomerOperationsService({
    LaunchBackendTransport transport = const LaunchBackendTransport(),
    ProductLocalStore store = const ProductLocalStore(),
  })  : _transport = transport,
        _store = store;

  final LaunchBackendTransport _transport;
  final ProductLocalStore _store;

  static const _cacheKey = 'sports_terminal.customer_operations.snapshot.v1';

  Future<CustomerOperationsSnapshot> load(AppSession session) async {
    final context = _context(session);
    final response = await _transport.getJson(
      '/v2/customer-operations/snapshot',
      query: {
        'actor_user_id': session.userId,
        'scope': context.scope,
        'owner_user_id': session.userId,
        if (context.organizationId.isNotEmpty) 'organization_id': context.organizationId,
      },
      timeout: const Duration(seconds: 4),
    );
    if (response.succeeded && response.data is Map) {
      final data = _map(response.data as Map);
      await _store.saveString(_cacheKey, jsonEncode(data));
      return _fromMap(data, remoteAvailable: true);
    }
    final cached = await _store.loadString(_cacheKey);
    if (cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map) {
          return _fromMap(
            _map(decoded),
            remoteAvailable: false,
            error: response.error,
          );
        }
      } catch (_) {
        // Fall through to a launch-safe empty snapshot.
      }
    }
    return CustomerOperationsSnapshot(
      scope: context.scope,
      onboarding: const {'completed_steps': <String>[]},
      entitlement: {
        'plan_id': context.scope == 'organization' ? 'organization' : 'individual',
        'status': 'offline',
        'seats': context.scope == 'organization' ? 10 : 1,
        'features': const <String>[],
        'limits': const <String, int>{},
      },
      notificationPreferences: const {},
      notifications: const [],
      supportCases: const [],
      incidents: const [],
      usage: {
        'active_members': 1,
        'seat_limit': context.scope == 'organization' ? 10 : 1,
        'unread_notifications': 0,
        'open_support_cases': 0,
        'active_incidents': 0,
      },
      remoteAvailable: false,
      error: response.error,
    );
  }

  Future<bool> saveOnboarding({
    required AppSession session,
    required Set<String> completedSteps,
    Set<String> dismissedSteps = const {},
  }) async {
    final context = _context(session);
    final response = await _transport.putJson(
      '/v2/customer-operations/onboarding',
      {
        'actor_user_id': session.userId,
        'scope': context.scope,
        'owner_user_id': session.userId,
        'organization_id': context.organizationId,
        'completed_steps': completedSteps.toList()..sort(),
        'dismissed_steps': dismissedSteps.toList()..sort(),
        'metadata': {'surface': 'launch_center'},
      },
    );
    return response.succeeded;
  }

  Future<bool> saveNotificationPreferences({
    required AppSession session,
    required Map<String, dynamic> preferences,
  }) async {
    final response = await _transport.putJson(
      '/v2/customer-operations/notification-preferences',
      {
        'actor_user_id': session.userId,
        'email_digest': preferences['email_digest'] == true,
        'product_updates': preferences['product_updates'] != false,
        'data_release_alerts': preferences['data_release_alerts'] != false,
        'case_assignments': preferences['case_assignments'] != false,
        'transaction_changes': preferences['transaction_changes'] != false,
        'community_activity': preferences['community_activity'] != false,
        'security_alerts': preferences['security_alerts'] != false,
        'quiet_hours_start': preferences['quiet_hours_start']?.toString() ?? '',
        'quiet_hours_end': preferences['quiet_hours_end']?.toString() ?? '',
        'metadata': {'surface': 'launch_center'},
      },
    );
    return response.succeeded;
  }

  Future<bool> markNotificationRead({
    required AppSession session,
    required String notificationId,
  }) async {
    final response = await _transport.postJson(
      '/v2/customer-operations/notifications/$notificationId/read',
      const {},
      query: {'actor_user_id': session.userId},
    );
    return response.succeeded;
  }

  Future<bool> markAllNotificationsRead(AppSession session) async {
    final response = await _transport.postJson(
      '/v2/customer-operations/notifications/read-all',
      const {},
      query: {'actor_user_id': session.userId},
    );
    return response.succeeded;
  }

  Future<Map<String, dynamic>?> createSupportCase({
    required AppSession session,
    required String category,
    required String priority,
    required String subject,
    required String description,
    String routeContext = '',
    Map<String, dynamic> diagnostics = const {},
  }) async {
    final context = _context(session);
    final response = await _transport.postJson(
      '/v2/customer-operations/support-cases',
      {
        'actor_user_id': session.userId,
        'scope': context.scope,
        'owner_user_id': session.userId,
        'organization_id': context.organizationId,
        'category': category,
        'priority': priority,
        'subject': subject,
        'description': description,
        'route_context': routeContext,
        'diagnostics': diagnostics,
      },
      timeout: const Duration(seconds: 4),
    );
    if (!response.succeeded || response.data is! Map) return null;
    return _map(response.data as Map);
  }

  Future<bool> addSupportComment({
    required AppSession session,
    required String caseId,
    required String body,
    bool internal = false,
  }) async {
    final response = await _transport.postJson(
      '/v2/customer-operations/support-cases/$caseId/comments',
      {
        'actor_user_id': session.userId,
        'body': body,
        'internal': internal,
      },
    );
    return response.succeeded;
  }

  Future<Map<String, dynamic>?> createIncident({
    required AppSession session,
    required String title,
    required String summary,
    required String severity,
    required List<String> affectedModules,
  }) async {
    if (session.organizationId.isEmpty) return null;
    final response = await _transport.postJson(
      '/v2/customer-operations/incidents',
      {
        'actor_user_id': session.userId,
        'organization_id': session.organizationId,
        'title': title,
        'summary': summary,
        'severity': severity,
        'status': 'investigating',
        'affected_modules': affectedModules,
        'metadata': {'surface': 'launch_center'},
      },
    );
    if (!response.succeeded || response.data is! Map) return null;
    return _map(response.data as Map);
  }

  _CustomerContext _context(AppSession session) {
    final organization =
        session.role.canManageOrganization && session.organizationId.isNotEmpty;
    return _CustomerContext(
      scope: organization ? 'organization' : 'personal',
      organizationId: organization ? session.organizationId : '',
    );
  }

  CustomerOperationsSnapshot _fromMap(
    Map<String, dynamic> data, {
    required bool remoteAvailable,
    String error = '',
  }) {
    return CustomerOperationsSnapshot(
      scope: data['scope']?.toString() ?? 'personal',
      onboarding: _mapOrEmpty(data['onboarding']),
      entitlement: _mapOrEmpty(data['entitlement']),
      notificationPreferences: _mapOrEmpty(data['notification_preferences']),
      notifications: _list(data['notifications']),
      supportCases: _list(data['support_cases']),
      incidents: _list(data['incidents']),
      usage: _mapOrEmpty(data['usage']),
      remoteAvailable: remoteAvailable,
      error: error,
    );
  }

  static List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) _map(item),
    ];
  }

  static Map<String, dynamic> _mapOrEmpty(dynamic value) {
    return value is Map ? _map(value) : <String, dynamic>{};
  }

  static Map<String, dynamic> _map(Map value) => value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
}

class _CustomerContext {
  const _CustomerContext({required this.scope, required this.organizationId});

  final String scope;
  final String organizationId;
}
