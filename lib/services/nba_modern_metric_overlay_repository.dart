

import 'nba_stats_metric_catalog.dart';
import 'nba_stats_workstation_engine.dart';
import 'product_local_store.dart';

class NbaModernMetricOverlay {
  const NbaModernMetricOverlay({
    required this.season,
    required this.seasonType,
    required this.byPlayerId,
    required this.byCanonicalPlayerKey,
    required this.byPlayerName,
    required this.metricKeys,
  });

  final String season;
  final String seasonType;
  final Map<String, Map<String, double>> byPlayerId;
  final Map<String, Map<String, double>> byCanonicalPlayerKey;
  final Map<String, Map<String, double>> byPlayerName;
  final Set<String> metricKeys;

  static const empty = NbaModernMetricOverlay(
    season: '',
    seasonType: 'regular',
    byPlayerId: {},
    byCanonicalPlayerKey: {},
    byPlayerName: {},
    metricKeys: {},
  );

  bool get isEmpty => metricKeys.isEmpty;

  NbaStatsRow enrich(NbaStatsRow row) {
    final metrics = byPlayerId[row.playerId] ??
        byCanonicalPlayerKey[row.playerId] ??
        byPlayerName[_normalizeName(row.player)];
    if (metrics == null || metrics.isEmpty) return row;
    final nextRaw = <String, dynamic>{...row.raw};
    final nextValues = <String, double?>{...row.values};
    for (final entry in metrics.entries) {
      nextRaw[entry.key] = entry.value;
      final definition = nbaTerminalMetricByKey[entry.key];
      if (definition != null) {
        for (final alias in definition.rawAliases) {
          nextRaw[alias] = entry.value;
        }
        final engineKey = definition.engineKey;
        if (engineKey != null && engineKey.isNotEmpty) {
          nextValues[engineKey] = entry.value;
        }
      }
    }
    return NbaStatsRow(
      playerId: row.playerId,
      player: row.player,
      team: row.team,
      position: row.position,
      values: nextValues,
      percentiles: row.percentiles,
      raw: nextRaw,
      possessionsEstimated: row.possessionsEstimated,
    );
  }
}

class NbaModernMetricOverlayRepository {
  const NbaModernMetricOverlayRepository({
    ProductLocalStore store = const ProductLocalStore(),
  });

  Future<NbaModernMetricOverlay> load({
    required String season,
    required String seasonType,
  }) async {
    return NbaModernMetricOverlay.empty;
  }

  Future<Map<String, dynamic>> status() async => const {
    'ready': false,
    'mode': 'static-only',
  };
}


String _normalizeName(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
