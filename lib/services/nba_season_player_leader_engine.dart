import 'nba_stats_workstation_engine.dart';
import 'nba_terminal_seed_repository.dart';

enum NbaSeasonLeaderMetric {
  points('pts', 'PPG'),
  rebounds('reb', 'RPG'),
  assists('ast', 'APG'),
  steals('stl', 'SPG'),
  blocks('blk', 'BPG'),
  trueShooting('ts_pct', 'TS%'),
  plusMinus('plus_minus', '+/-');

  const NbaSeasonLeaderMetric(this.key, this.label);
  final String key;
  final String label;
}

class NbaSeasonPlayerLeaderEngine {
  const NbaSeasonPlayerLeaderEngine();

  NbaSeasonPlayerLeaderResult build(
    NbaTerminalSeedSnapshot seed, {
    required String seasonId,
    String seasonType = 'Regular Season',
    NbaSeasonLeaderMetric metric = NbaSeasonLeaderMetric.points,
    int limit = 10,
    double minimumGames = 0,
  }) {
    final normalizedSeason = _normalize(seasonId);
    if (normalizedSeason.isEmpty) throw ArgumentError('seasonId is required.');
    final type = _seasonType(seasonType);
    final rows = const NbaStatsWorkstationEngine().buildRows(
      seed,
      basis: NbaStatsBasis.perGame,
      seasonType: type,
    );
    final activeSeason = _normalize(seed.supportedSeason);
    final eligible = rows.where((row) {
      final rawSeason = _rawSeasonId(row.raw);
      if (rawSeason.isNotEmpty) return _normalize(rawSeason) == normalizedSeason;
      return activeSeason == normalizedSeason;
    }).where((row) {
      final games = row.value('gp') ?? 0;
      return games >= minimumGames &&
          row.value(metric.key) != null &&
          _hasMetricEvidence(row.raw, metric);
    }).toList()
      ..sort((left, right) {
        final l = left.value(metric.key)!;
        final r = right.value(metric.key)!;
        final metricDefinition = const NbaStatsWorkstationEngine().metric(metric.key);
        final compared = r.compareTo(l);
        return metricDefinition.higherIsBetter ? compared : -compared;
      });

    final boundedLimit = limit.clamp(1, 100);
    final leaders = <NbaSeasonPlayerLeader>[];
    for (var index = 0; index < eligible.take(boundedLimit).length; index++) {
      final row = eligible[index];
      leaders.add(
        NbaSeasonPlayerLeader(
          rank: index + 1,
          playerId: row.playerId,
          playerName: row.player,
          teamLabel: row.team,
          position: row.position,
          games: row.value('gp') ?? 0,
          metric: metric,
          value: row.value(metric.key)!,
        ),
      );
    }

    return NbaSeasonPlayerLeaderResult(
      seasonId: seasonId,
      seasonType: seasonType,
      metric: metric,
      leaders: List.unmodifiable(leaders),
      eligiblePlayers: eligible.length,
      datasetStatus: seed.datasetStatus,
      validationStatus: seed.validationStatus,
      historicalContext: seed.isHistorical,
      usedFallbackDataset: seed.usedFallback,
    );
  }
}

class NbaSeasonPlayerLeaderResult {
  const NbaSeasonPlayerLeaderResult({
    required this.seasonId,
    required this.seasonType,
    required this.metric,
    required this.leaders,
    required this.eligiblePlayers,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String seasonId;
  final String seasonType;
  final NbaSeasonLeaderMetric metric;
  final List<NbaSeasonPlayerLeader> leaders;
  final int eligiblePlayers;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  bool get hasLeaders => leaders.isNotEmpty;
}

class NbaSeasonPlayerLeader {
  const NbaSeasonPlayerLeader({
    required this.rank,
    required this.playerId,
    required this.playerName,
    required this.teamLabel,
    required this.position,
    required this.games,
    required this.metric,
    required this.value,
  });

  final int rank;
  final String playerId;
  final String playerName;
  final String teamLabel;
  final String position;
  final double games;
  final NbaSeasonLeaderMetric metric;
  final double value;
}

NbaStatsSeasonType _seasonType(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.contains('playoff') || normalized.contains('postseason')) {
    return NbaStatsSeasonType.playoffs;
  }
  if (normalized == 'all' || normalized.contains('combined')) {
    return NbaStatsSeasonType.combined;
  }
  return NbaStatsSeasonType.regular;
}

String _rawSeasonId(Map<String, dynamic> raw) {
  for (final key in const ['season_id', 'seasonId', 'season']) {
    final value = raw[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

bool _hasMetricEvidence(
  Map<String, dynamic> raw,
  NbaSeasonLeaderMetric metric,
) {
  final keys = switch (metric) {
    NbaSeasonLeaderMetric.points => const [
        'points',
        'pts',
        'points_per_game',
        'ppg',
      ],
    NbaSeasonLeaderMetric.rebounds => const [
        'rebounds',
        'trb',
        'reb',
        'rebounds_per_game',
        'rpg',
      ],
    NbaSeasonLeaderMetric.assists => const [
        'assists',
        'ast',
        'assists_per_game',
        'apg',
      ],
    NbaSeasonLeaderMetric.steals => const [
        'steals',
        'stl',
        'steals_per_game',
        'spg',
      ],
    NbaSeasonLeaderMetric.blocks => const [
        'blocks',
        'blk',
        'blocks_per_game',
        'bpg',
      ],
    NbaSeasonLeaderMetric.plusMinus => const [
        'plus_minus',
        'plus_minus_per_game',
      ],
    NbaSeasonLeaderMetric.trueShooting => const <String>[],
  };
  if (metric == NbaSeasonLeaderMetric.trueShooting) {
    return _hasAny(raw, const ['field_goal_attempts', 'fga']) ||
        _hasAny(raw, const ['free_throw_attempts', 'fta']);
  }
  return _hasAny(raw, keys);
}

bool _hasAny(Map<String, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    final value = raw[key];
    if (value != null && value.toString().trim().isNotEmpty) return true;
  }
  return false;
}

String _normalize(String value) => value.trim().toUpperCase();
