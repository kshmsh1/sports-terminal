import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'historical_nba_repository.dart';
import 'product_local_store.dart';

class HistoricalNbaResearchRepository {
  const HistoricalNbaResearchRepository({
    ProductLocalStore store = const ProductLocalStore(),
  }) : _store = store;

  final ProductLocalStore _store;

  Future<Map<String, dynamic>> summary() => _get('/v2/nba/history/research/summary');

  Future<Map<String, dynamic>> playerGames(
    String playerKey, {
    String season = '',
    String seasonType = 'combined',
    int offset = 0,
    int limit = 100,
  }) =>
      _get(
        '/v2/nba/history/players/${Uri.encodeComponent(playerKey)}/games',
        query: {
          if (season.isNotEmpty) 'season': season,
          'season_type': seasonType,
          'offset': offset.toString(),
          'limit': limit.toString(),
        },
      );

  Future<Map<String, dynamic>> allTime({
    String metric = 'pts',
    String basis = 'totals',
    String mode = 'career',
    int bestN = 5,
    String league = 'NBA',
    String seasonType = 'regular',
    String seasonFrom = '',
    String seasonTo = '',
    int minSeasons = 1,
    double minGames = 0,
    int offset = 0,
    int limit = 200,
  }) =>
      _get(
        '/v2/nba/history/all-time',
        query: {
          'metric': metric,
          'basis': basis,
          'mode': mode,
          'best_n': bestN.toString(),
          'league': league,
          'season_type': seasonType,
          if (seasonFrom.isNotEmpty) 'season_from': seasonFrom,
          if (seasonTo.isNotEmpty) 'season_to': seasonTo,
          'min_seasons': minSeasons.toString(),
          'min_games': minGames.toString(),
          'offset': offset.toString(),
          'limit': limit.toString(),
        },
      );

  Future<Map<String, dynamic>> compare({
    required List<String> playerKeys,
    String metric = 'pts',
    String basis = 'per_game',
    String league = 'NBA',
    String seasonType = 'regular',
    double minGames = 10,
  }) =>
      _get(
        '/v2/nba/history/compare',
        query: {
          'player_keys': playerKeys.join(','),
          'metric': metric,
          'basis': basis,
          'league': league,
          'season_type': seasonType,
          'min_games': minGames.toString(),
        },
      );

  Future<Map<String, dynamic>> franchises({
    String query = '',
    String league = '',
    int limit = 200,
  }) =>
      _get(
        '/v2/nba/history/franchises',
        query: {
          if (query.isNotEmpty) 'query': query,
          if (league.isNotEmpty) 'league': league,
          'limit': limit.toString(),
        },
      );

  Future<Map<String, dynamic>> franchise(String franchiseKey) =>
      _get('/v2/nba/history/franchises/${Uri.encodeComponent(franchiseKey)}');

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
      throw const HistoricalNbaException('Historical backend URL is empty.');
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
            'Historical research API returned non-JSON content (${response.statusCode}).',
            statusCode: response.statusCode,
          );
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map && decoded['detail'] != null
            ? decoded['detail'].toString()
            : 'Historical research request failed (${response.statusCode}).';
        throw HistoricalNbaException(detail, statusCode: response.statusCode);
      }
      if (decoded is! Map) {
        throw const HistoricalNbaException(
          'Historical research API returned an unexpected response shape.',
        );
      }
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } on TimeoutException {
      throw const HistoricalNbaException(
        'Historical research request timed out. Confirm the launch backend is running.',
      );
    } on HistoricalNbaException {
      rethrow;
    } catch (error) {
      throw HistoricalNbaException('Historical research API unavailable: $error');
    }
  }
}
