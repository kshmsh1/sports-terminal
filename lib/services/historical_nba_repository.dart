import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'product_local_store.dart';

class HistoricalNbaRepository {
  const HistoricalNbaRepository({
    ProductLocalStore store = const ProductLocalStore(),
  }) : _store = store;

  final ProductLocalStore _store;

  Future<Map<String, dynamic>> status() => _get('/v2/nba/history/status');

  Future<List<Map<String, dynamic>>> seasons({
    String league = 'NBA',
    String domain = 'player_season',
  }) async {
    final payload = await _get(
      '/v2/nba/history/seasons',
      query: {'league': league, 'domain': domain},
    );
    return _mapRows(payload['rows']);
  }

  Future<List<Map<String, dynamic>>> coverage({
    String domain = '',
    String league = '',
    String season = '',
  }) async {
    final payload = await _get(
      '/v2/nba/history/coverage',
      query: {
        if (domain.isNotEmpty) 'domain': domain,
        if (league.isNotEmpty) 'league': league,
        if (season.isNotEmpty) 'season': season,
      },
    );
    return _mapRows(payload['rows']);
  }

  Future<Map<String, dynamic>> leaderboard({
    required String season,
    String metric = 'pts',
    String basis = 'per_game',
    String league = 'NBA',
    String seasonType = 'regular',
    String team = '',
    double minGames = 0,
    double minMinutes = 0,
    int offset = 0,
    int limit = 1000,
  }) {
    return _get(
      '/v2/nba/history/leaderboard',
      query: {
        'season': season,
        'metric': metric,
        'basis': basis,
        'league': league,
        'season_type': seasonType,
        if (team.isNotEmpty) 'team': team,
        'min_games': minGames.toString(),
        'min_minutes': minMinutes.toString(),
        'offset': offset.toString(),
        'limit': limit.toString(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> searchPlayers(
    String query, {
    String season = '',
    String league = '',
    String team = '',
    int limit = 100,
  }) async {
    final payload = await _get(
      '/v2/nba/history/players',
      query: {
        if (query.trim().isNotEmpty) 'query': query.trim(),
        if (season.isNotEmpty) 'season': season,
        if (league.isNotEmpty) 'league': league,
        if (team.isNotEmpty) 'team': team,
        'limit': limit.toString(),
      },
    );
    return _mapRows(payload['rows']);
  }

  Future<Map<String, dynamic>> player(String playerKey) =>
      _get('/v2/nba/history/players/${Uri.encodeComponent(playerKey)}');

  Future<Map<String, dynamic>> career(
    String playerKey, {
    String league = '',
    String seasonType = 'regular',
  }) {
    return _get(
      '/v2/nba/history/players/${Uri.encodeComponent(playerKey)}/career',
      query: {
        if (league.isNotEmpty) 'league': league,
        'season_type': seasonType,
      },
    );
  }

  Future<Map<String, dynamic>> eraAdjusted(
    String playerKey, {
    String metric = 'pts',
    String basis = 'per_game',
    String league = 'NBA',
    String seasonType = 'regular',
    double minGames = 10,
  }) {
    return _get(
      '/v2/nba/history/era-adjusted/${Uri.encodeComponent(playerKey)}',
      query: {
        'metric': metric,
        'basis': basis,
        'league': league,
        'season_type': seasonType,
        'min_games': minGames.toString(),
      },
    );
  }

  Future<Map<String, dynamic>> provenance(
    String entityType,
    String entityKey,
  ) =>
      _get(
        '/v2/nba/history/provenance/${Uri.encodeComponent(entityType)}/${Uri.encodeComponent(entityKey)}',
      );

  Future<Map<String, dynamic>> conflicts({
    String entityType = '',
    String entityKey = '',
    int limit = 100,
  }) =>
      _get(
        '/v2/nba/history/conflicts',
        query: {
          if (entityType.isNotEmpty) 'entity_type': entityType,
          if (entityKey.isNotEmpty) 'entity_key': entityKey,
          'limit': limit.toString(),
        },
      );

  Future<Map<String, dynamic>> games({
    String season = '',
    String league = 'NBA',
    String seasonType = 'regular',
    String teamKey = '',
    int limit = 250,
  }) =>
      _get(
        '/v2/nba/history/games',
        query: {
          if (season.isNotEmpty) 'season': season,
          'league': league,
          'season_type': seasonType,
          if (teamKey.isNotEmpty) 'team_key': teamKey,
          'limit': limit.toString(),
        },
      );

  Future<Map<String, dynamic>> playByPlay(
    String gameKey, {
    int offset = 0,
    int limit = 500,
  }) =>
      _get(
        '/v2/nba/history/games/${Uri.encodeComponent(gameKey)}/play-by-play',
        query: {'offset': offset.toString(), 'limit': limit.toString()},
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
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));
      Object? decoded;
      if (response.body.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          throw HistoricalNbaException(
            'Historical API returned non-JSON content (${response.statusCode}).',
            statusCode: response.statusCode,
          );
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map && decoded['detail'] != null
            ? decoded['detail'].toString()
            : 'Historical API request failed (${response.statusCode}).';
        throw HistoricalNbaException(detail, statusCode: response.statusCode);
      }
      if (decoded is! Map) {
        throw const HistoricalNbaException(
          'Historical API returned an unexpected response shape.',
        );
      }
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    } on TimeoutException {
      throw const HistoricalNbaException(
        'Historical API request timed out. Confirm the launch backend is running.',
      );
    } on HistoricalNbaException {
      rethrow;
    } catch (error) {
      throw HistoricalNbaException('Historical API unavailable: $error');
    }
  }

  List<Map<String, dynamic>> _mapRows(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map)
          item.map((key, value) => MapEntry(key.toString(), value)),
    ];
  }
}

class HistoricalNbaException implements Exception {
  const HistoricalNbaException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
