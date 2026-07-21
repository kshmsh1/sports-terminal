import 'dart:convert';

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
  static const workspaceImportMetadataKey = 'sports_terminal.workspace.import_metadata';
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
  static const backendConversationIdKey = 'sports_terminal.backend.conversation_id';
  static const frontOfficeScenarioKey = 'sports_terminal.front_office.scenario';
  static const statsQueryKey = 'sports_terminal.stats.query';
  static const tradeMachineStateKey = 'sports_terminal.trade_machine.state';
  static const routePayloadActiveKey = 'sports_terminal.routes.active_payload';
  static const routePayloadHistoryKey = 'sports_terminal.routes.history';
  static const objectRouterStateKey = 'sports_terminal.object_router.state';
  static const pythonNotebookCodeKey = 'sports_terminal.python.notebook_code';
  static const pythonNotebookOutputKey = 'sports_terminal.python.notebook_output';
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
      if (decoded is List) return decoded.map((value) => value.toString()).toSet();
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
    final encoded = preferences.getString(key);
    if (encoded == null || encoded.isEmpty) return Map<String, String>.from(fallback);
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

  Future<void> saveStringMap(String key, Map<String, String> values) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(values));
  }
}
