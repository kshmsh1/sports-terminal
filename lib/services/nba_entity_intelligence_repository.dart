import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'historical_nba_repository.dart';
import 'product_local_store.dart';

class NbaEntityIntelligenceRepository {
  const NbaEntityIntelligenceRepository({
    ProductLocalStore store = const ProductLocalStore(),
  }) : _store = store;

  final ProductLocalStore _store;

  Future<Map<String, dynamic>> search(
    String query, {
    String league = '',
    Set<String> kinds = const {'player', 'team', 'franchise', 'season', 'game'},
    int limitPerKind = 20,
  }) =>
      _get(
        '/v2/nba/history/entities/search',
        query: {
          'query': query,
          if (league.isNotEmpty && league != 'ALL') 'league': league,
          'kinds': kinds.join(','),
          'limit_per_kind': '$limitPerKind',
        },
      );

  Future<Map<String, dynamic>> playerDossier(
    String playerKey, {
    String league = '',
    String seasonType = 'combined',
    int recentGames = 25,
  }) =>
      _get(
        '/v2/nba/history/players/${Uri.encodeComponent(playerKey)}/dossier',
        query: {
          if (league.isNotEmpty && league != 'ALL') 'league': league,
          'season_type': seasonType,
          'recent_games': '$recentGames',
        },
      );

  Future<Map<String, dynamic>> teamDossier(
    String teamKey, {
    String league = '',
    String seasonType = 'regular',
    int recentGames = 25,
  }) =>
      _get(
        '/v2/nba/history/teams/${Uri.encodeComponent(teamKey)}/dossier',
        query: {
          if (league.isNotEmpty && league != 'ALL') 'league': league,
          'season_type': seasonType,
          'recent_games': '$recentGames',
        },
      );

  Future<Map<String, dynamic>> franchiseDossier(
    String franchiseKey, {
    String league = '',
  }) =>
      _get(
        '/v2/nba/history/franchises/${Uri.encodeComponent(franchiseKey)}/dossier',
        query: {
          if (league.isNotEmpty && league != 'ALL') 'league': league,
        },
      );

  Future<Map<String, dynamic>> seasonCommand(
    String season, {
    String league = 'NBA',
    String seasonType = 'regular',
    int leaderLimit = 10,
  }) =>
      _get(
        '/v2/nba/history/seasons/${Uri.encodeComponent(season)}/command',
        query: {
          'league': league,
          'season_type': seasonType,
          'leader_limit': '$leaderLimit',
        },
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
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 25));
      Object? decoded;
      if (response.body.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          throw HistoricalNbaException(
            'NBA entity API returned non-JSON content (${response.statusCode}).',
            statusCode: response.statusCode,
          );
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map && decoded['detail'] != null
            ? decoded['detail'].toString()
            : 'NBA entity request failed (${response.statusCode}).';
        throw HistoricalNbaException(detail, statusCode: response.statusCode);
      }
      if (decoded is! Map) {
        throw const HistoricalNbaException(
          'NBA entity API returned an unexpected response shape.',
        );
      }
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } on TimeoutException {
      throw const HistoricalNbaException(
        'NBA entity request timed out. Confirm the launch backend is running.',
      );
    } on HistoricalNbaException {
      rethrow;
    } catch (error) {
      throw HistoricalNbaException('NBA entity API unavailable: $error');
    }
  }
}
