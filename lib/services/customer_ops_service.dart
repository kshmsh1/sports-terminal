import 'dart:convert';

import '../models/app_session.dart';
import 'launch_backend_transport.dart';
import 'product_local_store.dart';

class CustomerOpsSnapshot {
  const CustomerOpsSnapshot({
    required this.account,
    required this.organization,
    required this.readiness,
    required this.plans,
    required this.notifications,
    required this.supportTickets,
    required this.privacyRequests,
    required this.invitations,
    required this.components,
    required this.incidents,
    required this.providerOutbox,
    required this.backups,
    required this.retentionPolicies,
    required this.auditEvents,
    required this.remoteAvailable,
    required this.loadedAtIso,
  });

  final Map<String, dynamic> account;
  final Map<String, dynamic> organization;
  final Map<String, dynamic> readiness;
  final List<Map<String, dynamic>> plans;
  final List<Map<String, dynamic>> notifications;
  final List<Map<String, dynamic>> supportTickets;
  final List<Map<String, dynamic>> privacyRequests;
  final List<Map<String, dynamic>> invitations;
  final List<Map<String, dynamic>> components;
  final List<Map<String, dynamic>> incidents;
  final List<Map<String, dynamic>> providerOutbox;
  final List<Map<String, dynamic>> backups;
  final List<Map<String, dynamic>> retentionPolicies;
  final List<Map<String, dynamic>> auditEvents;
  final bool remoteAvailable;
  final String loadedAtIso;

  Map<String, dynamic> get subscription => _map(account['subscription']);
  Map<String, dynamic> get organizationSubscription =>
      _map(organization['subscription']);
  Map<String, dynamic> get onboarding => _map(account['onboarding']);
  Map<String, dynamic> get organizationOnboarding =>
      _map(organization['onboarding']);
  Map<String, dynamic> get providerState => _map(readiness['provider_state']);

  int get unreadNotifications => notifications
      .where((item) => item['status']?.toString() == 'unread')
      .length;
  int get openSupportTickets => supportTickets
      .where((item) => !{'resolved', 'closed'}.contains(item['status']))
      .length;
  int get openPrivacyRequests => privacyRequests
      .where((item) => !{
            'completed',
            'rejected',
            'cancelled',
          }.contains(item['status']))
      .length;
  int get activeIncidents => incidents
      .where((item) => !{
            'resolved',
            'closed',
            'postmortem',
          }.contains(item['status']))
      .length;

  Map<String, dynamic> toJson() => {
        'account': account,
        'organization': organization,
        'readiness': readiness,
        'plans': plans,
        'notifications': notifications,
        'supportTickets': supportTickets,
        'privacyRequests': privacyRequests,
        'invitations': invitations,
        'components': components,
        'incidents': incidents,
        'providerOutbox': providerOutbox,
        'backups': backups,
        'retentionPolicies': retentionPolicies,
        'auditEvents': auditEvents,
        'remoteAvailable': remoteAvailable,
        'loadedAtIso': loadedAtIso,
      };

  factory CustomerOpsSnapshot.fromJson(
    Map<String, dynamic> json, {
    bool? remoteAvailable,
  }) {
    return CustomerOpsSnapshot(
      account: _map(json['account']),
      organization: _map(json['organization']),
      readiness: _map(json['readiness']),
      plans: _list(json['plans']),
      notifications: _list(json['notifications']),
      supportTickets: _list(json['supportTickets']),
      privacyRequests: _list(json['privacyRequests']),
      invitations: _list(json['invitations']),
      components: _list(json['components']),
      incidents: _list(json['incidents']),
      providerOutbox: _list(json['providerOutbox']),
      backups: _list(json['backups']),
      retentionPolicies: _list(json['retentionPolicies']),
      auditEvents: _list(json['auditEvents']),
      remoteAvailable:
          remoteAvailable ?? json['remoteAvailable'] == true,
      loadedAtIso: json['loadedAtIso']?.toString() ?? '',
    );
  }

  static CustomerOpsSnapshot empty() => const CustomerOpsSnapshot(
        account: {},
        organization: {},
        readiness: {},
        plans: [],
        notifications: [],
        supportTickets: [],
        privacyRequests: [],
        invitations: [],
        components: [],
        incidents: [],
        providerOutbox: [],
        backups: [],
        retentionPolicies: [],
        auditEvents: [],
        remoteAvailable: false,
        loadedAtIso: '',
      );
}

class CustomerOpsResult {
  const CustomerOpsResult({
    required this.succeeded,
    required this.available,
    required this.error,
    this.data,
  });

  final bool succeeded;
  final bool available;
  final String error;
  final Object? data;
}

class CustomerOpsService {
  const CustomerOpsService({
    LaunchBackendTransport transport = const LaunchBackendTransport(),
    ProductLocalStore store = const ProductLocalStore(),
  })  : _transport = transport,
        _store = store;

  final LaunchBackendTransport _transport;
  final ProductLocalStore _store;

  static const _cacheKey = 'sports_terminal.customer_ops.snapshot.v1';

