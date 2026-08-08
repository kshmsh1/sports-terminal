import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'historical_nba_repository.dart';
import 'product_local_store.dart';

class NbaTerminalRepository {
  const NbaTerminalRepository({
    ProductLocalStore store = const ProductLocalStore(),
  }) : _store = store;

  final ProductLocalStore _store;

  Future<Map<String, dynamic>> manifest() => _get('/v2/nba/terminal/manifest');

  Future<Map<String, dynamic>> seasons({
    String league = 'NBA',
    String query = '',
    int offset = 0,
    int limit = 100,
  }) =>
      _get(
        '/v2/nba/terminal/seasons',
        query: {
          'league': league,
          if (query.isNotEmpty) 'query': query,
          'offset': '$offset',
          'limit': '$limit',
        },
      );

  Future<Map<String, dynamic>> commands({String query = ''}) => _get(
        '/v2/nba/terminal/commands',
        query: {if (query.isNotEmpty) 'query': query},
      );

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String> query = const {},
  }) async {
    final baseUrl = await _store.loadString(
      ProductLocalStore.backendBaseUrlKey,
      fallback: 'http://127.0.0.1:8000',
    );
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalized.isEmpty) {
      throw const HistoricalNbaException('NBA terminal backend URL is empty.');
    }
    final base = Uri.parse(normalized);
    final relative = path.startsWith('/') ? path : '/$path';
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}$relative',
      queryParameters: query.isEmpty ? null : query,
    );
    final token = await _store.loadString(ProductLocalStore.launchAuthTokenKey);
    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 20));
      Object? decoded;
      if (response.body.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          throw HistoricalNbaException(
            'NBA terminal API returned non-JSON content (${response.statusCode}).',
            statusCode: response.statusCode,
          );
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map && decoded['detail'] != null
            ? decoded['detail'].toString()
            : 'NBA terminal request failed (${response.statusCode}).';
        throw HistoricalNbaException(detail, statusCode: response.statusCode);
      }
      if (decoded is! Map) {
        throw const HistoricalNbaException('NBA terminal API returned an unexpected response shape.');
      }
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } on TimeoutException {
      throw const HistoricalNbaException(
        'NBA terminal request timed out. Confirm the launch backend is running.',
      );
    } on HistoricalNbaException {
      rethrow;
    } catch (error) {
      throw HistoricalNbaException('NBA terminal API unavailable: $error');
    }
  }
}
