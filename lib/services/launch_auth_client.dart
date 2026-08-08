import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_session.dart';
import 'product_local_store.dart';

class LaunchAuthResult {
  const LaunchAuthResult({required this.available, this.session, this.error = ''});
  final bool available;
  final AppSession? session;
  final String error;
  bool get succeeded => available && session != null;
}

class LaunchAuthClient {
  const LaunchAuthClient({ProductLocalStore store = const ProductLocalStore()}) : _store = store;
  static const legalVersion = '2026-08-08-v1';
  final ProductLocalStore _store;

  Future<LaunchAuthResult> restore() async {
    final token = await _store.loadString(ProductLocalStore.launchAuthTokenKey);
    if (token.isEmpty) return const LaunchAuthResult(available: false);
    final response = await _request('GET', '/v2/auth/session', token: token);
    if (!response.available) {
      final cached = await _loadCachedSession();
      return LaunchAuthResult(available: false, session: cached);
    }
    if (response.data is! Map) {
      await clearLocalSession();
      return LaunchAuthResult(available: true, error: response.error.isEmpty ? 'Saved session is no longer valid.' : response.error);
    }
    return _acceptSession((response.data! as Map).map((key, value) => MapEntry(key.toString(), value)));
  }

  Future<LaunchAuthResult> signIn({required String email, required String password}) async {
    final response = await _request('POST', '/v2/auth/login', body: {'email': email.trim(), 'password': password});
    if (!response.available) return const LaunchAuthResult(available: false);
    if (response.data is! Map) return LaunchAuthResult(available: true, error: response.error.isEmpty ? 'Sign-in failed.' : response.error);
    return _acceptSession((response.data! as Map).map((key, value) => MapEntry(key.toString(), value)));
  }

