import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'product_local_store.dart';

class NbaAwardsRepository {
  const NbaAwardsRepository({
    ProductLocalStore store = const ProductLocalStore(),
  }) : _store = store;

  final ProductLocalStore _store;

  Future<Map<String, dynamic>> catalog({String league = 'NBA'}) => _get(
        '/v2/nba/awards/catalog',
        query: {'league': league},
      );

  Future<Map<String, dynamic>> history(
    String awardKey, {
    String league = 'NBA',
    String season = '',
    bool winnerOnly = false,
    int offset = 0,
    int limit = 500,
  }) =>
      _get(
        '/v2/nba/awards/history/${Uri.encodeComponent(awardKey)}',
        query: {
          'league': league,
          if (season.isNotEmpty) 'season': season,
          'winner_only': winnerOnly.toString(),
          'offset': offset.toString(),
          'limit': limit.toString(),
        },
      );

  Future<Map<String, dynamic>> season(
    String seasonId, {
    String league = 'NBA',
  }) =>
      _get(
        '/v2/nba/awards/season/${Uri.encodeComponent(seasonId)}',
        query: {'league': league},
      );

  Future<Map<String, dynamic>> player(
    String playerKey, {
    String league = '',
  }) =>
      _get(
        '/v2/nba/awards/player/${Uri.encodeComponent(playerKey)}',
        query: {if (league.isNotEmpty) 'league': league},
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
      throw const NbaAwardsException('NBA awards backend URL is empty.');
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
          .timeout(const Duration(seconds: 12));
      Object? decoded;
      if (response.body.trim().isNotEmpty) {
        decoded = jsonDecode(response.body);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map && decoded['detail'] != null
            ? decoded['detail'].toString()
            : 'NBA awards request failed (${response.statusCode}).';
        throw NbaAwardsException(detail, statusCode: response.statusCode);
      }
      if (decoded is! Map) {
        throw const NbaAwardsException(
          'NBA awards API returned an unexpected response shape.',
        );
      }
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    } on TimeoutException {
      throw const NbaAwardsException('NBA awards request timed out.');
    } on NbaAwardsException {
      rethrow;
    } catch (error) {
      throw NbaAwardsException('NBA awards API unavailable: $error');
    }
  }
}

class NbaAwardsException implements Exception {
  const NbaAwardsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
