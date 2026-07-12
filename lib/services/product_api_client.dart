import 'dart:convert';

import 'package:http/http.dart' as http;

class ProductApiClient {
  ProductApiClient({String baseUrl = 'http://127.0.0.1:8000', http.Client? httpClient})
      : baseUri = Uri.parse(baseUrl),
        client = httpClient ?? http.Client();

  final Uri baseUri;
  final http.Client client;

  Future<Map<String, dynamic>> health() => _getMap('/health');

  Future<Map<String, dynamic>> readiness() => _getMap('/launch/readiness');

  Future<Map<String, dynamic>> createUser({required String email, required String displayName, String role = 'user'}) {
    return _postMap('/users', {'email': email, 'display_name': displayName, 'role': role});
  }

  Future<List<dynamic>> listUsers() => _getList('/users');

  Future<Map<String, dynamic>> getUser(String userId) => _getMap('/users/$userId');

  Future<Map<String, dynamic>> getProfile(String userId) => _getMap('/users/$userId/profile');

  Future<Map<String, dynamic>> updateProfile(
    String userId, {
    String? handle,
    String? bio,
    String? avatarUrl,
    bool isPublic = true,
  }) {
    return _putMap('/users/$userId/profile', {
      'handle': handle,
      'bio': bio,
      'avatar_url': avatarUrl,
      'is_public': isPublic,
    });
  }

  Future<Map<String, dynamic>> getSettings(String userId) => _getMap('/users/$userId/settings');

  Future<Map<String, dynamic>> updateSettings(
    String userId, {
    required bool darkMode,
    required bool emailDigest,
    required bool fantasyAlerts,
    Map<String, dynamic> notificationPreferences = const {},
  }) {
    return _putMap('/users/$userId/settings', {
      'dark_mode': darkMode,
      'email_digest': emailDigest,
      'fantasy_alerts': fantasyAlerts,
      'notification_preferences': notificationPreferences,
    });
  }

  Future<Map<String, dynamic>> getPersonalization(String userId) => _getMap('/users/$userId/personalization');

  Future<Map<String, dynamic>> addFavoriteTeam(String userId, String teamId) => _postMap('/users/$userId/favorite-teams', {'item_id': teamId});

  Future<Map<String, dynamic>> removeFavoriteTeam(String userId, String teamId) => _deleteMap('/users/$userId/favorite-teams/$teamId');

  Future<Map<String, dynamic>> addFavoritePlayer(String userId, String playerId) => _postMap('/users/$userId/favorite-players', {'item_id': playerId});

  Future<Map<String, dynamic>> removeFavoritePlayer(String userId, String playerId) => _deleteMap('/users/$userId/favorite-players/$playerId');

  Future<Map<String, dynamic>> addWatchlistPlayer(String userId, String playerId, {String source = 'manual', String? notes}) {
    return _postMap('/users/$userId/watchlist', {'player_id': playerId, 'source': source, 'notes': notes});
  }

  Future<Map<String, dynamic>> removeWatchlistPlayer(String userId, String playerId) => _deleteMap('/users/$userId/watchlist/$playerId');

  Future<Map<String, dynamic>> createWorkbook({required String ownerUserId, required String title, String visibility = 'private'}) {
    return _postMap('/workbooks', {'owner_user_id': ownerUserId, 'title': title, 'visibility': visibility});
  }

  Future<Map<String, dynamic>> getWorkbook(String workbookId) => _getMap('/workbooks/$workbookId');

  Future<Map<String, dynamic>> updateWorkbookCell(String workbookId, {required String sheet, required String cellRef, required String rawValue}) {
    return _putMap('/workbooks/$workbookId/cells', {'sheet': sheet, 'cell_ref': cellRef, 'raw_value': rawValue});
  }

  Future<List<dynamic>> listCommunityPosts({String? board, String? entityType, String? entityId}) {
    final params = <String, String>{};
    if (board != null && board.isNotEmpty) params['board'] = board;
    if (entityType != null && entityType.isNotEmpty) params['entity_type'] = entityType;
    if (entityId != null && entityId.isNotEmpty) params['entity_id'] = entityId;
    return _getList(_pathWithQuery('/community/posts', params));
  }

  Future<Map<String, dynamic>> createCommunityPost({required String authorUserId, required String board, required String title, required String body, String? entityType, String? entityId}) {
    return _postMap('/community/posts', {
      'author_user_id': authorUserId,
      'board': board,
      'title': title,
      'body': body,
      'entity_type': entityType,
      'entity_id': entityId,
    });
  }

  Future<Map<String, dynamic>> reactToPost({required String postId, required String userId, String kind = 'like'}) {
    return _postMap('/community/posts/$postId/reactions', {'user_id': userId, 'kind': kind});
  }

