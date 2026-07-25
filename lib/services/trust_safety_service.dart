import 'dart:convert';

import '../models/app_session.dart';
import 'launch_backend_transport.dart';
import 'product_local_store.dart';

class TrustSafetySnapshot {
  const TrustSafetySnapshot({
    required this.posts,
    required this.blocks,
    required this.mutes,
    required this.sanctions,
    required this.remoteAvailable,
  });

  final List<Map<String, dynamic>> posts;
  final List<Map<String, dynamic>> blocks;
  final List<Map<String, dynamic>> mutes;
  final List<Map<String, dynamic>> sanctions;
  final bool remoteAvailable;
}

class TrustSafetyService {
  const TrustSafetyService({
    LaunchBackendTransport transport = const LaunchBackendTransport(),
    ProductLocalStore store = const ProductLocalStore(),
  })  : _transport = transport,
        _store = store;

  final LaunchBackendTransport _transport;
  final ProductLocalStore _store;

  static const _postsKey = 'sports_terminal.trust.posts.v1';
  static const _conversationsKey = 'sports_terminal.trust.conversations.v1';

  Future<TrustSafetySnapshot> loadCommunity({
    required AppSession session,
    String board = '',
  }) async {
    final postsResponse = await _transport.getJson(
      '/v2/trust/community/posts',
      query: {
        'viewer_user_id': session.userId,
        if (board.isNotEmpty && board != 'All') 'board': board,
      },
    );
    var remoteAvailable = false;
    var posts = <Map<String, dynamic>>[];
    if (postsResponse.available && postsResponse.data is List) {
      remoteAvailable = true;
      posts = _list(postsResponse.data);
      await _store.saveString(_postsKey, jsonEncode(posts));
    } else {
      posts = await _cachedList(_postsKey);
      if (board.isNotEmpty && board != 'All') {
        posts = posts.where((item) => item['board'] == board).toList();
      }
    }

    final relationships = await _transport.getJson(
      '/v2/trust/relationships/${session.userId}',
    );
    final data = relationships.data is Map
        ? _map(relationships.data as Map)
        : <String, dynamic>{};
    return TrustSafetySnapshot(
      posts: posts,
      blocks: _list(data['blocks']),
      mutes: _list(data['mutes']),
      sanctions: _list(data['sanctions']),
      remoteAvailable: remoteAvailable || relationships.available,
    );
  }

  Future<Map<String, dynamic>?> createPost({
    required AppSession session,
    required String board,
    required String title,
    required String body,
    String entityType = '',
    String entityId = '',
  }) async {
    final response = await _transport.postJson(
      '/v2/trust/community/posts',
      {
        'actor_user_id': session.userId,
        'board': board,
        'title': title,
        'body': body,
        'entity_type': entityType,
        'entity_id': entityId,
      },
    );
    if (!response.available || response.data is! Map) return null;
    return _map(response.data as Map);
  }

  Future<Map<String, dynamic>?> createComment({
    required AppSession session,
    required String postId,
    required String body,
  }) async {
    final response = await _transport.postJson(
      '/v2/trust/community/posts/$postId/comments',
      {'actor_user_id': session.userId, 'body': body},
    );
    if (!response.available || response.data is! Map) return null;
    return _map(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> comments({
    required AppSession session,
    required String postId,
  }) async {
    final response = await _transport.getJson(
      '/v2/trust/community/posts/$postId/comments',
      query: {'viewer_user_id': session.userId},
    );
    if (!response.available || response.data is! List) return const [];
    return _list(response.data);
  }

  Future<Map<String, dynamic>?> toggleLike({
    required AppSession session,
    required String postId,
  }) async {
    final response = await _transport.putJson(
      '/v2/trust/community/posts/$postId/reaction',
      {'actor_user_id': session.userId, 'kind': 'like'},
    );
    if (!response.available || response.data is! Map) return null;
    return _map(response.data as Map);
  }

  Future<Map<String, dynamic>?> report({
    required AppSession session,
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
    String priority = 'normal',
  }) async {
    final response = await _transport.postJson(
      '/v2/trust/reports',
      {
        'actor_user_id': session.userId,
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        'details': details,
        'priority': priority,
      },
    );
    if (!response.available || response.data is! Map) return null;
    return _map(response.data as Map);
  }

  Future<bool> block({
    required AppSession session,
    required String targetUserId,
    String reason = '',
  }) async {
    final response = await _transport.putJson(
      '/v2/trust/blocks',
      {
        'actor_user_id': session.userId,
        'target_user_id': targetUserId,
        'reason': reason,
      },
    );
    return response.available;
  }

  Future<bool> mute({
    required AppSession session,
    required String targetUserId,
    String reason = '',
  }) async {
    final response = await _transport.putJson(
      '/v2/trust/mutes',
      {
        'actor_user_id': session.userId,
        'target_user_id': targetUserId,
        'reason': reason,
      },
    );
    return response.available;
  }

  Future<List<Map<String, dynamic>>> conversations(AppSession session) async {
    final response = await _transport.getJson(
      '/v2/trust/messages/conversations',
      query: {'user_id': session.userId},
    );
    if (response.available && response.data is List) {
      final rows = _list(response.data);
      await _store.saveString(_conversationsKey, jsonEncode(rows));
      return rows;
    }
    return _cachedList(_conversationsKey);
  }

  Future<Map<String, dynamic>?> createConversation({
    required AppSession session,
    required List<String> memberUserIds,
    String title = 'Direct message',
  }) async {
    final response = await _transport.postJson(
      '/v2/trust/messages/conversations',
      {
        'actor_user_id': session.userId,
        'title': title,
        'member_user_ids': memberUserIds,
      },
    );
    if (!response.available || response.data is! Map) return null;
    return _map(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> messages({
    required AppSession session,
    required String conversationId,
  }) async {
    final response = await _transport.getJson(
      '/v2/trust/messages/conversations/$conversationId',
      query: {'user_id': session.userId},
    );
    if (!response.available || response.data is! List) return const [];
    return _list(response.data);
  }

  Future<Map<String, dynamic>?> sendMessage({
    required AppSession session,
    required String conversationId,
    required String body,
  }) async {
    final response = await _transport.postJson(
      '/v2/trust/messages/conversations/$conversationId',
      {'actor_user_id': session.userId, 'body': body},
    );
    if (!response.available || response.data is! Map) return null;
    return _map(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> moderationQueue({
    String status = 'open',
  }) async {
    final response = await _transport.getJson(
      '/v2/trust/moderation/queue',
      query: {'status': status},
    );
    if (!response.available || response.data is! List) return const [];
    return _list(response.data);
  }

  Future<List<Map<String, dynamic>>> moderationAudit() async {
    final response = await _transport.getJson('/v2/trust/moderation/audit');
    if (!response.available || response.data is! List) return const [];
    return _list(response.data);
  }

  Future<Map<String, dynamic>?> moderate({
    required AppSession session,
    required String caseId,
    required String action,
    required String reason,
    String resolution = '',
    String expiresAt = '',
  }) async {
    final response = await _transport.postJson(
      '/v2/trust/moderation/cases/$caseId/actions',
      {
        'actor_user_id': session.userId,
        'action': action,
        'reason': reason,
        'resolution': resolution,
        'expires_at': expiresAt,
        'payload': const {},
      },
    );
    if (!response.available || response.data is! Map) return null;
    return _map(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> _cachedList(String key) async {
    final encoded = await _store.loadString(key);
    if (encoded.isEmpty) return const [];
    try {
      return _list(jsonDecode(encoded));
    } catch (_) {
      return const [];
    }
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
