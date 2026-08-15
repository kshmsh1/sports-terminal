import 'dart:convert';

import 'nba_player_career_analytics_engine.dart';
import 'nba_player_career_comparison_engine.dart';
import 'product_local_store.dart';

class NbaPlayerCareerComparisonStateItem {
  const NbaPlayerCareerComparisonStateItem({
    required this.leftPlayerKey,
    required this.leftPlayerName,
    required this.rightPlayerKey,
    required this.rightPlayerName,
    required this.seasonType,
    required this.alignment,
    required this.metric,
    required this.sharedOnly,
    this.presetId = '',
    this.savedAt,
  });

  final String leftPlayerKey;
  final String leftPlayerName;
  final String rightPlayerKey;
  final String rightPlayerName;
  final String seasonType;
  final NbaPlayerCareerComparisonAlignment alignment;
  final NbaPlayerCareerMetric metric;
  final bool sharedOnly;
  final String presetId;
  final DateTime? savedAt;

  String get signature =>
      '$leftPlayerKey|$rightPlayerKey|$seasonType|${alignment.name}|${metric.name}|$sharedOnly|$presetId';

  Map<String, dynamic> toJson() => {
        'leftPlayerKey': leftPlayerKey,
        'leftPlayerName': leftPlayerName,
        'rightPlayerKey': rightPlayerKey,
        'rightPlayerName': rightPlayerName,
        'seasonType': seasonType,
        'alignment': alignment.name,
        'metric': metric.name,
        'sharedOnly': sharedOnly,
        'presetId': presetId,
        'savedAt': (savedAt ?? DateTime.now().toUtc()).toIso8601String(),
      };

  factory NbaPlayerCareerComparisonStateItem.fromJson(
    Map<String, dynamic> json,
  ) {
    T enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
      for (final value in values) {
        if (value.name == name) return value;
      }
      return fallback;
    }

    return NbaPlayerCareerComparisonStateItem(
      leftPlayerKey: json['leftPlayerKey']?.toString() ?? '',
      leftPlayerName: json['leftPlayerName']?.toString() ?? '',
      rightPlayerKey: json['rightPlayerKey']?.toString() ?? '',
      rightPlayerName: json['rightPlayerName']?.toString() ?? '',
      seasonType: json['seasonType']?.toString() ?? 'regular',
      alignment: enumByName(
        NbaPlayerCareerComparisonAlignment.values,
        json['alignment']?.toString(),
        NbaPlayerCareerComparisonAlignment.calendarSeason,
      ),
      metric: enumByName(
        NbaPlayerCareerMetric.values,
        json['metric']?.toString(),
        NbaPlayerCareerMetric.pointsPerGame,
      ),
      sharedOnly: json['sharedOnly'] == true,
      presetId: json['presetId']?.toString() ?? '',
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? ''),
    );
  }
}

class NbaPlayerCareerComparisonState {
  const NbaPlayerCareerComparisonState({
    this.recents = const [],
    this.saved = const [],
  });

  final List<NbaPlayerCareerComparisonStateItem> recents;
  final List<NbaPlayerCareerComparisonStateItem> saved;

  Map<String, dynamic> toJson() => {
        'recents': [for (final item in recents) item.toJson()],
        'saved': [for (final item in saved) item.toJson()],
      };

  factory NbaPlayerCareerComparisonState.fromJson(Map<String, dynamic> json) {
    List<NbaPlayerCareerComparisonStateItem> decode(Object? raw) {
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map)
            NbaPlayerCareerComparisonStateItem.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
      ];
    }

    return NbaPlayerCareerComparisonState(
      recents: decode(json['recents']),
      saved: decode(json['saved']),
    );
  }
}

class NbaPlayerCareerComparisonStateStore {
  const NbaPlayerCareerComparisonStateStore({
    ProductLocalStore localStore = const ProductLocalStore(),
  }) : _store = localStore;

  static const storageKey = 'sports_terminal.nba.player_career_comparisons.v1';
  final ProductLocalStore _store;

  Future<NbaPlayerCareerComparisonState> load() async {
    final raw = await _store.loadString(storageKey);
    if (raw.isEmpty) return const NbaPlayerCareerComparisonState();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return NbaPlayerCareerComparisonState.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      return const NbaPlayerCareerComparisonState();
    }
    return const NbaPlayerCareerComparisonState();
  }

  Future<NbaPlayerCareerComparisonState> record(
    NbaPlayerCareerComparisonStateItem item,
  ) async {
    final current = await load();
    final stamped = _stamp(item);
    final recents = [
      stamped,
      ...current.recents.where((candidate) => candidate.signature != item.signature),
    ].take(20).toList();
    final next = NbaPlayerCareerComparisonState(
      recents: recents,
      saved: current.saved,
    );
    await _save(next);
    return next;
  }

  Future<NbaPlayerCareerComparisonState> toggleSaved(
    NbaPlayerCareerComparisonStateItem item,
  ) async {
    final current = await load();
    final exists = current.saved.any((candidate) => candidate.signature == item.signature);
    final saved = exists
        ? [
            for (final candidate in current.saved)
              if (candidate.signature != item.signature) candidate,
          ]
        : [
            _stamp(item),
            ...current.saved,
          ].take(50).toList();
    final next = NbaPlayerCareerComparisonState(
      recents: current.recents,
      saved: saved,
    );
    await _save(next);
    return next;
  }

  Future<void> clearRecents() async {
    final current = await load();
    await _save(NbaPlayerCareerComparisonState(saved: current.saved));
  }

  Future<bool> isSaved(String signature) async =>
      (await load()).saved.any((item) => item.signature == signature);

  NbaPlayerCareerComparisonStateItem _stamp(
    NbaPlayerCareerComparisonStateItem item,
  ) =>
      NbaPlayerCareerComparisonStateItem(
        leftPlayerKey: item.leftPlayerKey,
        leftPlayerName: item.leftPlayerName,
        rightPlayerKey: item.rightPlayerKey,
        rightPlayerName: item.rightPlayerName,
        seasonType: item.seasonType,
        alignment: item.alignment,
        metric: item.metric,
        sharedOnly: item.sharedOnly,
        presetId: item.presetId,
        savedAt: DateTime.now().toUtc(),
      );

  Future<void> _save(NbaPlayerCareerComparisonState state) =>
      _store.saveString(storageKey, jsonEncode(state.toJson()));
}
