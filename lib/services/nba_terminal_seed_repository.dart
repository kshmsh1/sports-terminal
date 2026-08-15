import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:http/http.dart' as http;

import 'product_local_store.dart';

class NbaTerminalSeedRepository {
  const NbaTerminalSeedRepository({
    this.basePath,
    this.configPath = 'assets/data/nba/launch/season_config.json',
    ProductLocalStore store = const ProductLocalStore(),
  }) : _store = store;

  static const dataScopeKey = 'sports_terminal.nba.data_scope';
  static const historicalSeasonKey = 'sports_terminal.nba.historical_season';
  static const historicalLeagueKey = 'sports_terminal.nba.historical_league';
  static const historicalSeasonTypeKey =
      'sports_terminal.nba.historical_season_type';

  final String? basePath;
  final String configPath;
  final ProductLocalStore _store;

  Future<NbaTerminalSeedSnapshot> load() async {
    if (basePath == null) {
      final scope = await _store.loadString(dataScopeKey, fallback: 'current');
      if (scope == 'historical') {
        final season = await _store.loadString(historicalSeasonKey);
        if (season.isNotEmpty) {
          final league = await _store.loadString(
            historicalLeagueKey,
            fallback: 'NBA',
          );
          final seasonType = await _store.loadString(
            historicalSeasonTypeKey,
            fallback: 'regular',
          );
          return loadHistoricalSeason(
            season,
            league: league,
            seasonType: seasonType,
          );
        }
      }
    }
    return loadCurrent();
  }

  Future<NbaTerminalSeedSnapshot> loadCurrent() async {
    final config = await _loadConfig();
    final candidate = basePath ??
        config['candidateAssetPath']?.toString() ??
        'assets/data/nba/terminal_seed/nba_2026';
    final fallback = config['fallbackAssetPath']?.toString() ??
        'assets/data/nba/terminal_seed/nba_2025';
    final allowFallback = config['allowFallback'] != false;

    // On Flutter Web, probing a missing asset emits a noisy engine-level 404
    // before rootBundle throws. Consult the bundle manifest first so an absent
    // current-season candidate can fall back without requesting every file.
    if (allowFallback &&
        candidate != fallback &&
        !await _assetExists('$candidate/manifest.json')) {
      return _loadFrom(
        fallback,
        launchConfig: config,
        usedFallback: true,
      );
    }

    try {
      return await _loadFrom(
        candidate,
        launchConfig: config,
        usedFallback: false,
      );
    } catch (_) {
      if (!allowFallback || candidate == fallback) rethrow;
      return _loadFrom(
        fallback,
        launchConfig: config,
        usedFallback: true,
      );
    }
  }

  Future<void> selectCurrent() => _store.saveString(dataScopeKey, 'current');

  Future<void> selectHistorical(
    String season, {
    String league = 'NBA',
    String seasonType = 'regular',
  }) async {
    await _store.saveString(dataScopeKey, 'historical');
    await _store.saveString(historicalSeasonKey, season);
    await _store.saveString(historicalLeagueKey, league.toUpperCase());
    await _store.saveString(historicalSeasonTypeKey, seasonType);
  }