  Future<CustomerOpsSnapshot> load(AppSession session) async {
    final organizationMode =
        session.role.canManageOrganization && session.organizationId.isNotEmpty;
    final scopeType = organizationMode ? 'organization' : 'personal';
    final scopeId = organizationMode ? session.organizationId : session.userId;
    final actor = session.userId;

    final accountFuture = _transport.getJson(
      '/v2/customer-ops/account/${session.userId}/overview',
      query: {
        'actor_user_id': actor,
        if (organizationMode) 'organization_id': session.organizationId,
      },
      timeout: const Duration(seconds: 4),
    );
    final plansFuture = _transport.getJson('/v2/customer-ops/plans');
    final notificationsFuture = _transport.getJson(
      '/v2/customer-ops/notifications/${session.userId}',
      query: {'actor_user_id': actor},
    );
    final supportFuture = _transport.getJson(
      '/v2/customer-ops/support/tickets',
      query: {
        'actor_user_id': actor,
        'scope_type': scopeType,
        'scope_id': scopeId,
      },
    );
    final privacyFuture = _transport.getJson(
      '/v2/customer-ops/privacy/requests',
      query: {'actor_user_id': actor, 'user_id': session.userId},
    );
    final readinessFuture = _transport.getJson('/v2/customer-ops/readiness');
    final componentsFuture =
        _transport.getJson('/v2/customer-ops/reliability/components');
    final incidentsFuture =
        _transport.getJson('/v2/customer-ops/reliability/incidents');

    final core = await Future.wait([
      accountFuture,
      plansFuture,
      notificationsFuture,
      supportFuture,
      privacyFuture,
      readinessFuture,
      componentsFuture,
      incidentsFuture,
    ]);

    LaunchBackendResponse? organizationResponse;
    LaunchBackendResponse? invitationsResponse;
    LaunchBackendResponse? auditResponse;
    if (organizationMode) {
      final organizationResults = await Future.wait([
        _transport.getJson(
          '/v2/customer-ops/organizations/${session.organizationId}/overview',
          query: {'actor_user_id': actor},
        ),
        _transport.getJson(
          '/v2/customer-ops/organizations/${session.organizationId}/invitations',
          query: {'actor_user_id': actor},
        ),
        _transport.getJson(
          '/v2/customer-ops/audit',
          query: {
            'actor_user_id': actor,
            'organization_id': session.organizationId,
          },
        ),
      ]);
      organizationResponse = organizationResults[0];
      invitationsResponse = organizationResults[1];
      auditResponse = organizationResults[2];
    }

    LaunchBackendResponse? outboxResponse;
    LaunchBackendResponse? backupsResponse;
    LaunchBackendResponse? retentionResponse;
    if (session.role.canAccessPlatformAdmin) {
      final platformResults = await Future.wait([
        _transport.getJson(
          '/v2/customer-ops/providers/outbox',
          query: {'actor_user_id': actor},
        ),
        _transport.getJson(
          '/v2/customer-ops/reliability/backups',
          query: {'actor_user_id': actor},
        ),
        _transport.getJson(
          '/v2/customer-ops/retention/policies',
          query: {'actor_user_id': actor},
        ),
      ]);
      outboxResponse = platformResults[0];
      backupsResponse = platformResults[1];
      retentionResponse = platformResults[2];
    }

    final responses = <LaunchBackendResponse>[
      ...core,
      if (organizationResponse != null) organizationResponse,
      if (invitationsResponse != null) invitationsResponse,
      if (auditResponse != null) auditResponse,
      if (outboxResponse != null) outboxResponse,
      if (backupsResponse != null) backupsResponse,
      if (retentionResponse != null) retentionResponse,
    ];
    final remoteAvailable = responses.any((response) => response.succeeded);
    final accountResponse = core[0];
    if (!accountResponse.succeeded || accountResponse.data is! Map) {
      final cached = await _loadCache();
      return cached ?? CustomerOpsSnapshot.empty();
    }

    final snapshot = CustomerOpsSnapshot(
      account: _map(accountResponse.data),
      organization: organizationResponse?.succeeded == true
          ? _map(organizationResponse?.data)
          : const {},
      readiness: core[5].succeeded ? _map(core[5].data) : const {},
      plans: core[1].succeeded ? _list(core[1].data) : const [],
      notifications: core[2].succeeded ? _list(core[2].data) : const [],
      supportTickets: core[3].succeeded ? _list(core[3].data) : const [],
      privacyRequests: core[4].succeeded ? _list(core[4].data) : const [],
      invitations: invitationsResponse?.succeeded == true
          ? _list(invitationsResponse?.data)
          : const [],
      components: core[6].succeeded ? _list(core[6].data) : const [],
      incidents: core[7].succeeded ? _list(core[7].data) : const [],
      providerOutbox: outboxResponse?.succeeded == true
          ? _list(outboxResponse?.data)
          : const [],
      backups: backupsResponse?.succeeded == true
          ? _list(backupsResponse?.data)
          : const [],
      retentionPolicies: retentionResponse?.succeeded == true
          ? _list(retentionResponse?.data)
          : const [],
      auditEvents: auditResponse?.succeeded == true
          ? _list(auditResponse?.data)
          : const [],
      remoteAvailable: remoteAvailable,
      loadedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    await _store.saveString(_cacheKey, jsonEncode(snapshot.toJson()));
    return snapshot;
  }

  Future<CustomerOpsResult> updateSubscription({
    required AppSession session,
    required String planId,
    required String status,
    required int seatCount,
    String billingPeriod = 'monthly',
  }) {
    final context = _scope(session);
    return _result(
      _transport.putJson(
        '/v2/customer-ops/subscriptions/${context.type}/${context.id}',
        {
          'actor_user_id': session.userId,
          'scope_type': context.type,
          'scope_id': context.id,
          'plan_id': planId,
          'status': status,
          'billing_period': billingPeriod,
          'seat_count': seatCount,
          'metadata': {
            'source': 'flutter-launch-center',
            'provider_mode': 'outbox_until_configured',
          },
        },
        timeout: const Duration(seconds: 4),
      ),
    );
  }

  Future<CustomerOpsResult> updateOnboarding({
    required AppSession session,
    required List<String> completedSteps,
    required List<String> dismissedSteps,
    required String currentStep,
  }) {
    final context = _scope(session);
    return _result(
      _transport.putJson(
        '/v2/customer-ops/onboarding/${context.type}/${context.id}',
        {
          'actor_user_id': session.userId,
          'scope_type': context.type,
          'scope_id': context.id,
          'completed_steps': completedSteps,
          'dismissed_steps': dismissedSteps,
          'current_step': currentStep,
          'metadata': {'surface': 'launch-center'},
        },
      ),
    );
  }

  Future<CustomerOpsResult> createSupportTicket({
    required AppSession session,
    required String category,
    required String priority,
    required String subject,
    required String body,
  }) {
    final context = _scope(session);
    return _result(
      _transport.postJson(
        '/v2/customer-ops/support/tickets',
        {
          'actor_user_id': session.userId,
          'scope_type': context.type,
          'scope_id': context.id,
          'organization_id': context.type == 'organization' ? context.id : '',
          'category': category,
          'priority': priority,
          'subject': subject,
          'body': body,
          'metadata': {'surface': 'launch-center'},
        },
      ),
    );
  }

  Future<CustomerOpsResult> createPrivacyRequest({
    required AppSession session,
    required String requestType,
    required String details,
  }) {
    return _result(
      _transport.postJson(
        '/v2/customer-ops/privacy/requests',
        {
          'actor_user_id': session.userId,
          'user_id': session.userId,
          'organization_id': session.organizationId,
          'request_type': requestType,
          'details': details,
          'jurisdiction': 'US',
          'metadata': {'surface': 'launch-center'},
        },
      ),
    );
  }

  Future<CustomerOpsResult> createInvitation({
    required AppSession session,
    required String email,
    required String role,
    required String message,
  }) {
    return _result(
      _transport.postJson(
        '/v2/customer-ops/organizations/${session.organizationId}/invitations',
        {
          'actor_user_id': session.userId,
          'email': email,
          'role': role,
          'expires_in_days': 7,
          'message': message,
        },
      ),
    );
  }

  Future<CustomerOpsResult> notificationAction({
    required AppSession session,
    required String notificationId,
    required String action,
  }) {
    return _result(
      _transport.postJson(
        '/v2/customer-ops/notifications/$notificationId/action',
        {'actor_user_id': session.userId, 'action': action},
      ),
    );
  }

  Future<CustomerOpsResult> createIncident({
    required AppSession session,
    required String severity,
    required String title,
    required String summary,
    required List<String> componentIds,
  }) {
    return _result(
      _transport.postJson(
        '/v2/customer-ops/reliability/incidents',
        {
          'actor_user_id': session.userId,
          'severity': severity,
          'title': title,
          'summary': summary,
          'component_ids': componentIds,
          'metadata': {'surface': 'launch-center'},
        },
      ),
    );
  }

  Future<CustomerOpsResult> providerOutboxAction({
    required AppSession session,
    required String eventId,
    required String action,
  }) {
    return _result(
      _transport.postJson(
        '/v2/customer-ops/providers/outbox/$eventId/action',
        {'actor_user_id': session.userId, 'action': action, 'error': ''},
      ),
    );
  }

  Future<CustomerOpsResult> _result(
    Future<LaunchBackendResponse> request,
  ) async {
    final response = await request;
    return CustomerOpsResult(
      succeeded: response.succeeded,
      available: response.available,
      error: response.error,
      data: response.data,
    );
  }

  Future<CustomerOpsSnapshot?> _loadCache() async {
    final raw = await _store.loadString(_cacheKey);
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return CustomerOpsSnapshot.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
          remoteAvailable: false,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  _CustomerOpsScope _scope(AppSession session) {
    final organization =
        session.role.canManageOrganization && session.organizationId.isNotEmpty;
    return _CustomerOpsScope(
      type: organization ? 'organization' : 'personal',
      id: organization ? session.organizationId : session.userId,
    );
  }
}

class _CustomerOpsScope {
  const _CustomerOpsScope({required this.type, required this.id});
  final String type;
  final String id;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) _map(item),
  ];
}
