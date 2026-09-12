import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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
    this.basePath = 'data/nba_static/front_office',
  }) : _client = client ?? http.Client();

  final http.Client _client;
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
    final uri = Uri.base.resolve('${_normalizedBase()}/$relative');
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            item.map((key, value) => MapEntry(key.toString(), value)),
      ];
    } on TimeoutException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  String _normalizedBase() => basePath.replaceAll(RegExp(r'^/+|/+$'), '');
}
