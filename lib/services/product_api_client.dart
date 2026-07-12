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

  Future<List<dynamic>> listCommunityPosts({String? board}) {
    final query = board == null || board.isEmpty ? '' : '?board=${Uri.encodeQueryComponent(board)}';
    return _getList('/community/posts$query');
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

  Future<Map<String, dynamic>> reportContent({required String reporterUserId, required String targetType, required String targetId, required String reason}) {
    return _postMap('/moderation/reports', {'reporter_user_id': reporterUserId, 'target_type': targetType, 'target_id': targetId, 'reason': reason});
  }

  Future<List<dynamic>> listPlans() => _getList('/billing/plans');

  Future<Map<String, dynamic>> featureFlags() => _getMap('/admin/feature-flags');

  Future<Uri> _uri(String path) async => baseUri.resolve(path);

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
