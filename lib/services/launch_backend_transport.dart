import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'product_local_store.dart';

class LaunchBackendResponse {
  const LaunchBackendResponse({
    required this.available,
    this.data,
    this.statusCode = 0,
    this.error = '',
    this.requestCompleted = false,
  });

  final bool available;
  final Object? data;
  final int statusCode;
  final String error;
  final bool requestCompleted;

  bool get succeeded => statusCode >= 200 && statusCode < 300;
  bool get rejected => requestCompleted && !succeeded;
}

class LaunchBackendTransport {
  const LaunchBackendTransport({
    ProductLocalStore store = const ProductLocalStore(),
  }) : _store = store;

  final ProductLocalStore _store;

  Future<LaunchBackendResponse> getJson(
    String path, {
    Map<String, String> query = const {},
    Duration? timeout,
  }) {
    return _request('GET', path, query: query, timeout: timeout);
  }

  Future<LaunchBackendResponse> putJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String> query = const {},
    Duration? timeout,
  }) {
    return _request(
      'PUT',
      path,
      query: query,
      body: body,
      timeout: timeout,
    );
  }

  Future<LaunchBackendResponse> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String> query = const {},
    Duration? timeout,
  }) {
    return _request(
      'POST',
      path,
      query: query,
      body: body,
      timeout: timeout,
    );
  }

  Future<LaunchBackendResponse> deleteJson(
    String path, {
    Map<String, String> query = const {},
    Duration? timeout,
  }) {
    return _request('DELETE', path, query: query, timeout: timeout);
  }

  Future<LaunchBackendResponse> _request(
    String method,
    String path, {
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final enabled = await _store.loadBool(
      ProductLocalStore.launchRemoteSyncEnabledKey,
      fallback: true,
    );
    if (!enabled) {
      return const LaunchBackendResponse(
        available: false,
        error: 'Remote-first collaboration is disabled.',
      );
    }

    final configuredBase = await _store.loadString(
      ProductLocalStore.backendBaseUrlKey,
      fallback: 'http://127.0.0.1:8000',
    );
    final normalizedBase =
        configuredBase.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalizedBase.isEmpty) {
      return const LaunchBackendResponse(
        available: false,
        error: 'Backend base URL is empty.',
      );
    }

    try {
      final base = Uri.parse(normalizedBase);
      final relative = path.startsWith('/') ? path : '/$path';
      final uri = base.replace(
        path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}$relative',
        queryParameters: query.isEmpty ? null : query,
      );
      final token = await _store.loadString(
        ProductLocalStore.launchAuthTokenKey,
      );
      final headers = <String, String>{
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final encoded = body == null ? null : jsonEncode(body);
      final requestTimeout = timeout ??
          (body == null
              ? const Duration(milliseconds: 900)
              : const Duration(seconds: 2));
      late final http.Response response;
      switch (method) {
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: encoded)
              .timeout(requestTimeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: encoded)
              .timeout(requestTimeout);
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers)
              .timeout(requestTimeout);
          break;
        default:
          response = await http.get(uri, headers: headers).timeout(requestTimeout);
      }
      final decoded = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return LaunchBackendResponse(
          available: true,
          data: decoded,
          statusCode: response.statusCode,
          error: _errorMessage(decoded, response.body),
          requestCompleted: true,
        );
      }
      return LaunchBackendResponse(
        available: true,
        data: decoded,
        statusCode: response.statusCode,
        requestCompleted: true,
      );
    } on TimeoutException {
      return const LaunchBackendResponse(
        available: false,
        error: 'The backend request timed out.',
      );
    } catch (error) {
      return LaunchBackendResponse(
        available: false,
        error: 'Backend request failed: $error',
      );
    }
  }

  Object? _decodeResponse(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String _errorMessage(Object? decoded, String body) {
    if (decoded is Map) {
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is Map) {
        final message = detail['message'];
        final errors = detail['errors'];
        if (message != null && errors is List && errors.isNotEmpty) {
          return '$message ${errors.join(' ')}';
        }
        if (message != null) return message.toString();
        return jsonEncode(detail);
      }
      if (detail is List) return detail.join(' ');
      final message = decoded['message'];
      if (message != null) return message.toString();
    }
    if (decoded is String && decoded.isNotEmpty) return decoded;
    return body.trim().isEmpty ? 'The backend rejected the request.' : body;
  }
}
