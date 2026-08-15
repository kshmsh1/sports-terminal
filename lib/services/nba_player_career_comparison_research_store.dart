import 'dart:convert';

import 'nba_player_career_analytics_engine.dart';
import 'nba_player_career_comparison_engine.dart';
import 'product_local_store.dart';

class NbaPlayerCareerComparisonResearchCheckpoint {
  const NbaPlayerCareerComparisonResearchCheckpoint({
    required this.leftPlayerKey,
    required this.leftPlayerName,
    required this.rightPlayerKey,
    required this.rightPlayerName,
    required this.league,
    required this.seasonType,
    required this.alignment,
    required this.metric,
    required this.sharedOnly,
    this.presetId = '',
    this.activatedAt,
  });

  final String leftPlayerKey;
  final String leftPlayerName;
  final String rightPlayerKey;
  final String rightPlayerName;
  final String league;
  final String seasonType;
  final NbaPlayerCareerComparisonAlignment alignment;
  final NbaPlayerCareerMetric metric;
  final bool sharedOnly;
  final String presetId;
  final DateTime? activatedAt;

  bool get available => leftPlayerKey.isNotEmpty && rightPlayerKey.isNotEmpty;

  String get label => available
      ? '$leftPlayerName vs $rightPlayerName · ${alignment.label}'
      : 'NO ACTIVE CAREER COMPARISON';

  Map<String, dynamic> toJson() => {
        'leftPlayerKey': leftPlayerKey,
        'leftPlayerName': leftPlayerName,
        'rightPlayerKey': rightPlayerKey,
        'rightPlayerName': rightPlayerName,
        'league': league,
        'seasonType': seasonType,
        'alignment': alignment.name,
        'metric': metric.name,
        'sharedOnly': sharedOnly,
        'presetId': presetId,
        'activatedAt':
            (activatedAt ?? DateTime.now().toUtc()).toIso8601String(),
      };

  factory NbaPlayerCareerComparisonResearchCheckpoint.fromJson(
    Map<String, dynamic> json,
  ) {
    final alignmentName = json['alignment']?.toString() ?? '';
    final metricName = json['metric']?.toString() ?? '';
    final alignment = NbaPlayerCareerComparisonAlignment.values.firstWhere(
      (value) => value.name == alignmentName,
      orElse: () => NbaPlayerCareerComparisonAlignment.calendarSeason,
    );
    final metric = NbaPlayerCareerMetric.values.firstWhere(
      (value) => value.name == metricName,
      orElse: () => NbaPlayerCareerMetric.pointsPerGame,
    );
    return NbaPlayerCareerComparisonResearchCheckpoint(
      leftPlayerKey: json['leftPlayerKey']?.toString() ?? '',
      leftPlayerName: json['leftPlayerName']?.toString() ?? '',
      rightPlayerKey: json['rightPlayerKey']?.toString() ?? '',
      rightPlayerName: json['rightPlayerName']?.toString() ?? '',
      league: (json['league']?.toString() ?? 'NBA').toUpperCase(),
      seasonType: json['seasonType']?.toString() ?? 'regular',
      alignment: alignment,
      metric: metric,
      sharedOnly: json['sharedOnly'] == true,
      presetId: json['presetId']?.toString() ?? '',
      activatedAt: DateTime.tryParse(json['activatedAt']?.toString() ?? ''),
    );
  }
}

class NbaPlayerCareerComparisonResearchStore {
  const NbaPlayerCareerComparisonResearchStore({
    ProductLocalStore localStore = const ProductLocalStore(),
  }) : _store = localStore;

  static const storageKey =
      'sports_terminal.nba.player_career_comparison_research.v1';
  final ProductLocalStore _store;

  Future<NbaPlayerCareerComparisonResearchCheckpoint?> load() async {
    final raw = await _store.loadString(storageKey);
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final checkpoint =
            NbaPlayerCareerComparisonResearchCheckpoint.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
        return checkpoint.available ? checkpoint : null;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<NbaPlayerCareerComparisonResearchCheckpoint> activate(
    NbaPlayerCareerComparisonResearchCheckpoint checkpoint,
  ) async {
    final stamped = NbaPlayerCareerComparisonResearchCheckpoint(
      leftPlayerKey: checkpoint.leftPlayerKey.trim(),
      leftPlayerName: checkpoint.leftPlayerName.trim(),
      rightPlayerKey: checkpoint.rightPlayerKey.trim(),
      rightPlayerName: checkpoint.rightPlayerName.trim(),
      league: checkpoint.league.trim().isEmpty
          ? 'NBA'
          : checkpoint.league.trim().toUpperCase(),
      seasonType: checkpoint.seasonType.trim().isEmpty
          ? 'regular'
          : checkpoint.seasonType.trim(),
      alignment: checkpoint.alignment,
      metric: checkpoint.metric,
      sharedOnly: checkpoint.sharedOnly,
      presetId: checkpoint.presetId,
      activatedAt: DateTime.now().toUtc(),
    );
    if (!stamped.available) {
      throw ArgumentError('Both canonical Player keys are required.');
    }
    await _store.saveString(storageKey, jsonEncode(stamped.toJson()));
    return stamped;
  }

  Future<void> clear() => _store.remove(storageKey);
}
