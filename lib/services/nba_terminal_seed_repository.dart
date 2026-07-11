import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show rootBundle;

class NbaTerminalSeedRepository {
  const NbaTerminalSeedRepository({this.basePath = 'assets/data/nba/terminal_seed/nba_2025'});

  final String basePath;

  Future<NbaTerminalSeedSnapshot> load() async {
    final documents = await Future.wait<dynamic>([
      _loadObject('manifest.json'),
      _loadList('teams.json'),
      _loadList('players.json'),
      _loadList('games.json'),
      _loadList('team_records.json'),
      _loadList('team_game_logs.json'),
      _loadList('player_season_totals.json'),
      _loadObject('player_leaders.json'),
      _loadObject('player_game_highs.json'),
      _loadList('player_game_logs_top.json'),
      _loadList('search_index.json'),
      _loadObject('data_dictionary.json'),
      _loadOptionalObject('validation_report.json'),
      _loadOptionalObject('asset_manifest.json'),
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
    );
  }

  Future<Map<String, dynamic>> _loadObject(String filename) async {
    final raw = await rootBundle.loadString('$basePath/$filename');
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>?> _loadOptionalObject(String filename) async {
    try {
      return await _loadObject(filename);
    } on FlutterError {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _loadList(String filename) async {
    final raw = await rootBundle.loadString('$basePath/$filename');
    return [for (final item in jsonDecode(raw) as List) (item as Map).cast<String, dynamic>()];
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

  String get validationStatus => validationReport?['status']?.toString() ?? 'missing';

  String get warehouseGeneratedAt {
    final build = manifest['warehouseBuild'];
    if (build is Map && build['generatedAt'] != null) return build['generatedAt'].toString();
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
