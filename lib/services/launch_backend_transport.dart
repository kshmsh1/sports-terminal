import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'product_local_store.dart';

class LaunchBackendResponse {
  const LaunchBackendResponse({required this.available, this.data});

  final bool available;
  final Object? data;
}

class LaunchBackendTransport {
  const LaunchBackendTransport({
    ProductLocalStore store = const ProductLocalStore(),
  }) : _store = store;

  final ProductLocalStore _store;

  Future<LaunchBackendResponse> getJson(
    String path, {
    Map<String, String> query = const {},
  }) {
    return _request('GET', path, query: query);
  }

  Future<LaunchBackendResponse> putJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String> query = const {},
  }) {
    return _request('PUT', path, query: query, body: body);
  }

  Future<LaunchBackendResponse> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String> query = const {},
  }) {
    return _request('POST', path, query: query, body: body);
  }

  Future<LaunchBackendResponse> deleteJson(
    String path, {
    Map<String, String> query = const {},
  }) {
    return _request('DELETE', path, query: query);
  }

  Future<LaunchBackendResponse> _request(
    String method,
    String path, {
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
  }) async {
    final enabled = await _store.loadBool(
      ProductLocalStore.launchRemoteSyncEnabledKey,
      fallback: true,
    );
    if (!enabled) return const LaunchBackendResponse(available: false);

    final configuredBase = await _store.loadString(
      ProductLocalStore.backendBaseUrlKey,
      fallback: 'http://127.0.0.1:8000',
    );
    final normalizedBase = configuredBase.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalizedBase.isEmpty) {
      return const LaunchBackendResponse(available: false);
    }

    try {
      final base = Uri.parse(normalizedBase);
      final relative = path.startsWith('/') ? path : '/$path';
      final uri = base.replace(
        path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}$relative',
        queryParameters: query.isEmpty ? null : query,
      );
      final headers = <String, String>{
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
      };
      final encoded = body == null ? null : jsonEncode(body);
      final timeout = body == null
          ? const Duration(milliseconds: 900)
          : const Duration(seconds: 2);
      late final http.Response response;
      switch (method) {
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: encoded)
              .timeout(timeout);
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: encoded)
              .timeout(timeout);
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(timeout);
        default:
          response = await http.get(uri, headers: headers).timeout(timeout);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const LaunchBackendResponse(available: false);
      }
      if (response.body.trim().isEmpty) {
        return const LaunchBackendResponse(available: true);
      }
      return LaunchBackendResponse(
        available: true,
        data: jsonDecode(response.body),
      );
    } on TimeoutException {
      return const LaunchBackendResponse(available: false);
    } catch (_) {
      return const LaunchBackendResponse(available: false);
    }
  }
}
