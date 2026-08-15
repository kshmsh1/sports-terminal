import 'nba_player_career_engine.dart';

enum NbaPlayerCareerMetric {
  pointsPerGame('PPG'),
  reboundsPerGame('RPG'),
  assistsPerGame('APG'),
  stealsPerGame('SPG'),
  blocksPerGame('BPG'),
  turnoversPerGame('TPG'),
  trueShootingPct('TS%'),
  playerEfficiencyRating('PER'),
  winShares('WS'),
  boxPlusMinus('BPM'),
  valueOverReplacement('VORP');

  const NbaPlayerCareerMetric(this.label);
  final String label;
}

class NbaPlayerCareerMetricPoint {
  const NbaPlayerCareerMetricPoint({
    required this.seasonId,
    required this.teamLabel,
    required this.value,
    required this.rollingValue,
  });

  final String seasonId;
  final String teamLabel;
  final double? value;
  final double? rollingValue;
}

class NbaPlayerCareerDistribution {
  const NbaPlayerCareerDistribution({
    required this.observed,
    required this.missing,
    required this.mean,
    required this.median,
    required this.minimum,
    required this.maximum,
  });

  final int observed;
  final int missing;
  final double? mean;
  final double? median;
  final double? minimum;
  final double? maximum;
}

class NbaPlayerCareerAnalyticsResult {
  const NbaPlayerCareerAnalyticsResult({
    required this.metric,
    required this.points,
    required this.distribution,
    required this.peakSeason,
    required this.lowSeason,
  });

  final NbaPlayerCareerMetric metric;
  final List<NbaPlayerCareerMetricPoint> points;
  final NbaPlayerCareerDistribution distribution;
  final NbaPlayerCareerMetricPoint? peakSeason;
  final NbaPlayerCareerMetricPoint? lowSeason;

  bool get available => distribution.observed > 0;
}

/// Cross-season analytics over already-canonical Player career observations.
///
/// Missing metric values remain gaps. Rolling values require a complete window
/// of observed values; no interpolation, smoothing, or replacement values are
/// created for missing seasons.
class NbaPlayerCareerAnalyticsEngine {
  const NbaPlayerCareerAnalyticsEngine();

  NbaPlayerCareerAnalyticsResult build(
    NbaPlayerCareerSnapshot career, {
    NbaPlayerCareerMetric metric = NbaPlayerCareerMetric.pointsPerGame,
    int rollingWindow = 3,
  }) {
    final window = rollingWindow.clamp(2, 10);
    final values = <double?>[
      for (final season in career.seasons) _value(season, metric),
    ];
    final points = <NbaPlayerCareerMetricPoint>[];
    for (var index = 0; index < career.seasons.length; index++) {
      double? rolling;
      if (index + 1 >= window) {
        final sample = values.sublist(index + 1 - window, index + 1);
        if (sample.every((value) => value != null)) {
          rolling = sample.whereType<double>().reduce((a, b) => a + b) / window;
        }
      }
      points.add(
        NbaPlayerCareerMetricPoint(
          seasonId: career.seasons[index].seasonId,
          teamLabel: career.seasons[index].teamLabel,
          value: values[index],
          rollingValue: rolling,
        ),
      );
    }

    final observed = values.whereType<double>().toList()..sort();
    final distribution = NbaPlayerCareerDistribution(
      observed: observed.length,
      missing: values.length - observed.length,
      mean: observed.isEmpty
          ? null
          : observed.reduce((a, b) => a + b) / observed.length,
      median: _median(observed),
      minimum: observed.isEmpty ? null : observed.first,
      maximum: observed.isEmpty ? null : observed.last,
    );
    final observedPoints = points.where((point) => point.value != null).toList();
    observedPoints.sort((left, right) => left.value!.compareTo(right.value!));
    return NbaPlayerCareerAnalyticsResult(
      metric: metric,
      points: List.unmodifiable(points),
      distribution: distribution,
      peakSeason: observedPoints.isEmpty ? null : observedPoints.last,
      lowSeason: observedPoints.isEmpty ? null : observedPoints.first,
    );
  }

  double? _value(
    NbaPlayerCareerSeason season,
    NbaPlayerCareerMetric metric,
  ) {
    return switch (metric) {
      NbaPlayerCareerMetric.pointsPerGame => season.pointsPerGame,
      NbaPlayerCareerMetric.reboundsPerGame => season.reboundsPerGame,
      NbaPlayerCareerMetric.assistsPerGame => season.assistsPerGame,
      NbaPlayerCareerMetric.stealsPerGame => season.stealsPerGame,
      NbaPlayerCareerMetric.blocksPerGame => season.blocksPerGame,
      NbaPlayerCareerMetric.turnoversPerGame => season.turnoversPerGame,
      NbaPlayerCareerMetric.trueShootingPct =>
        season.trueShootingPct == null ? null : season.trueShootingPct! * 100,
      NbaPlayerCareerMetric.playerEfficiencyRating =>
        season.playerEfficiencyRating,
      NbaPlayerCareerMetric.winShares => season.winShares,
      NbaPlayerCareerMetric.boxPlusMinus => season.boxPlusMinus,
      NbaPlayerCareerMetric.valueOverReplacement =>
        season.valueOverReplacement,
    };
  }
}

double? _median(List<double> sorted) {
  if (sorted.isEmpty) return null;
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
}
