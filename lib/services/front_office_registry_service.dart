import 'dart:convert';

import '../models/app_session.dart';
import 'launch_backend_transport.dart';
import 'product_local_store.dart';

class FrontOfficeRegistrySnapshot {
  const FrontOfficeRegistrySnapshot({
    required this.contracts,
    required this.teamPositions,
    required this.draftAssets,
    required this.ledger,
    required this.remoteAvailable,
  });

  final List<Map<String, dynamic>> contracts;
  final List<Map<String, dynamic>> teamPositions;
  final List<Map<String, dynamic>> draftAssets;
  final List<Map<String, dynamic>> ledger;
  final bool remoteAvailable;

  int get verifiedCount => [
        ...contracts,
        ...teamPositions,
        ...draftAssets,
        ...ledger,
      ].where((item) => item['source_status'] == 'verified').length;

  int get reviewCount => [
        ...contracts,
        ...teamPositions,
        ...draftAssets,
        ...ledger,
      ].where((item) {
        final validation = item['validation'];
        return validation is Map && validation['status'] != 'pass';
      }).length;
}

class FrontOfficeRegistryService {
  const FrontOfficeRegistryService({
    LaunchBackendTransport transport = const LaunchBackendTransport(),
    ProductLocalStore store = const ProductLocalStore(),
  })  : _transport = transport,
        _store = store;

  final LaunchBackendTransport _transport;
  final ProductLocalStore _store;

  static const _contractsKey = 'sports_terminal.front_office.contracts.v1';
  static const _positionsKey = 'sports_terminal.front_office.positions.v1';
  static const _assetsKey = 'sports_terminal.front_office.draft_assets.v1';
  static const _ledgerKey = 'sports_terminal.front_office.ledger.v1';

  Future<FrontOfficeRegistrySnapshot> load({
    required AppSession session,
    String season = '2025-26',
  }) async {
    final useSalarySnapshot = season == '2026-27';
    final contractsFuture = _loadCollection(
      '/v2/front-office/contracts',
      _contractsKey,
      query: {'season': season, 'limit': '1000'},
      snapshotPath:
          useSalarySnapshot ? '/v2/front-office-snapshot/contracts' : null,
    );
    final positionsFuture = _loadCollection(
      '/v2/front-office/team-positions',
      _positionsKey,
      query: {'season': season},
      snapshotPath: useSalarySnapshot
          ? '/v2/front-office-snapshot/team-positions'
          : null,
    );
    final assetsFuture = _loadCollection(
      '/v2/front-office/draft-assets',
      _assetsKey,
    );
    final ledgerFuture = _loadCollection(
      '/v2/front-office/ledger',
      _ledgerKey,
      query: {
        'season': season,
        if (session.organizationId.isNotEmpty)
          'organization_id': session.organizationId,
      },
    );
    final results = await Future.wait([
      contractsFuture,
      positionsFuture,
      assetsFuture,
      ledgerFuture,
    ]);
    return FrontOfficeRegistrySnapshot(
      contracts: results[0].rows,
      teamPositions: results[1].rows,
      draftAssets: results[2].rows,
      ledger: results[3].rows,
      remoteAvailable: results.any((result) => result.remoteAvailable),
    );
  }

  Future<Map<String, dynamic>?> upsertContract({
    required AppSession session,
    required String id,
    required Map<String, dynamic> record,
  }) {
    return _upsert(
      path: '/v2/front-office/contracts/$id',
      cacheKey: _contractsKey,
      session: session,
      record: record,
    );
  }

  Future<Map<String, dynamic>?> upsertTeamPosition({
    required AppSession session,
    required String id,
    required Map<String, dynamic> record,
  }) {
    return _upsert(
      path: '/v2/front-office/team-positions/$id',
      cacheKey: _positionsKey,
      session: session,
      record: record,
    );
  }

  Future<Map<String, dynamic>?> upsertDraftAsset({
    required AppSession session,
    required String id,
    required Map<String, dynamic> record,
  }) {
    return _upsert(
      path: '/v2/front-office/draft-assets/$id',
      cacheKey: _assetsKey,
      session: session,
      record: record,
    );
  }

  Future<Map<String, dynamic>?> upsertLedger({
    required AppSession session,
    required String id,
    required Map<String, dynamic> record,
  }) {
    return _upsert(
      path: '/v2/front-office/ledger/$id',
      cacheKey: _ledgerKey,
      session: session,
      record: {
        ...record,
        if (record['organization_id'] == null)
          'organization_id': session.organizationId,
      },
    );
  }

