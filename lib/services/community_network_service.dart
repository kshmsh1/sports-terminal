import '../models/app_session.dart';
import 'launch_backend_transport.dart';

class CommunityNetworkService {
  const CommunityNetworkService({
    LaunchBackendTransport transport = const LaunchBackendTransport(),
  }) : _transport = transport;

  final LaunchBackendTransport _transport;

  Future<List<Map<String, dynamic>>> boards(AppSession session) async {
    final response = await _transport.getJson(
      '/v2/community/boards',
      query: {'viewer_user_id': session.userId},
    );
    return response.available ? _list(response.data) : const [];
  }

  Future<List<Map<String, dynamic>>> feed(
    AppSession session, {
    String communitySlug = '',
    String sort = 'hot',
    bool followedOnly = false,
    bool savedOnly = false,
    int limit = 150,
  }) async {
    final response = await _transport.getJson(
      '/v2/community/feed',
      query: {
        'viewer_user_id': session.userId,
        if (communitySlug.isNotEmpty) 'community_slug': communitySlug,
        'sort': sort,
        'followed_only': followedOnly.toString(),
        'saved_only': savedOnly.toString(),
        'limit': limit.toString(),
      },
    );
    if (!response.available || response.data is! Map) return const [];
    final payload = _map(response.data as Map);
    return _list(payload['rows']);
  }

  Future<Map<String, dynamic>?> createThread({
    required AppSession session,
    required String communitySlug,
    required String title,
    required String body,
    String flair = 'Discussion',
    String entityType = '',
    String entityId = '',
  }) async {
    final response = await _transport.postJson(
      '/v2/community/posts',
      {
        'actor_user_id': session.userId,
        'community_slug': communitySlug,
        'title': title,
        'body': body,
        'flair': flair,
        'entity_type': entityType,
        'entity_id': entityId,
      },
    );
    return response.available && response.data is Map
        ? _map(response.data as Map)
        : null;
  }

  Future<Map<String, dynamic>?> vote({
    required AppSession session,
    required String postId,
    required int direction,
  }) async {
    final response = await _transport.putJson(
      '/v2/community/posts/$postId/vote',
      {'actor_user_id': session.userId, 'direction': direction},
    );
    return response.available && response.data is Map
        ? _map(response.data as Map)
        : null;
  }

  Future<bool> save({
    required AppSession session,
    required String postId,
    required bool saved,
  }) async {
    final response = await _transport.putJson(
      '/v2/community/posts/$postId/save',
      {'actor_user_id': session.userId, 'saved': saved},
    );
    return response.available;
  }

  Future<bool> follow({
    required AppSession session,
    required String communitySlug,
    required bool followed,
  }) async {
    final response = await _transport.putJson(
      '/v2/community/boards/$communitySlug/follow',
      {'actor_user_id': session.userId, 'followed': followed},
    );
    return response.available;
  }

  Future<List<Map<String, dynamic>>> comments({
    required AppSession session,
    required String postId,
  }) async {
    final response = await _transport.getJson(
      '/v2/community/posts/$postId/comments',
      query: {'viewer_user_id': session.userId},
    );
    return response.available ? _list(response.data) : const [];
  }

  Future<Map<String, dynamic>?> reply({
    required AppSession session,
    required String postId,
    required String body,
    String parentCommentId = '',
  }) async {
    final response = await _transport.postJson(
      '/v2/community/posts/$postId/comments',
      {
        'actor_user_id': session.userId,
        'body': body,
        'parent_comment_id': parentCommentId,
      },
    );
    return response.available && response.data is Map
        ? _map(response.data as Map)
        : null;
  }

  Future<Map<String, dynamic>?> userProfile(String userId) async {
    final response = await _transport.getJson('/v2/community/users/$userId');
    return response.available && response.data is Map
        ? _map(response.data as Map)
        : null;
  }

  static List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) _map(item),
    ];
  }

  static Map<String, dynamic> _map(Map value) => value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
}
