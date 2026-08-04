import '../models/app_session.dart';
import 'launch_backend_transport.dart';

class AnalyticsLibraryService {
  const AnalyticsLibraryService({
    LaunchBackendTransport transport = const LaunchBackendTransport(),
  }) : _transport = transport;

  final LaunchBackendTransport _transport;

  bool _organization(AppSession session) =>
      session.role.canManageOrganization && session.organizationId.isNotEmpty;

  Map<String, String> _scopeQuery(AppSession session) => {
        'owner_user_id': session.userId,
        'scope': _organization(session) ? 'organization' : 'personal',
        if (_organization(session)) 'organization_id': session.organizationId,
      };

  Map<String, dynamic> _scopeBody(AppSession session) => {
        'actor_user_id': session.userId,
        'owner_user_id': session.userId,
        'scope': _organization(session) ? 'organization' : 'personal',
        'organization_id': _organization(session) ? session.organizationId : '',
      };

  Future<Map<String, dynamic>> summary(AppSession session) async {
    final response = await _transport.getJson(
      '/v2/analytics-library/summary',
      query: _scopeQuery(session),
    );
    return _map(response.data);
  }

  Future<List<Map<String, dynamic>>> assets(
    AppSession session, {
    String assetType = '',
    String query = '',
  }) async {
    final response = await _transport.getJson(
      '/v2/analytics-library/assets',
      query: {
        ..._scopeQuery(session),
        if (assetType.isNotEmpty) 'asset_type': assetType,
        if (query.isNotEmpty) 'query': query,
      },
    );
    return _list(response.data);
  }

  Future<Map<String, dynamic>?> saveAsset({
    required AppSession session,
    required String id,
    required String assetType,
    required String title,
    String description = '',
    String visibility = 'private',
    Map<String, dynamic> configuration = const {},
    Map<String, dynamic> sourceSnapshot = const {},
    List<String> tags = const [],
    bool pinned = false,
    int? expectedVersion,
  }) async {
    final response = await _transport.putJson(
      '/v2/analytics-library/assets/$id',
      {
        ..._scopeBody(session),
        'asset_type': assetType,
        'title': title,
        'description': description,
        'visibility': visibility,
        'configuration': configuration,
        'source_snapshot': sourceSnapshot,
        'tags': tags,
        'pinned': pinned,
        if (expectedVersion != null) 'expected_version': expectedVersion,
      },
    );
    return response.succeeded ? _map(response.data) : null;
  }

  Future<bool> deleteAsset(AppSession session, String id) async {
    final response = await _transport.deleteJson(
      '/v2/analytics-library/assets/$id',
      query: {'actor_user_id': session.userId},
    );
    return response.succeeded;
  }

  Future<Map<String, dynamic>?> cloneAsset({
    required AppSession session,
    required String id,
    String title = '',
  }) async {
    final response = await _transport.postJson(
      '/v2/analytics-library/assets/$id/clone',
      {
        ..._scopeBody(session),
        'title': title,
      },
    );
    return response.succeeded ? _map(response.data) : null;
  }

  Future<List<Map<String, dynamic>>> versions(String id) async {
    final response = await _transport.getJson(
      '/v2/analytics-library/assets/$id/versions',
    );
    return _list(response.data);
  }

  Future<List<Map<String, dynamic>>> recent(AppSession session) async {
    final response = await _transport.getJson(
      '/v2/analytics-library/recent',
      query: _scopeQuery(session),
    );
    return _list(response.data);
  }

  Future<bool> recordRecent({
    required AppSession session,
    required String route,
    required String label,
    String assetId = '',
    Map<String, dynamic> context = const {},
  }) async {
    final response = await _transport.postJson(
      '/v2/analytics-library/recent',
      {
        ..._scopeBody(session),
        'asset_id': assetId,
        'route': route,
        'label': label,
        'context': context,
      },
    );
    return response.succeeded;
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) _map(item),
    ];
  }
}