  Future<Map<String, dynamic>?> reconcile({
    required String teamId,
    String season = '2025-26',
  }) async {
    final response = await _transport.getJson(
      '/v2/front-office/reconcile/${teamId.toUpperCase()}/$season',
    );
    if (!response.available || response.data is! Map) return null;
    return _map(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> versions(String recordId) async {
    final response = await _transport.getJson(
      '/v2/front-office/records/$recordId/versions',
    );
    if (!response.available || response.data is! List) return const [];
    return _list(response.data);
  }

  Future<Map<String, dynamic>?> addLedgerEvent({
    required AppSession session,
    required String ledgerId,
    required String eventType,
    required String message,
    Map<String, dynamic> payload = const {},
  }) async {
    final response = await _transport.postJson(
      '/v2/front-office/ledger/$ledgerId/events',
      {
        'actor_user_id': session.userId,
        'event_type': eventType,
        'message': message,
        'payload': payload,
      },
    );
    if (!response.available || response.data is! Map) return null;
    return _map(response.data as Map);
  }

  Future<_CollectionResult> _loadCollection(
    String path,
    String cacheKey, {
    Map<String, String> query = const {},
    String? snapshotPath,
  }) async {
    final response = await _transport.getJson(path, query: query);
    final liveRows = response.available && response.data is List
        ? _list(response.data)
        : <Map<String, dynamic>>[];

    var snapshotRows = <Map<String, dynamic>>[];
    var snapshotAvailable = false;
    if (snapshotPath != null) {
      final snapshot = await _transport.getJson(snapshotPath, query: query);
      snapshotAvailable = snapshot.available && snapshot.data is List;
      if (snapshotAvailable) snapshotRows = _list(snapshot.data);
    }

    if (response.available || snapshotAvailable) {
      final rows = _mergeRows(liveRows, snapshotRows);
      await _store.saveString(cacheKey, jsonEncode(rows));
      return _CollectionResult(rows, true);
    }

    final cached = await _store.loadString(cacheKey);
    if (cached.isEmpty) return const _CollectionResult([], false);
    try {
      final decoded = jsonDecode(cached);
      return _CollectionResult(_list(decoded), false);
    } catch (_) {
      return const _CollectionResult([], false);
    }
  }

  Future<Map<String, dynamic>?> _upsert({
    required String path,
    required String cacheKey,
    required AppSession session,
    required Map<String, dynamic> record,
  }) async {
    final response = await _transport.putJson(
      path,
      {
        'actor_user_id': session.userId,
        'record_status': 'active',
        'record': record,
      },
    );
    if (!response.available || response.data is! Map) return null;
    final item = _map(response.data as Map);
    final cached = await _store.loadString(cacheKey);
    final rows = <Map<String, dynamic>>[];
    if (cached.isNotEmpty) {
      try {
        rows.addAll(_list(jsonDecode(cached)));
      } catch (_) {
        // Replace an unreadable cache with the server response.
      }
    }
    rows.removeWhere((row) => row['id'] == item['id']);
    rows.insert(0, item);
    await _store.saveString(cacheKey, jsonEncode(rows));
    return item;
  }

  static List<Map<String, dynamic>> _mergeRows(
    List<Map<String, dynamic>> liveRows,
    List<Map<String, dynamic>> snapshotRows,
  ) {
    if (snapshotRows.isEmpty) return liveRows;
    final occupied = <String>{for (final row in liveRows) _identity(row)};
    final merged = <Map<String, dynamic>>[...liveRows];
    for (final row in snapshotRows) {
      final identity = _identity(row);
      if (occupied.add(identity)) merged.add(row);
    }
    return merged;
  }

  static String _identity(Map<String, dynamic> wrapper) {
    final raw = wrapper['record'];
    final record = raw is Map ? _map(raw) : wrapper;
    final type = '${wrapper['record_type'] ?? ''}';
    final team = '${record['team_id'] ?? record['current_team_id'] ?? wrapper['team_id'] ?? ''}';
    final player = '${record['player_id'] ?? wrapper['player_id'] ?? ''}';
    if (player.isNotEmpty) return '$type:$team:$player';
    if (type == 'team_position') return '$type:$team:${record['season'] ?? wrapper['season'] ?? ''}';
    return '${wrapper['id'] ?? '$type:$team:${mergedIdentityFallback(record)}'}';
  }

  static String mergedIdentityFallback(Map<String, dynamic> record) =>
      '${record['id'] ?? record['description'] ?? record['summary'] ?? record.hashCode}';

  static List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) _map(item),
    ];
  }

  static Map<String, dynamic> _map(Map value) => value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
}

class _CollectionResult {
  const _CollectionResult(this.rows, this.remoteAvailable);

  final List<Map<String, dynamic>> rows;
  final bool remoteAvailable;
}
