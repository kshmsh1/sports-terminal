import 'dart:convert';

import '../models/app_session.dart';
import 'launch_backend_transport.dart';
import 'product_local_store.dart';

class ConnectedWorkbook {
  const ConnectedWorkbook({
    required this.title,
    required this.activeSheet,
    required this.sheets,
    required this.version,
    required this.remoteAvailable,
    required this.permissions,
    required this.updatedAt,
  });

  final String title;
  final String activeSheet;
  final Map<String, Map<String, String>> sheets;
  final int version;
  final bool remoteAvailable;
  final List<Map<String, dynamic>> permissions;
  final String updatedAt;

  Map<String, String> get activeCells =>
      Map<String, String>.from(sheets[activeSheet] ?? const {});

  ConnectedWorkbook copyWith({
    String? title,
    String? activeSheet,
    Map<String, Map<String, String>>? sheets,
    int? version,
    bool? remoteAvailable,
    List<Map<String, dynamic>>? permissions,
    String? updatedAt,
  }) {
    return ConnectedWorkbook(
      title: title ?? this.title,
      activeSheet: activeSheet ?? this.activeSheet,
      sheets: sheets ?? _deepCopy(sheets: this.sheets),
      version: version ?? this.version,
      remoteAvailable: remoteAvailable ?? this.remoteAvailable,
      permissions: permissions ?? [for (final item in this.permissions) {...item}],
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'active_sheet': activeSheet,
        'sheets': sheets,
        'version': version,
        'remote_available': remoteAvailable,
        'permissions': permissions,
        'updated_at': updatedAt,
      };

  factory ConnectedWorkbook.fromJson(
    Map<String, dynamic> json, {
    bool remoteAvailable = false,
  }) {
    final rawSheets = json['sheets'];
    final sheets = <String, Map<String, String>>{};
    if (rawSheets is Map) {
      for (final entry in rawSheets.entries) {
        if (entry.value is! Map) continue;
        sheets[entry.key.toString()] = (entry.value as Map).map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
      }
    }
    if (sheets.isEmpty) sheets['Sheet 1'] = {};
    final requested = json['active_sheet']?.toString() ?? sheets.keys.first;
    final active = sheets.containsKey(requested) ? requested : sheets.keys.first;
    return ConnectedWorkbook(
      title: json['title']?.toString() ?? 'Sports Terminal Workbook',
      activeSheet: active,
      sheets: sheets,
      version: (json['version'] as num?)?.toInt() ?? 0,
      remoteAvailable: remoteAvailable,
      permissions: json['permissions'] is List
          ? [
              for (final item in json['permissions'] as List)
                if (item is Map)
                  item.map((key, value) => MapEntry(key.toString(), value)),
            ]
          : const [],
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  static Map<String, Map<String, String>> _deepCopy({
    required Map<String, Map<String, String>> sheets,
  }) => {
        for (final entry in sheets.entries)
          entry.key: Map<String, String>.from(entry.value),
      };
}

class WorkspaceSaveResult {
  const WorkspaceSaveResult({
    required this.saved,
    required this.remoteAvailable,
    required this.conflict,
    required this.error,
    required this.workbook,
  });

  final bool saved;
  final bool remoteAvailable;
  final bool conflict;
  final String error;
  final ConnectedWorkbook workbook;
}

class ConnectedWorkspaceService {
  const ConnectedWorkspaceService({
    LaunchBackendTransport transport = const LaunchBackendTransport(),
    ProductLocalStore store = const ProductLocalStore(),
  })  : _transport = transport,
        _store = store;

  final LaunchBackendTransport _transport;
  final ProductLocalStore _store;

  static const _workbookCacheKey = 'sports_terminal.workspace.connected.v2';

  Future<ConnectedWorkbook> load(AppSession session) async {
    final context = _context(session);
    final response = await _transport.getJson(
      '/v2/workspaces/primary',
      query: context.query,
      timeout: const Duration(seconds: 3),
    );
    if (response.succeeded && response.data is Map) {
      final workbook = ConnectedWorkbook.fromJson(
        _map(response.data as Map),
        remoteAvailable: true,
      );
      await _cache(workbook);
      await _syncLegacyKeys(workbook);
      return workbook;
    }

    final cached = await _loadCache();
    if (cached != null) {
      return cached.copyWith(remoteAvailable: false);
    }
    final migrated = await _migrateLegacy();
    await _cache(migrated);
    return migrated;
  }

  Future<WorkspaceSaveResult> save({
    required AppSession session,
    required ConnectedWorkbook workbook,
  }) async {
    final context = _context(session);
    final local = workbook.copyWith(
      remoteAvailable: false,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _cache(local);
    await _syncLegacyKeys(local);

    final response = await _transport.putJson(
      '/v2/workspaces/primary',
      {
        'actor_user_id': session.userId,
        'scope': context.scope,
        'owner_user_id': context.ownerUserId,
        'organization_id': context.organizationId,
        'title': workbook.title,
        'active_sheet': workbook.activeSheet,
        'sheets': workbook.sheets,
        'expected_version': workbook.version,
      },
      timeout: const Duration(seconds: 5),
    );
    if (response.succeeded && response.data is Map) {
      final saved = ConnectedWorkbook.fromJson(
        _map(response.data as Map),
        remoteAvailable: true,
      );
      await _cache(saved);
      await _syncLegacyKeys(saved);
      return WorkspaceSaveResult(
        saved: true,
        remoteAvailable: true,
        conflict: false,
        error: '',
        workbook: saved,
      );
    }
    return WorkspaceSaveResult(
      saved: false,
      remoteAvailable: response.available,
      conflict: response.statusCode == 409,
      error: response.error,
      workbook: local,
    );
  }

  Future<List<Map<String, dynamic>>> versions(AppSession session) async {
    final context = _context(session);
    final response = await _transport.getJson(
      '/v2/workspaces/primary/versions',
      query: context.query,
      timeout: const Duration(seconds: 3),
    );
    if (!response.succeeded || response.data is! List) return const [];
    return _list(response.data);
  }

  Future<WorkspaceSaveResult> restore({
    required AppSession session,
    required ConnectedWorkbook current,
    required int version,
  }) async {
    final context = _context(session);
    final response = await _transport.postJson(
      '/v2/workspaces/primary/restore',
      {
        'actor_user_id': session.userId,
        'owner_user_id': context.ownerUserId,
        'scope': context.scope,
        'organization_id': context.organizationId,
        'version': version,
        'expected_current_version': current.version,
      },
      timeout: const Duration(seconds: 5),
    );
    if (response.succeeded && response.data is Map) {
      final restored = ConnectedWorkbook.fromJson(
        _map(response.data as Map),
        remoteAvailable: true,
      );
      await _cache(restored);
      await _syncLegacyKeys(restored);
      return WorkspaceSaveResult(
        saved: true,
        remoteAvailable: true,
        conflict: false,
        error: '',
        workbook: restored,
      );
    }
    return WorkspaceSaveResult(
      saved: false,
      remoteAvailable: response.available,
      conflict: response.statusCode == 409,
      error: response.error,
      workbook: current,
    );
  }

  Future<List<Map<String, dynamic>>> permissions(AppSession session) async {
    final context = _context(session);
    final response = await _transport.getJson(
      '/v2/workspaces/primary/permissions',
      query: context.query,
    );
    if (!response.succeeded || response.data is! List) return const [];
    return _list(response.data);
  }

  Future<bool> grantPermission({
    required AppSession session,
    required String userId,
    required String permission,
  }) async {
    final context = _context(session);
    final response = await _transport.putJson(
      '/v2/workspaces/primary/permissions',
      {
        'actor_user_id': session.userId,
        'owner_user_id': context.ownerUserId,
        'scope': context.scope,
        'organization_id': context.organizationId,
        'user_id': userId,
        'permission': permission,
      },
    );
    return response.succeeded;
  }

  Future<bool> removePermission({
    required AppSession session,
    required String userId,
  }) async {
    final context = _context(session);
    final response = await _transport.deleteJson(
      '/v2/workspaces/primary/permissions',
      query: {
        ...context.query,
        'actor_user_id': session.userId,
        'user_id': userId,
      },
    );
    return response.succeeded;
  }

  Future<void> _cache(ConnectedWorkbook workbook) {
    return _store.saveString(_workbookCacheKey, jsonEncode(workbook.toJson()));
  }

  Future<ConnectedWorkbook?> _loadCache() async {
    final encoded = await _store.loadString(_workbookCacheKey);
    if (encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        return ConnectedWorkbook.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<ConnectedWorkbook> _migrateLegacy() async {
    final cells = await _store.loadStringMap(
      ProductLocalStore.workbookCellsKey,
      fallback: _watchlistTemplate(),
    );
    final sheet = await _store.loadString(
      ProductLocalStore.workbookSheetKey,
      fallback: 'Watchlist',
    );
    return ConnectedWorkbook(
      title: 'Sports Terminal Workbook',
      activeSheet: sheet.isEmpty ? 'Watchlist' : sheet,
      sheets: {sheet.isEmpty ? 'Watchlist' : sheet: cells},
      version: 0,
      remoteAvailable: false,
      permissions: const [],
      updatedAt: '',
    );
  }

  Future<void> _syncLegacyKeys(ConnectedWorkbook workbook) async {
    await _store.saveStringMap(
      ProductLocalStore.workbookCellsKey,
      workbook.activeCells,
    );
    await _store.saveString(
      ProductLocalStore.workbookSheetKey,
      workbook.activeSheet,
    );
  }

  _WorkspaceContext _context(AppSession session) {
    final organization =
        session.role.canManageOrganization && session.organizationId.isNotEmpty;
    return _WorkspaceContext(
      scope: organization ? 'organization' : 'personal',
      ownerUserId: session.userId,
      organizationId: organization ? session.organizationId : '',
    );
  }

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

class _WorkspaceContext {
  const _WorkspaceContext({
    required this.scope,
    required this.ownerUserId,
    required this.organizationId,
  });

  final String scope;
  final String ownerUserId;
  final String organizationId;

  Map<String, String> get query => {
        'owner_user_id': ownerUserId,
        'scope': scope,
        if (organizationId.isNotEmpty) 'organization_id': organizationId,
      };
}

Map<String, String> _watchlistTemplate() => {
      'A1': 'Player',
      'B1': 'Team',
      'C1': 'Metric',
      'D1': 'Value',
      'A2': 'Route NBA data here',
      'B2': '—',
      'C2': 'Status',
      'D2': 'Ready',
    };