  Future<LaunchAuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
    required bool organizationAccount,
    required bool acceptedTerms,
    required bool acceptedPrivacy,
    String organizationName = '',
  }) async {
    if (!acceptedTerms || !acceptedPrivacy) {
      return const LaunchAuthResult(
        available: true,
        error: 'You must agree to the Terms & Conditions and Privacy Policy before creating an account.',
      );
    }
    final acceptedAt = DateTime.now().toUtc().toIso8601String();
    final response = await _request(
      'POST',
      '/v2/auth/signup',
      body: {
        'email': email.trim(),
        'password': password,
        'display_name': displayName.trim(),
        'account_type': organizationAccount ? 'organization' : 'individual',
        if (organizationAccount) 'organization_name': organizationName.trim(),
        'accepted_terms': true,
        'accepted_privacy': true,
        'terms_version': legalVersion,
        'privacy_version': legalVersion,
        'legal_accepted_at': acceptedAt,
      },
    );
    if (!response.available) return const LaunchAuthResult(available: false);
    if (response.data is! Map) return LaunchAuthResult(available: true, error: response.error.isEmpty ? 'Account creation failed.' : response.error);
    return _acceptSession((response.data! as Map).map((key, value) => MapEntry(key.toString(), value)));
  }

  Future<void> signOut() async {
    final token = await _store.loadString(ProductLocalStore.launchAuthTokenKey);
    if (token.isNotEmpty) await _request('POST', '/v2/auth/logout', token: token, body: const {});
    await clearLocalSession();
  }

  Future<void> clearLocalSession() async {
    await Future.wait([
      _store.remove(ProductLocalStore.launchAuthTokenKey),
      _store.remove(ProductLocalStore.launchAuthSessionKey),
      _store.remove(ProductLocalStore.launchAuthExpiresAtKey),
    ]);
  }

  Future<LaunchAuthResult> _acceptSession(Map<String, dynamic> payload) async {
    final token = payload['token']?.toString() ?? '';
    final session = _sessionFromPayload(payload);
    if (token.isEmpty || session == null) return const LaunchAuthResult(available: true, error: 'The authentication server returned an incomplete session.');
    await Future.wait([
      _store.saveString(ProductLocalStore.launchAuthTokenKey, token),
      _store.saveString(ProductLocalStore.launchAuthSessionKey, jsonEncode(_sessionToJson(session))),
      _store.saveString(ProductLocalStore.launchAuthExpiresAtKey, payload['expires_at']?.toString() ?? ''),
      _store.saveString(ProductLocalStore.backendUserIdKey, session.userId),
    ]);
    return LaunchAuthResult(available: true, session: session);
  }

  AppSession? _sessionFromPayload(Map<String, dynamic> payload) {
    final rawUser = payload['user'];
    if (rawUser is! Map) return null;
    final user = rawUser.map((key, value) => MapEntry(key.toString(), value));
    final userId = user['id']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';
    if (userId.isEmpty || email.isEmpty) return null;
    final organizations = payload['organizations'];
    Map<String, dynamic>? selectedOrganization;
    if (organizations is List) {
      for (final item in organizations) {
        if (item is Map && item['membership_status'] != 'inactive') {
          selectedOrganization = item.map((key, value) => MapEntry(key.toString(), value));
          break;
        }
      }
    }
    final role = _role(user['role']?.toString() ?? 'analyst', selectedOrganization?['membership_role']?.toString() ?? '');
    return AppSession(
      userId: userId,
      email: email,
      displayName: user['display_name']?.toString() ?? email,
      organizationId: selectedOrganization?['id']?.toString() ?? '',
      organizationName: selectedOrganization?['name']?.toString() ?? 'Personal account',
      role: role,
    );
  }

  UserRole _role(String backendRole, String membershipRole) {
    if (backendRole == 'platform_admin') return UserRole.platformAdmin;
    if (backendRole == 'organization_admin' || {'owner', 'admin'}.contains(membershipRole)) return UserRole.organizationAdmin;
    return UserRole.analyst;
  }

  Future<AppSession?> _loadCachedSession() async {
    final raw = await _store.loadString(ProductLocalStore.launchAuthSessionKey);
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final json = decoded.map((key, value) => MapEntry(key.toString(), value));
      return AppSession(
        userId: json['userId']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? '',
        organizationId: json['organizationId']?.toString() ?? '',
        organizationName: json['organizationName']?.toString() ?? '',
        role: UserRole.values.firstWhere((value) => value.name == json['role'], orElse: () => UserRole.analyst),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _sessionToJson(AppSession session) => {
    'userId': session.userId,
    'email': session.email,
    'displayName': session.displayName,
    'organizationId': session.organizationId,
    'organizationName': session.organizationName,
    'role': session.role.name,
  };

  Future<_AuthHttpResponse> _request(String method, String path, {Map<String, dynamic>? body, String token = ''}) async {
    final baseUrl = await _store.loadString(ProductLocalStore.backendBaseUrlKey, fallback: 'http://127.0.0.1:8000');
    final normalizedBase = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalizedBase.isEmpty) return const _AuthHttpResponse(available: false);
    try {
      final base = Uri.parse(normalizedBase);
      final relative = path.startsWith('/') ? path : '/$path';
      final uri = base.replace(path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}$relative');
      final headers = <String, String>{'Accept': 'application/json', if (body != null) 'Content-Type': 'application/json', if (token.isNotEmpty) 'Authorization': 'Bearer $token'};
      late final http.Response response;
      if (method == 'GET') {
        response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 2));
      } else {
        response = await http.post(uri, headers: headers, body: jsonEncode(body ?? const {})).timeout(const Duration(seconds: 3));
      }
      Object? data;
      if (response.body.trim().isNotEmpty) {
        try { data = jsonDecode(response.body); } catch (_) { data = null; }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) return _AuthHttpResponse(available: true, data: data);
      var error = 'Authentication request failed.';
      if (data is Map && data['detail'] != null) error = data['detail'].toString();
      return _AuthHttpResponse(available: true, error: error);
    } on TimeoutException {
      return const _AuthHttpResponse(available: false);
    } catch (_) {
      return const _AuthHttpResponse(available: false);
    }
  }
}

class _AuthHttpResponse {
  const _AuthHttpResponse({required this.available, this.data, this.error = ''});
  final bool available;
  final Object? data;
  final String error;
}
