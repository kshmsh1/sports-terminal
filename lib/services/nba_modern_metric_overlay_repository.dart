import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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
    for (final entry in metrics.entries) {
      nextRaw[entry.key] = entry.value;
      final definition = nbaTerminalMetricByKey[entry.key];
      if (definition != null) {
        for (final alias in definition.rawAliases) {
          nextRaw[alias] = entry.value;
        }
      }
    }
    return NbaStatsRow(
      playerId: row.playerId,
      player: row.player,
      team: row.team,
      position: row.position,
      values: row.values,
      percentiles: row.percentiles,
      raw: nextRaw,
      possessionsEstimated: row.possessionsEstimated,
    );
  }
}

class NbaModernMetricOverlayRepository {
  const NbaModernMetricOverlayRepository({
    ProductLocalStore store = const ProductLocalStore(),
  }) : _store = store;

  final ProductLocalStore _store;

  Future<NbaModernMetricOverlay> load({
    required String season,
    required String seasonType,
  }) async {
    final cleanSeason = season.trim();
    if (cleanSeason.isEmpty) return NbaModernMetricOverlay.empty;
    final baseUrl = await _store.loadString(
      ProductLocalStore.backendBaseUrlKey,
      fallback: 'http://127.0.0.1:8000',
    );
    final normalizedBase = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalizedBase.isEmpty) return NbaModernMetricOverlay.empty;
    final base = Uri.parse(normalizedBase);
    final uri = base.replace(
      path:
          '${base.path.replaceFirst(RegExp(r'/+$'), '')}/v2/nba/modern-metrics/season/${Uri.encodeComponent(cleanSeason)}',
      queryParameters: {'season_type': seasonType},
    );
    final token = await _store.loadString(ProductLocalStore.launchAuthTokenKey);
    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 404 || response.statusCode == 503) {
        return NbaModernMetricOverlay.empty;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return NbaModernMetricOverlay.empty;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return NbaModernMetricOverlay.empty;
      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final idMap = <String, Map<String, double>>{};
      final canonicalMap = <String, Map<String, double>>{};
      final nameMap = <String, Map<String, double>>{};
      final metricKeys = <String>{};
      final rows = payload['rows'];
      if (rows is List) {
        for (final raw in rows) {
          if (raw is! Map) continue;
          final row = raw.map((key, value) => MapEntry(key.toString(), value));
          final metrics = <String, double>{};
          final rawMetrics = row['metrics'];
          if (rawMetrics is Map) {
            for (final entry in rawMetrics.entries) {
              final value = _number(entry.value);
              if (value == null) continue;
              final key = entry.key.toString();
              metrics[key] = value;
              metricKeys.add(key);
            }
          }
          if (metrics.isEmpty) continue;
          final playerId = row['player_id']?.toString() ?? '';
          final canonicalKey = row['canonical_player_key']?.toString() ?? '';
          final playerName = row['player_name']?.toString() ?? '';
          if (playerId.isNotEmpty) idMap[playerId] = metrics;
          if (canonicalKey.isNotEmpty) canonicalMap[canonicalKey] = metrics;
          if (playerName.isNotEmpty) nameMap[_normalizeName(playerName)] = metrics;
        }
      }
      return NbaModernMetricOverlay(
        season: payload['season']?.toString() ?? cleanSeason,
        seasonType: payload['season_type']?.toString() ?? seasonType,
        byPlayerId: idMap,
        byCanonicalPlayerKey: canonicalMap,
        byPlayerName: nameMap,
        metricKeys: metricKeys,
      );
    } on TimeoutException {
      return NbaModernMetricOverlay.empty;
    } catch (_) {
      return NbaModernMetricOverlay.empty;
    }
  }

  Future<Map<String, dynamic>> status() async {
    final baseUrl = await _store.loadString(
      ProductLocalStore.backendBaseUrlKey,
      fallback: 'http://127.0.0.1:8000',
    );
    final normalizedBase = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalizedBase.isEmpty) return const {'ready': false};
    final base = Uri.parse(normalizedBase);
    final uri = base.replace(
      path:
          '${base.path.replaceFirst(RegExp(r'/+$'), '')}/v2/nba/modern-metrics/status',
    );
    try {
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 4));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const {'ready': false};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      // A missing local overlay must never make core Stats unavailable.
    }
    return const {'ready': false};
  }
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString());
}

String _normalizeName(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
