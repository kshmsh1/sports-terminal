import 'package:http/http.dart' as http;

import 'sports_terminal_static_config.dart';
import 'sports_terminal_static_json_loader.dart';

class FrontOfficeStaticSnapshot {
  const FrontOfficeStaticSnapshot({
    required this.contracts,
    required this.teamPositions,
    required this.draftAssets,
    required this.ledger,
  });

  final List<Map<String, dynamic>> contracts;
  final List<Map<String, dynamic>> teamPositions;
  final List<Map<String, dynamic>> draftAssets;
  final List<Map<String, dynamic>> ledger;

  static const empty = FrontOfficeStaticSnapshot(
    contracts: [],
    teamPositions: [],
    draftAssets: [],
    ledger: [],
  );
}

class FrontOfficeStaticSnapshotRepository {
  FrontOfficeStaticSnapshotRepository({
    http.Client? client,
    String? basePath,
  }) : basePath = basePath ?? sportsTerminalStaticPath('front_office'),
        _client = client ?? http.Client() {
    _loader = SportsTerminalStaticJsonLoader(_client);
  }

  final http.Client _client;
  late final SportsTerminalStaticJsonLoader _loader;
  final String basePath;
  FrontOfficeStaticSnapshot? _cache;

  Future<FrontOfficeStaticSnapshot> load() async {
    if (_cache != null) return _cache!;
    final results = await Future.wait([
      _listOrEmpty('contracts.json'),
      _listOrEmpty('team_positions.json'),
      _listOrEmpty('draft_assets.json'),
      _listOrEmpty('ledger.json'),
    ]);
    return _cache = FrontOfficeStaticSnapshot(
      contracts: results[0],
      teamPositions: results[1],
      draftAssets: results[2],
      ledger: results[3],
    );
  }

  Future<List<Map<String, dynamic>>> _listOrEmpty(String relative) async {
    try {
      final decoded = await _loader
          .load(basePath, relative)
          .timeout(const Duration(seconds: 12));
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            item.map((key, value) => MapEntry(key.toString(), value)),
      ];
    } catch (_) {
      return const [];
    }
  }
}
