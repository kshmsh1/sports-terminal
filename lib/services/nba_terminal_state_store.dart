import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NbaTerminalState {
  const NbaTerminalState({
    this.favoriteCommandIds = const <String>{},
    this.recentCommandIds = const <String>[],
    this.recentQueries = const <String>[],
  });

  final Set<String> favoriteCommandIds;
  final List<String> recentCommandIds;
  final List<String> recentQueries;

  NbaTerminalState copyWith({
    Set<String>? favoriteCommandIds,
    List<String>? recentCommandIds,
    List<String>? recentQueries,
  }) =>
      NbaTerminalState(
        favoriteCommandIds: favoriteCommandIds ?? this.favoriteCommandIds,
        recentCommandIds: recentCommandIds ?? this.recentCommandIds,
        recentQueries: recentQueries ?? this.recentQueries,
      );

  Map<String, dynamic> toJson() => {
        'favoriteCommandIds': favoriteCommandIds.toList()..sort(),
        'recentCommandIds': recentCommandIds,
        'recentQueries': recentQueries,
      };

  factory NbaTerminalState.fromJson(Map<String, dynamic> json) {
    List<String> list(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw.map((value) => value.toString()).where((value) => value.isNotEmpty).toList();
    }

    return NbaTerminalState(
      favoriteCommandIds: list('favoriteCommandIds').toSet(),
      recentCommandIds: list('recentCommandIds'),
      recentQueries: list('recentQueries'),
    );
  }
}

class NbaTerminalStateStore {
  const NbaTerminalStateStore();

  static const storageKey = 'sports_terminal.nba.terminal_state.v1';

  Future<NbaTerminalState> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(storageKey);
    if (encoded == null || encoded.isEmpty) return const NbaTerminalState();
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        return NbaTerminalState.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      return const NbaTerminalState();
    }
    return const NbaTerminalState();
  }

  Future<void> save(NbaTerminalState state) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(storageKey, jsonEncode(state.toJson()));
  }

  Future<NbaTerminalState> toggleFavorite(String commandId) async {
    final current = await load();
    final favorites = Set<String>.from(current.favoriteCommandIds);
    if (!favorites.add(commandId)) favorites.remove(commandId);
    final next = current.copyWith(favoriteCommandIds: favorites);
    await save(next);
    return next;
  }

  Future<NbaTerminalState> recordCommand(String commandId) async {
    final current = await load();
    final recents = [
      commandId,
      ...current.recentCommandIds.where((id) => id != commandId),
    ].take(12).toList();
    final next = current.copyWith(recentCommandIds: recents);
    await save(next);
    return next;
  }

  Future<NbaTerminalState> recordQuery(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return load();
    final current = await load();
    final recents = [
      normalized,
      ...current.recentQueries.where((value) => value.toLowerCase() != normalized.toLowerCase()),
    ].take(12).toList();
    final next = current.copyWith(recentQueries: recents);
    await save(next);
    return next;
  }

  Future<void> clearRecents() async {
    final current = await load();
    await save(current.copyWith(recentCommandIds: const [], recentQueries: const []));
  }
}
