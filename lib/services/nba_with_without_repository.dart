import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class NbaWithWithoutSplit {
  const NbaWithWithoutSplit({
    required this.team,
    required this.playerId,
    required this.teammateId,
    required this.minutesWith,
    required this.minutesWithout,
    required this.withStats,
    required this.withoutStats,
  });

  final String team;
  final String playerId;
  final String teammateId;
  final double? minutesWith;
  final double? minutesWithout;
  final Map<String, double?> withStats;
  final Map<String, double?> withoutStats;

  factory NbaWithWithoutSplit.fromMap(Map<String, dynamic> map) {
    return NbaWithWithoutSplit(
      team: _text(map['team']),
      playerId: _text(map['player_id']),
      teammateId: _text(map['teammate_id']),
      minutesWith: _number(map['minutes_with']),
      minutesWithout: _number(map['minutes_without']),
      withStats: _stats(map['with']),
      withoutStats: _stats(map['without']),
    );
  }
}

class NbaWithWithoutSnapshot {
  const NbaWithWithoutSnapshot({
    required this.available,
    required this.source,
    required this.rows,
    required this.message,
  });

  final bool available;
  final String source;
  final List<NbaWithWithoutSplit> rows;
  final String message;

  NbaWithWithoutSplit? find({
    required String team,
    required String playerId,
    required String teammateId,
  }) {
    for (final row in rows) {
      if (row.team == team &&
          row.playerId == playerId &&
          row.teammateId == teammateId) {
        return row;
      }
    }
    return null;
  }
}

/// Reads an optional same-origin static lineup split generated from play-by-play
/// or lineup stint data. Missing files are a supported state: the product UI
/// remains usable while explicitly showing that with/without values are not yet
/// source-backed for the selected season.
class NbaWithWithoutRepository {
  NbaWithWithoutRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, NbaWithWithoutSnapshot> _cache = {};

  Future<NbaWithWithoutSnapshot> load(
    String season, {
    String seasonType = 'regular',
  }) async {
    final segment = seasonType.toLowerCase().contains('play')
        ? 'playoffs'
        : 'regular';
    final key = '$season/$segment';
    final cached = _cache[key];
    if (cached != null) return cached;
    final uri = Uri.base.resolve(
      'data/nba_static/lineups/$season/$segment/with_without.json',
    );
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 404) {
        return _cache[key] = const NbaWithWithoutSnapshot(
          available: false,
          source: '',
          rows: [],
          message:
              'Lineup stint / play-by-play splits have not been materialized for this season yet.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _cache[key] = NbaWithWithoutSnapshot(
          available: false,
          source: '',
          rows: const [],
          message: 'With/without dataset is unavailable (${response.statusCode}).',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return _cache[key] = const NbaWithWithoutSnapshot(
          available: false,
          source: '',
          rows: [],
          message: 'With/without dataset has an invalid shape.',
        );
      }
      final map = decoded.map((field, value) => MapEntry(field.toString(), value));
      final rows = <NbaWithWithoutSplit>[];
      final rawRows = map['rows'];
      if (rawRows is List) {
        for (final item in rawRows) {
          if (item is! Map) continue;
          rows.add(
            NbaWithWithoutSplit.fromMap(
              item.map((field, value) => MapEntry(field.toString(), value)),
            ),
          );
        }
      }
      return _cache[key] = NbaWithWithoutSnapshot(
        available: rows.isNotEmpty,
        source: _text(map['source']),
        rows: rows,
        message: rows.isEmpty
            ? 'The lineup split file is present but contains no player-pair rows.'
            : '',
      );
    } on TimeoutException {
      return _cache[key] = const NbaWithWithoutSnapshot(
        available: false,
        source: '',
        rows: [],
        message: 'With/without static file timed out.',
      );
    } catch (error) {
      return _cache[key] = NbaWithWithoutSnapshot(
        available: false,
        source: '',
        rows: const [],
        message: 'With/without static file could not be read: $error',
      );
    }
  }
}

Map<String, double?> _stats(Object? value) {
  if (value is! Map) return const {};
  return value.map(
    (key, item) => MapEntry(key.toString(), _number(item)),
  );
}

String _text(Object? value) => value?.toString().trim() ?? '';

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
