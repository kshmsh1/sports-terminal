import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show rootBundle;

class NbaTerminalSeedRepository {
  const NbaTerminalSeedRepository({
    this.basePath,
    this.configPath = 'assets/data/nba/launch/season_config.json',
  });

  final String? basePath;
  final String configPath;

  Future<NbaTerminalSeedSnapshot> load() async {
    final config = await _loadConfig();
    final candidate = basePath ??
        config['candidateAssetPath']?.toString() ??
        'assets/data/nba/terminal_seed/nba_2026';
    final fallback = config['fallbackAssetPath']?.toString() ??
        'assets/data/nba/terminal_seed/nba_2025';
    final allowFallback = config['allowFallback'] != false;

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
    try {
      return await _loadObject(resolvedBasePath, filename);
    } on FlutterError {
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
    try {
      return await _loadList(resolvedBasePath, filename);
    } on FlutterError {
      return null;
    }
  }
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
    this.launchConfig = const {},
    this.assetPath = '',
    this.usedFallback = false,
  });

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

  String get warehouseGeneratedAt {
    final build = manifest['warehouseBuild'];
    if (build is Map && build['generatedAt'] != null) {
      return build['generatedAt'].toString();
    }
    return '—';
  }

  int get playByPlayEvents {
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
