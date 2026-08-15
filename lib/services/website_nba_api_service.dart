import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'nba_terminal_seed_repository.dart';
import 'product_local_store.dart';

class WebsiteNbaSeason {
  const WebsiteNbaSeason({
    required this.id,
    required this.label,
    required this.startYear,
    required this.rowCount,
  });

  final String id;
  final String label;
  final int startYear;
  final int rowCount;

  factory WebsiteNbaSeason.fromMap(Map<String, dynamic> map) {
    final id = (map['season_id'] ?? map['id'] ?? '').toString();
    return WebsiteNbaSeason(
      id: id,
      label: (map['label'] ?? id).toString(),
      startYear: _int(map['start_year']) ?? _seasonStart(id),
      rowCount: _int(map['row_count']) ?? 0,
    );
  }
}

/// Website-facing NBA data access.
///
/// The canonical historical warehouse/API is the primary source. Generated
/// Flutter asset seeds remain an offline compatibility mechanism for older
/// product surfaces, not a prerequisite for the website.
class WebsiteNbaApiService {
  const WebsiteNbaApiService({
    ProductLocalStore store = const ProductLocalStore(),
    NbaTerminalSeedRepository seedRepository = const NbaTerminalSeedRepository(),
  })  : _store = store,
        _seedRepository = seedRepository;

  final ProductLocalStore _store;
  final NbaTerminalSeedRepository _seedRepository;

  Future<List<WebsiteNbaSeason>> seasons() async {
    final decoded = await _get(
      '/v2/nba/history/seasons',
      query: const {'league': 'NBA', 'domain': 'player_season'},
    );
    final rows = decoded['rows'];
    if (rows is! List) return const [];
    final result = <WebsiteNbaSeason>[
      for (final value in rows)
        if (value is Map)
          WebsiteNbaSeason.fromMap(
            value.map((key, item) => MapEntry(key.toString(), item)),
          ),
    ];
    result.sort((a, b) => b.startYear.compareTo(a.startYear));
    return result;
  }

  Future<NbaTerminalSeedSnapshot> seasonSnapshot(
    String season, {
    String seasonType = 'regular',
    // Website index/dashboard/stat surfaces only need season-level facts,
    // teams and games to render. Pulling the compatibility endpoint's default
    // 50,000 player-game rows made every primary page wait on a massive JSON
    // response before first paint. Player/team entity pages fetch their own
    // bounded recent-game dossiers separately when detailed logs are needed.
    bool includeGameLogs = false,
  }) {
    return _seedRepository.loadHistoricalSeason(
      season,
      league: 'NBA',
      seasonType: seasonType,
      includeGameLogs: includeGameLogs,
    );
  }

  Future<Map<String, dynamic>> playerDossier(
    String playerKey, {
    String seasonType = 'combined',
    int recentGames = 30,
  }) async {
    if (seasonType != 'combined') {
      return _playerDossierRequest(
        playerKey,
        seasonType: seasonType,
        recentGames: recentGames,
      );
    }

    // The backend's combined research mode intentionally collapses regular
    // season and playoff rows. A conventional player page should preserve the
    // two bodies of work, so the website composes separate sourced requests.
    final regular = await _playerDossierRequest(
      playerKey,
      seasonType: 'regular',
      recentGames: recentGames,
    );
    final playoffs = await _playerDossierRequest(
      playerKey,
      seasonType: 'playoffs',
      recentGames: 0,
    );
    final regularRows = _mapList(regular['seasons']);
    final playoffRows = _mapList(playoffs['seasons']);
    return {
      ...regular,
      'seasons': [...regularRows, ...playoffRows],
      'regular_seasons': regularRows,
      'playoff_seasons': playoffRows,
      'website_season_split': true,
    };
  }

  Future<Map<String, dynamic>> _playerDossierRequest(
    String playerKey, {
    required String seasonType,
    required int recentGames,
  }) {
    return _get(
      '/v2/nba/history/players/${Uri.encodeComponent(playerKey)}/dossier',
      query: {
        'league': 'NBA',
        'season_type': seasonType,
        'recent_games': '$recentGames',
      },
    );
  }

  Future<Map<String, dynamic>> teamDossier(String teamKey) {
    return _get(
      '/v2/nba/history/teams/${Uri.encodeComponent(teamKey)}/dossier',
      query: const {'league': 'NBA', 'season_type': 'regular', 'recent_games': '30'},
    );
  }

  Future<Map<String, dynamic>> searchEntities(
    String query, {
    String kinds = 'player,team',
    int limitPerKind = 12,
  }) {
    return _get(
      '/v2/nba/history/entities/search',
      query: {
        'query': query,
        'league': 'NBA',
        'kinds': kinds,
        'limit_per_kind': '$limitPerKind',
      },
    );
  }

  Future<String?> resolveTeamKey(String idOrAbbreviation) async {
    final value = idOrAbbreviation.trim();
    if (value.isEmpty) return null;
    try {
      await teamDossier(value);
      return value;
    } catch (_) {
      final result = await searchEntities(value, kinds: 'team', limitPerKind: 20);
      final groups = result['groups'];
      if (groups is! Map || groups['teams'] is! List) return null;
      final teams = groups['teams'] as List;
      Map<String, dynamic>? fallback;
      for (final raw in teams) {
        if (raw is! Map) continue;
        final row = raw.map((key, item) => MapEntry(key.toString(), item));
        fallback ??= row;
        final abbreviation = (row['abbreviation'] ?? '').toString();
        if (abbreviation.toUpperCase() == value.toUpperCase()) {
          return row['team_key']?.toString();
        }
      }
      return fallback?['team_key']?.toString();
    }
  }

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
      throw const WebsiteNbaApiException('Sports Terminal backend URL is empty.');
    }
    final base = Uri.parse(normalized);
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}$path',
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
          .timeout(const Duration(seconds: 45));
      Object? decoded;
      if (response.body.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          throw WebsiteNbaApiException(
            'NBA API returned non-JSON content (${response.statusCode}).',
            statusCode: response.statusCode,
          );
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map && decoded['detail'] != null
            ? decoded['detail'].toString()
            : 'NBA API request failed (${response.statusCode}).';
        throw WebsiteNbaApiException(detail, statusCode: response.statusCode);
      }
      if (decoded is! Map) {
        throw const WebsiteNbaApiException('NBA API returned an unexpected response shape.');
      }
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } on TimeoutException {
      throw const WebsiteNbaApiException('NBA API request timed out.');
    } on WebsiteNbaApiException {
      rethrow;
    } catch (error) {
      throw WebsiteNbaApiException('NBA API unavailable: $error');
    }
  }
}

class WebsiteNbaApiException implements Exception {
  const WebsiteNbaApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, field) => MapEntry(key.toString(), field)),
  ];
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

int _seasonStart(String value) {
  final match = RegExp(r'(19|20)\d{2}').firstMatch(value);
  return match == null ? 0 : int.tryParse(match.group(0) ?? '') ?? 0;
}
