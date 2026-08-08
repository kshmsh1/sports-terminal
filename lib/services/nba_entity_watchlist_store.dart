import 'dart:convert';

import 'product_local_store.dart';

class NbaEntityWatchItem {
  const NbaEntityWatchItem({
    required this.kind,
    required this.key,
    required this.label,
    this.subtitle = '',
    this.season = '',
    this.league = 'NBA',
    this.seasonType = 'regular',
    this.pinnedAt,
  });

  final String kind;
  final String key;
  final String label;
  final String subtitle;
  final String season;
  final String league;
  final String seasonType;
  final DateTime? pinnedAt;

  String get signature => '$kind|$key|$season|$league|$seasonType';

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'key': key,
        'label': label,
        'subtitle': subtitle,
        'season': season,
        'league': league,
        'seasonType': seasonType,
        'pinnedAt': (pinnedAt ?? DateTime.now().toUtc()).toIso8601String(),
      };

  factory NbaEntityWatchItem.fromJson(Map<String, dynamic> json) =>
      NbaEntityWatchItem(
        kind: json['kind']?.toString() ?? '',
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
        season: json['season']?.toString() ?? '',
        league: (json['league']?.toString() ?? 'NBA').toUpperCase(),
        seasonType: json['seasonType']?.toString() ?? 'regular',
        pinnedAt: DateTime.tryParse(json['pinnedAt']?.toString() ?? ''),
      );
}

class NbaEntityWatchlistStore {
  const NbaEntityWatchlistStore({
    ProductLocalStore localStore = const ProductLocalStore(),
  }) : _store = localStore;

  static const storageKey = 'sports_terminal.nba.entity_watchlist.v1';
  final ProductLocalStore _store;

  Future<List<NbaEntityWatchItem>> load() async {
    final raw = await _store.loadString(storageKey);
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            NbaEntityWatchItem.fromJson(item.cast<String, dynamic>()),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<NbaEntityWatchItem>> toggle(NbaEntityWatchItem item) async {
    final current = await load();
    final exists = current.any((candidate) => candidate.signature == item.signature);
    final next = exists
        ? [
            for (final candidate in current)
              if (candidate.signature != item.signature) candidate,
          ]
        : [
            NbaEntityWatchItem(
              kind: item.kind,
              key: item.key,
              label: item.label,
              subtitle: item.subtitle,
              season: item.season,
              league: item.league,
              seasonType: item.seasonType,
              pinnedAt: DateTime.now().toUtc(),
            ),
            ...current,
          ];
    await _save(next);
    return next;
  }

  Future<List<NbaEntityWatchItem>> remove(String signature) async {
    final current = await load();
    final next = [
      for (final item in current)
        if (item.signature != signature) item,
    ];
    await _save(next);
    return next;
  }

  Future<void> clear() => _store.remove(storageKey);

  Future<bool> contains(String signature) async =>
      (await load()).any((item) => item.signature == signature);

  Future<void> _save(List<NbaEntityWatchItem> items) => _store.saveString(
        storageKey,
        jsonEncode([for (final item in items.take(100)) item.toJson()]),
      );
}