  Future<NbaTerminalSeedSnapshot> loadHistoricalSeason(
    String season, {
    String league = 'NBA',
    String seasonType = 'regular',
    bool includeGameLogs = true,
  }) async {
    final normalizedSeason = season.trim();
    if (normalizedSeason.isEmpty) {
      throw const NbaTerminalSeedException('Historical season is required.');
    }
    final baseUrl = await _store.loadString(
      ProductLocalStore.backendBaseUrlKey,
      fallback: 'http://127.0.0.1:8000',
    );
    final normalizedBase = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalizedBase.isEmpty) {
      throw const NbaTerminalSeedException('Sports Terminal backend URL is empty.');
    }
    final base = Uri.parse(normalizedBase);
    final relative = '/v2/nba/history/seed/${Uri.encodeComponent(normalizedSeason)}';
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}$relative',
      queryParameters: {
        'league': league.trim().isEmpty ? 'NBA' : league.trim().toUpperCase(),
        'season_type': seasonType,
        'include_game_logs': includeGameLogs ? 'true' : 'false',
      },
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
          throw NbaTerminalSeedException(
            'Historical NBA snapshot returned non-JSON content (${response.statusCode}).',
            statusCode: response.statusCode,
          );
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map && decoded['detail'] != null
            ? decoded['detail'].toString()
            : 'Historical NBA snapshot request failed (${response.statusCode}).';
        throw NbaTerminalSeedException(
          detail,
          statusCode: response.statusCode,
        );
      }
      if (decoded is! Map) {
        throw const NbaTerminalSeedException(
          'Historical NBA snapshot returned an unexpected response shape.',
        );
      }
      return NbaTerminalSeedSnapshot.fromMap(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on TimeoutException {
      throw const NbaTerminalSeedException(
        'Historical NBA snapshot timed out. Confirm the local backend is running.',
      );
    } on NbaTerminalSeedException {
      rethrow;
    } catch (error) {
      throw NbaTerminalSeedException(
        'Historical NBA snapshot unavailable: $error',
      );
    }
  }

  Future<Map<String, dynamic>> _loadConfig() async {
    try {
      final raw = await rootBundle.loadString(configPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } on FlutterError {
      // Older tests and development builds may not include launch config yet.
    } catch (_) {
      // A malformed launch config should not make the validated fallback seed
      // unavailable to the rest of the terminal.
    }
    return const {
      'supportedSeason': '2025-26',
      'candidateAssetPath': 'assets/data/nba/terminal_seed/nba_2026',
      'fallbackAssetPath': 'assets/data/nba/terminal_seed/nba_2025',
      'datasetStatus': 'missing-config',
      'allowFallback': true,
    };
  }

  Future<NbaTerminalSeedSnapshot> _loadFrom(
    String resolvedBasePath, {
    required Map<String, dynamic> launchConfig,
    required bool usedFallback,
  }) async {
    final documents = await Future.wait<dynamic>([
      _loadObject(resolvedBasePath, 'manifest.json'),
      _loadList(resolvedBasePath, 'teams.json'),
      _loadList(resolvedBasePath, 'players.json'),
      _loadList(resolvedBasePath, 'games.json'),
      _loadList(resolvedBasePath, 'team_records.json'),
      _loadList(resolvedBasePath, 'team_game_logs.json'),
      _loadList(resolvedBasePath, 'player_season_totals.json'),
      _loadObject(resolvedBasePath, 'player_leaders.json'),
      _loadObject(resolvedBasePath, 'player_game_highs.json'),
      _loadPlayerLogs(resolvedBasePath),
      _loadList(resolvedBasePath, 'search_index.json'),
      _loadObject(resolvedBasePath, 'data_dictionary.json'),
      _loadOptionalObject(resolvedBasePath, 'validation_report.json'),
      _loadOptionalObject(resolvedBasePath, 'asset_manifest.json'),
      _loadOptionalObject(resolvedBasePath, 'release_manifest.json'),
      _loadOptionalList(resolvedBasePath, 'standings.json'),
      _loadOptionalFirstList(
        resolvedBasePath,
        const [
          'play_by_play.json',
          'play_by_play_events.json',
          'pbp.json',
        ],
      ),
    ]);

    return NbaTerminalSeedSnapshot(
      manifest: documents[0] as Map<String, dynamic>,
      teams: documents[1] as List<Map<String, dynamic>>,
      players: documents[2] as List<Map<String, dynamic>>,
      games: documents[3] as List<Map<String, dynamic>>,
      teamRecords: documents[4] as List<Map<String, dynamic>>,
      teamGameLogs: documents[5] as List<Map<String, dynamic>>,
      playerSeasonTotals: documents[6] as List<Map<String, dynamic>>,
      playerLeaders: documents[7] as Map<String, dynamic>,
      playerGameHighs: documents[8] as Map<String, dynamic>,
      playerGameLogsTop: documents[9] as List<Map<String, dynamic>>,
      searchIndex: documents[10] as List<Map<String, dynamic>>,
      dataDictionary: documents[11] as Map<String, dynamic>,
      validationReport: documents[12] as Map<String, dynamic>?,
      assetManifest: documents[13] as Map<String, dynamic>?,
      releaseManifest: documents[14] as Map<String, dynamic>?,
      standings: documents[15] as List<Map<String, dynamic>>? ?? const [],
      playByPlay: documents[16] as List<Map<String, dynamic>>? ?? const [],
      launchConfig: launchConfig,
      assetPath: resolvedBasePath,
      usedFallback: usedFallback,
    );
  }

  Future<List<Map<String, dynamic>>> _loadPlayerLogs(
    String resolvedBasePath,
  ) async {
    final complete = await _loadOptionalList(
      resolvedBasePath,
      'player_game_logs.json',
    );
    if (complete != null) return complete;
    return _loadList(resolvedBasePath, 'player_game_logs_top.json');
  }

  Future<List<Map<String, dynamic>>?> _loadOptionalFirstList(
    String resolvedBasePath,
    List<String> filenames,
  ) async {
    for (final filename in filenames) {
      final rows = await _loadOptionalList(resolvedBasePath, filename);
      if (rows != null) return rows;
    }
    return null;
  }

  Future<bool> _assetExists(String path) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest.listAssets().contains(path);
    } catch (_) {
      // Tests and older embedding environments may not expose the binary asset
      // manifest. Preserve the existing load-and-catch behavior in that case.
      return true;
    }
  }

  Future<Map<String, dynamic>> _loadObject(
    String resolvedBasePath,
    String filename,
  ) async {
    final raw = await rootBundle.loadString('$resolvedBasePath/$filename');
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>?> _loadOptionalObject(
    String resolvedBasePath,
    String filename,
  ) async {
    if (!await _assetExists('$resolvedBasePath/$filename')) return null;
    try {
      return await _loadObject(resolvedBasePath, filename);
    } catch (_) {
      // Flutter Web can surface a missing bundled asset either as FlutterError
      // or as an HTML fallback response that then throws FormatException while
      // decoding. Optional release metadata must never make the validated seed
      // unusable.
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _loadList(
    String resolvedBasePath,
    String filename,
  ) async {
    final raw = await rootBundle.loadString('$resolvedBasePath/$filename');
    return [
      for (final item in jsonDecode(raw) as List)
        (item as Map).cast<String, dynamic>(),
    ];
  }

  Future<List<Map<String, dynamic>>?> _loadOptionalList(
    String resolvedBasePath,
    String filename,
  ) async {
    if (!await _assetExists('$resolvedBasePath/$filename')) return null;
    try {
      return await _loadList(resolvedBasePath, filename);
    } catch (_) {
      // See _loadOptionalObject: missing optional web assets may decode as HTML
      // rather than throwing FlutterError directly.
      return null;
    }
  }
}

class NbaTerminalSeedException implements Exception {
  const NbaTerminalSeedException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class NbaTerminalSeedSnapshot {
  const NbaTerminalSeedSnapshot({
    required this.manifest,
    required this.teams,
    required this.players,
    required this.games,
    required this.teamRecords,
    required this.teamGameLogs,
    required this.playerSeasonTotals,
    required this.playerLeaders,
    required this.playerGameHighs,
    required this.playerGameLogsTop,
    required this.searchIndex,
    required this.dataDictionary,
    required this.validationReport,
    required this.assetManifest,
    this.releaseManifest,
    this.standings = const [],
    this.playByPlay = const [],
    this.launchConfig = const {},
    this.assetPath = '',
    this.usedFallback = false,
  });

  factory NbaTerminalSeedSnapshot.fromMap(Map<String, dynamic> payload) {
    return NbaTerminalSeedSnapshot(
      manifest: _seedMap(payload['manifest']),
      teams: _seedList(payload['teams']),
      players: _seedList(payload['players']),
      games: _seedList(payload['games']),
      teamRecords: _seedList(payload['team_records'] ?? payload['teamRecords']),
      teamGameLogs: _seedList(payload['team_game_logs'] ?? payload['teamGameLogs']),
      playerSeasonTotals: _seedList(
        payload['player_season_totals'] ?? payload['playerSeasonTotals'],
      ),
      playerLeaders: _seedMap(payload['player_leaders'] ?? payload['playerLeaders']),
      playerGameHighs: _seedMap(
        payload['player_game_highs'] ?? payload['playerGameHighs'],
      ),
      playerGameLogsTop: _seedList(
        payload['player_game_logs_top'] ?? payload['playerGameLogsTop'],
      ),
      searchIndex: _seedList(payload['search_index'] ?? payload['searchIndex']),
      dataDictionary: _seedMap(
        payload['data_dictionary'] ?? payload['dataDictionary'],
      ),
      validationReport: _seedNullableMap(
        payload['validation_report'] ?? payload['validationReport'],
      ),
      assetManifest: _seedNullableMap(
        payload['asset_manifest'] ?? payload['assetManifest'],
      ),
      releaseManifest: _seedNullableMap(
        payload['release_manifest'] ?? payload['releaseManifest'],
      ),
      standings: _seedList(payload['standings']),
      playByPlay: _seedList(
        payload['play_by_play'] ??
            payload['playByPlay'] ??
            payload['play_by_play_events'] ??
            payload['playByPlayEvents'],
      ),
      launchConfig: _seedMap(
        payload['launch_config'] ?? payload['launchConfig'],
      ),
      assetPath: payload['asset_path']?.toString() ??
          payload['assetPath']?.toString() ??
          '',
      usedFallback: payload['used_fallback'] == true || payload['usedFallback'] == true,
    );
  }

  final Map<String, dynamic> manifest;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> games;
  final List<Map<String, dynamic>> teamRecords;
  final List<Map<String, dynamic>> teamGameLogs;
  final List<Map<String, dynamic>> playerSeasonTotals;
  final Map<String, dynamic> playerLeaders;
  final Map<String, dynamic> playerGameHighs;
  final List<Map<String, dynamic>> playerGameLogsTop;
  final List<Map<String, dynamic>> searchIndex;
  final Map<String, dynamic> dataDictionary;
  final Map<String, dynamic>? validationReport;
  final Map<String, dynamic>? assetManifest;
  final Map<String, dynamic>? releaseManifest;
  final List<Map<String, dynamic>> standings;
  final List<Map<String, dynamic>> playByPlay;
  final Map<String, dynamic> launchConfig;
  final String assetPath;
  final bool usedFallback;

  String get validationStatus =>
      validationReport?['status']?.toString() ?? 'missing';

  String get supportedSeason =>
      launchConfig['supportedSeason']?.toString() ?? '2025-26';

  String get datasetStatus {
    if (usedFallback) return 'fallback-development-seed';
    return releaseManifest?['status']?.toString() ??
        launchConfig['datasetStatus']?.toString() ??
        validationStatus;
  }

  bool get isHistorical => datasetStatus == 'historical-canonical' ||
      assetPath.startsWith('backend://v2/nba/history/');

  String get warehouseGeneratedAt {
    final build = manifest['warehouseBuild'];
    if (build is Map && build['generatedAt'] != null) {
      return build['generatedAt'].toString();
    }
    return '—';
  }

  int get playByPlayEvents {
    if (playByPlay.isNotEmpty) return playByPlay.length;
    final build = manifest['warehouseBuild'];
    if (build is Map && build['playByPlayEventsNormalized'] is num) {
      return (build['playByPlayEventsNormalized'] as num).toInt();
    }
    return 0;
  }

  int get copiedAssetFiles {
    final files = assetManifest?['copiedFiles'];
    return files is List ? files.length : 0;
  }
}

Map<String, dynamic> _seedMap(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

Map<String, dynamic>? _seedNullableMap(Object? value) {
  if (value == null) return null;
  return _seedMap(value);
}

List<Map<String, dynamic>> _seedList(Object? value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, entry) => MapEntry(key.toString(), entry)),
  ];
}