  Future<Map<String, dynamic>> removePostReaction({required String postId, required String userId, String kind = 'like'}) {
    return _deleteMap('/community/posts/$postId/reactions/$userId?kind=${Uri.encodeQueryComponent(kind)}');
  }

  Future<Map<String, dynamic>> reportContent({required String reporterUserId, required String targetType, required String targetId, required String reason}) {
    return _postMap('/moderation/reports', {'reporter_user_id': reporterUserId, 'target_type': targetType, 'target_id': targetId, 'reason': reason});
  }

  Future<List<dynamic>> listReports({String? status}) {
    return _getList(_pathWithQuery('/moderation/reports', {if (status != null && status.isNotEmpty) 'status': status}));
  }

  Future<Map<String, dynamic>> createConversation({required String title, required List<String> memberUserIds}) {
    return _postMap('/messages/conversations', {'title': title, 'member_user_ids': memberUserIds});
  }

  Future<List<dynamic>> listUserConversations(String userId) => _getList('/users/$userId/conversations');

  Future<Map<String, dynamic>> sendMessage({required String conversationId, required String senderUserId, required String body}) {
    return _postMap('/messages/conversations/$conversationId/messages', {'sender_user_id': senderUserId, 'body': body});
  }

  Future<List<dynamic>> listMessages(String conversationId) => _getList('/messages/conversations/$conversationId/messages');

  Future<Map<String, dynamic>> createArticle({required String authorUserId, required String title, required String body, String status = 'draft', List<String> tags = const []}) {
    return _postMap('/cms/articles', {'author_user_id': authorUserId, 'title': title, 'body': body, 'status': status, 'tags': tags});
  }

  Future<List<dynamic>> listArticles({String? status}) {
    return _getList(_pathWithQuery('/cms/articles', {if (status != null && status.isNotEmpty) 'status': status}));
  }

  Future<Map<String, dynamic>> updateArticleStatus(String articleId, String status) {
    return _putMap('/cms/articles/$articleId/status', {'status': status});
  }

  Future<List<dynamic>> listPlans() => _getList('/billing/plans');

  Future<Map<String, dynamic>> upsertSubscription({required String subscriptionId, required String userId, required String planId, String status = 'trialing'}) {
    return _putMap('/billing/subscriptions/$subscriptionId', {'user_id': userId, 'plan_id': planId, 'status': status});
  }

  Future<Map<String, dynamic>> featureFlags() => _getMap('/admin/feature-flags');

  Future<Map<String, dynamic>> updateFeatureFlag(String flag, bool enabled) => _putMap('/admin/feature-flags/$flag', {'enabled': enabled});

  Future<List<dynamic>> listDataSources() => _getList('/admin/data-sources');

  Future<Map<String, dynamic>> upsertDataSource({required String sourceId, required String sourceType, required String label, Map<String, dynamic> config = const {}, bool enabled = false}) {
    return _putMap('/admin/data-sources/$sourceId', {'source_type': sourceType, 'label': label, 'config': config, 'enabled': enabled});
  }

  Future<List<dynamic>> listPipelineRuns() => _getList('/admin/data/pipeline-runs');

  Future<Map<String, dynamic>> recordPipelineRun(Map<String, dynamic> payload) => _postMap('/admin/data/pipeline-runs', payload);

  Future<Uri> _uri(String path) async => baseUri.resolve(path);

  String _pathWithQuery(String path, Map<String, String> params) {
    if (params.isEmpty) return path;
    final query = params.entries.map((entry) => '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}').join('&');
    return '$path?$query';
  }

  Future<Map<String, dynamic>> _getMap(String path) async => _decodeMap(await client.get(await _uri(path)));

  Future<List<dynamic>> _getList(String path) async => _decodeList(await client.get(await _uri(path)));

  Future<Map<String, dynamic>> _postMap(String path, Map<String, dynamic> body) async {
    return _decodeMap(await client.post(await _uri(path), headers: _headers, body: jsonEncode(body)));
  }

  Future<Map<String, dynamic>> _putMap(String path, Map<String, dynamic> body) async {
    return _decodeMap(await client.put(await _uri(path), headers: _headers, body: jsonEncode(body)));
  }

  Future<Map<String, dynamic>> _deleteMap(String path) async => _decodeMap(await client.delete(await _uri(path)));

  Map<String, String> get _headers => const {'content-type': 'application/json'};

  Map<String, dynamic> _decodeMap(http.Response response) {
    _throwIfBad(response);
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw ProductApiException('Expected object response but received ${decoded.runtimeType}', response.statusCode);
  }

  List<dynamic> _decodeList(http.Response response) {
    _throwIfBad(response);
    final decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) return decoded;
    throw ProductApiException('Expected list response but received ${decoded.runtimeType}', response.statusCode);
  }

  void _throwIfBad(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ProductApiException(response.body, response.statusCode);
  }
}

class ProductApiException implements Exception {
  const ProductApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => 'ProductApiException($statusCode): $message';
}
