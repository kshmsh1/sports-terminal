import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProductLocalStore {
  const ProductLocalStore();

  static const darkModeKey = 'sports_terminal.theme.dark_mode';
  static const favoriteTeamsKey = 'sports_terminal.favorites.teams';
  static const playerWatchlistKey = 'sports_terminal.watchlist.players';
  static const communityLikesKey = 'sports_terminal.community.liked_posts';
  static const profileSettingsKey = 'sports_terminal.profile.settings';
  static const workbookCellsKey = 'sports_terminal.workspace.cells';
  static const workbookSheetKey = 'sports_terminal.workspace.sheet';
  static const workspaceImportMetadataKey =
      'sports_terminal.workspace.import_metadata';
  static const nbaModeKey = 'sports_terminal.nba.mode';
  static const nbaSelectedPlayerKey = 'sports_terminal.nba.selected_player';
  static const nbaSelectedTeamKey = 'sports_terminal.nba.selected_team';
  static const nbaSelectedGameKey = 'sports_terminal.nba.selected_game';
  static const fantasyQueryKey = 'sports_terminal.fantasy.query';
  static const communityBoardKey = 'sports_terminal.community.board';
  static const backendUserIdKey = 'sports_terminal.backend.user_id';
  static const backendLastSyncKey = 'sports_terminal.backend.last_sync';
  static const backendBaseUrlKey = 'sports_terminal.backend.base_url';
  static const backendWorkbookIdKey = 'sports_terminal.backend.workbook_id';
  static const backendConversationIdKey =
      'sports_terminal.backend.conversation_id';
  static const launchRemoteSyncEnabledKey =
      'sports_terminal.launch.remote_sync_enabled';
  static const launchAuthTokenKey = 'sports_terminal.launch.auth_token';
  static const launchAuthSessionKey = 'sports_terminal.launch.auth_session';
  static const launchAuthExpiresAtKey =
      'sports_terminal.launch.auth_expires_at';
  static const frontOfficeScenarioKey =
      'sports_terminal.front_office.scenario';
  static const statsQueryKey = 'sports_terminal.stats.query';
  static const tradeMachineStateKey = 'sports_terminal.trade_machine.state';
  static const routePayloadActiveKey =
      'sports_terminal.routes.active_payload';
  static const routePayloadHistoryKey = 'sports_terminal.routes.history';
  static const objectRouterStateKey = 'sports_terminal.object_router.state';
  static const pythonNotebookCodeKey =
      'sports_terminal.python.notebook_code';
  static const pythonNotebookOutputKey =
      'sports_terminal.python.notebook_output';
  static const capLabStateKey = 'sports_terminal.cap_lab.state';

  Future<bool> loadBool(String key, {bool fallback = false}) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(key) ?? fallback;
  }

  Future<void> saveBool(String key, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
  }

  Future<String> loadString(String key, {String fallback = ''}) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key) ?? fallback;
  }

  Future<void> saveString(String key, String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, value);
    if (key == workbookSheetKey) {
      final cells = _decodeStringMap(
        preferences.getString(workbookCellsKey),
        const {},
      );
      unawaited(_syncRemoteWorkbook(preferences, cells));
    }
  }

  Future<void> remove(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }

  Future<Set<String>> loadStringSet(
    String key, {
    Set<String> fallback = const {},
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(key);
    if (encoded == null || encoded.isEmpty) return Set<String>.from(fallback);
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is List) {
        return decoded.map((value) => value.toString()).toSet();
      }
    } catch (_) {
      return Set<String>.from(fallback);
    }
    return Set<String>.from(fallback);
  }

  Future<void> saveStringSet(String key, Set<String> values) async {
    final preferences = await SharedPreferences.getInstance();
    final sorted = values.toList()..sort();
    await preferences.setString(key, jsonEncode(sorted));
  }

  Future<Map<String, String>> loadStringMap(
    String key, {
    Map<String, String> fallback = const {},
  }) async {
    final preferences = await SharedPreferences.getInstance();
    if (key == workbookCellsKey) {
      final remote = await _loadRemoteWorkbook(preferences);
      if (remote != null) return remote;
    }
    return _decodeStringMap(preferences.getString(key), fallback);
  }

  Future<void> saveStringMap(String key, Map<String, String> values) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(values));
    if (key == workbookCellsKey) {
      unawaited(_syncRemoteWorkbook(preferences, values));
    }
  }

  Map<String, String> _decodeStringMap(
    String? encoded,
    Map<String, String> fallback,
  ) {
    if (encoded == null || encoded.isEmpty) {
      return Map<String, String>.from(fallback);
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
      }
    } catch (_) {
      return Map<String, String>.from(fallback);
    }
    return Map<String, String>.from(fallback);
  }

  Future<Map<String, String>?> _loadRemoteWorkbook(
    SharedPreferences preferences,
  ) async {
    final context = _workspaceContext(preferences);
    if (context == null) return null;
    try {
      final uri = _backendUri(
        preferences,
        '/v2/workspaces/primary',
        {
          'owner_user_id': context.userId,
          'scope': context.scope,
          if (context.organizationId.isNotEmpty)
            'organization_id': context.organizationId,
        },
      );
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(milliseconds: 850));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final sheets = decoded['sheets'];
      if (sheets is! Map || sheets.isEmpty) return null;
      final activeSheet = decoded['active_sheet']?.toString() ??
          preferences.getString(workbookSheetKey) ??
          sheets.keys.first.toString();
      final selected = sheets[activeSheet] ?? sheets.values.first;
      if (selected is! Map) return null;
      final cells = selected.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
      await preferences.setString(workbookCellsKey, jsonEncode(cells));
      await preferences.setString(workbookSheetKey, activeSheet);
      return cells;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncRemoteWorkbook(
    SharedPreferences preferences,
    Map<String, String> cells,
  ) async {
    final context = _workspaceContext(preferences);
    if (context == null) return;
    final sheet = preferences.getString(workbookSheetKey) ?? 'Sheet 1';
    try {
      final uri = _backendUri(
        preferences,
        '/v2/workspaces/primary',
        const {},
      );
      await http
          .put(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'actor_user_id': context.userId,
              'scope': context.scope,
              'owner_user_id': context.userId,
              'organization_id': context.organizationId,
              'title': context.scope == 'organization'
                  ? 'Organization Sports Workbook'
                  : 'My Sports Workbook',
              'active_sheet': sheet,
              'sheets': {sheet: cells},
            }),
          )
          .timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // The local workbook is still the durable offline fallback.
    } catch (_) {
      // Remote synchronization is best effort and never blocks spreadsheet edits.
    }
  }

  _WorkspaceContext? _workspaceContext(SharedPreferences preferences) {
    if (preferences.getBool(launchRemoteSyncEnabledKey) == false) return null;
    final rawSession = preferences.getString(launchAuthSessionKey);
    if (rawSession == null || rawSession.isEmpty) return null;
    try {
      final decoded = jsonDecode(rawSession);
      if (decoded is! Map) return null;
      final userId = decoded['userId']?.toString() ?? '';
      if (userId.isEmpty) return null;
      final role = decoded['role']?.toString() ?? 'analyst';
      final organizationId = decoded['organizationId']?.toString() ?? '';
      final organizationWorkspace =
          role == 'organizationAdmin' && organizationId.isNotEmpty;
      return _WorkspaceContext(
        userId: userId,
        organizationId: organizationWorkspace ? organizationId : '',
        scope: organizationWorkspace ? 'organization' : 'personal',
      );
    } catch (_) {
      return null;
    }
  }

  Uri _backendUri(
    SharedPreferences preferences,
    String path,
    Map<String, String> query,
  ) {
    final baseUrl = preferences.getString(backendBaseUrlKey) ??
        'http://127.0.0.1:8000';
    final base = Uri.parse(baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''));
    final relative = path.startsWith('/') ? path : '/$path';
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}$relative',
      queryParameters: query.isEmpty ? null : query,
    );
  }
}

class _WorkspaceContext {
  const _WorkspaceContext({
    required this.userId,
    required this.organizationId,
    required this.scope,
  });

  final String userId;
  final String organizationId;
  final String scope;
}
