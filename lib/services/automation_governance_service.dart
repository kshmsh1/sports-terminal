import '../models/app_session.dart';
import 'launch_backend_transport.dart';

class AutomationGovernanceService {
  const AutomationGovernanceService({
    LaunchBackendTransport transport = const LaunchBackendTransport(),
  }) : _transport = transport;

  final LaunchBackendTransport _transport;

  Map<String, String> _scopeQuery(AppSession session) {
    final organization = session.role.canManageOrganization && session.organizationId.isNotEmpty;
    return {
      'owner_user_id': session.userId,
      'scope': organization ? 'organization' : 'personal',
      if (organization) 'organization_id': session.organizationId,
    };
  }

  Map<String, dynamic> _scopeBody(AppSession session) {
    final organization = session.role.canManageOrganization && session.organizationId.isNotEmpty;
    return {
      'actor_user_id': session.userId,
      'owner_user_id': session.userId,
      'scope': organization ? 'organization' : 'personal',
      'organization_id': organization ? session.organizationId : '',
    };
  }

  Future<Map<String, dynamic>> snapshot(AppSession session) async {
    final response = await _transport.getJson(
      '/v2/automation-governance/snapshot',
      query: _scopeQuery(session),
    );
    return _map(response.data);
  }

  Future<List<Map<String, dynamic>>> alertRules(AppSession session) async {
    final response = await _transport.getJson(
      '/v2/automation-governance/alert-rules',
      query: _scopeQuery(session),
    );
    return _list(response.data);
  }

  Future<bool> saveAlertRule({
    required AppSession session,
    required String id,
    required String name,
    required String category,
    required Map<String, dynamic> condition,
    bool enabled = true,
  }) async {
    final response = await _transport.putJson(
      '/v2/automation-governance/alert-rules/$id',
      {
        ..._scopeBody(session),
        'name': name,
        'category': category,
        'condition': condition,
        'delivery_channels': const ['in_app'],
        'enabled': enabled,
        'cooldown_minutes': 60,
      },
    );
    return response.succeeded;
  }

  Future<List<Map<String, dynamic>>> scheduledReports(AppSession session) async {
    final response = await _transport.getJson(
      '/v2/automation-governance/scheduled-reports',
      query: _scopeQuery(session),
    );
    return _list(response.data);
  }

  Future<bool> saveScheduledReport({
    required AppSession session,
    required String id,
    required String title,
    required String reportType,
    required String schedule,
  }) async {
    final response = await _transport.putJson(
      '/v2/automation-governance/scheduled-reports/$id',
      {
        ..._scopeBody(session),
        'title': title,
        'report_type': reportType,
        'source_route': reportType,
        'schedule': schedule,
        'delivery_channels': const ['in_app'],
        'recipients': const [],
        'filters': const {},
        'enabled': true,
      },
    );
    return response.succeeded;
  }

  Future<List<Map<String, dynamic>>> exports(AppSession session) async {
    final response = await _transport.getJson(
      '/v2/automation-governance/exports',
      query: _scopeQuery(session),
    );
    return _list(response.data);
  }

  Future<bool> requestExport(AppSession session, String type) async {
    final response = await _transport.postJson(
      '/v2/automation-governance/exports',
      {
        ..._scopeBody(session),
        'export_type': type,
        'filters': const {},
        'format': 'json',
      },
    );
    return response.succeeded;
  }

  Future<List<Map<String, dynamic>>> invites(AppSession session) async {
    if (!session.role.canManageOrganization || session.organizationId.isEmpty) return const [];
    final response = await _transport.getJson(
      '/v2/automation-governance/organizations/${session.organizationId}/invites',
      query: {'actor_user_id': session.userId},
    );
    return _list(response.data);
  }

  Future<Map<String, dynamic>?> createInvite({
    required AppSession session,
    required String email,
    required String role,
  }) async {
    final response = await _transport.postJson(
      '/v2/automation-governance/organizations/${session.organizationId}/invites',
      {
        'actor_user_id': session.userId,
        'organization_id': session.organizationId,
        'email': email,
        'role': role,
      },
    );
    return response.succeeded ? _map(response.data) : null;
  }

  Future<List<Map<String, dynamic>>> deliveryJobs(AppSession session) async {
    final response = await _transport.getJson(
      '/v2/automation-governance/delivery-jobs',
      query: session.role.canManageOrganization && session.organizationId.isNotEmpty
          ? {'organization_id': session.organizationId}
          : {'user_id': session.userId},
    );
    return _list(response.data);
  }

  Future<List<Map<String, dynamic>>> audit(AppSession session) async {
    final response = await _transport.getJson(
      '/v2/automation-governance/governance-audit',
      query: {
        if (session.role.canManageOrganization && session.organizationId.isNotEmpty)
          'organization_id': session.organizationId,
      },
    );
    return _list(response.data);
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) return const [];
    return [for (final item in value) if (item is Map) _map(item)];
  }
}
