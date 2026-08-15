import 'dart:math' as math;

import 'nba_player_career_analytics_engine.dart';
import 'nba_player_career_comparison_scope_engine.dart';
import 'nba_player_career_engine.dart';

class NbaPlayerCareerMetricDistribution {
  const NbaPlayerCareerMetricDistribution({
    required this.observed,
    required this.missing,
    required this.mean,
    required this.median,
    required this.minimum,
    required this.maximum,
    required this.standardDeviation,
    required this.lowerQuartile,
    required this.upperQuartile,
  });

  final int observed;
  final int missing;
  final double? mean;
  final double? median;
  final double? minimum;
  final double? maximum;
  final double? standardDeviation;
  final double? lowerQuartile;
  final double? upperQuartile;
}

class NbaPlayerCareerComparisonDistributionResult {
  const NbaPlayerCareerComparisonDistributionResult({
    required this.metric,
    required this.left,
    required this.right,
  });

  final NbaPlayerCareerMetric metric;
  final NbaPlayerCareerMetricDistribution left;
  final NbaPlayerCareerMetricDistribution right;

  double? get meanDelta => left.mean == null || right.mean == null
      ? null
      : left.mean! - right.mean!;
  double? get medianDelta => left.median == null || right.median == null
      ? null
      : left.median! - right.median!;
}

/// Compares the observed season-value distributions inside one explicit scope.
/// This is descriptive only: it does not normalize for era, pace, age, role,
/// rules, competition, games played, or possession environment.
class NbaPlayerCareerComparisonDistributionEngine {
  const NbaPlayerCareerComparisonDistributionEngine();

  NbaPlayerCareerComparisonDistributionResult build(
    NbaPlayerCareerComparisonScopeResult scope, {
    NbaPlayerCareerMetric metric = NbaPlayerCareerMetric.pointsPerGame,
  }) {
    final left = <double?>[];
    final right = <double?>[];
    for (final pair in scope.pairs) {
      left.add(_value(pair.left, metric));
      right.add(_value(pair.right, metric));
    }
    return NbaPlayerCareerComparisonDistributionResult(
      metric: metric,
      left: _distribution(left),
      right: _distribution(right),
    );
  }

  NbaPlayerCareerMetricDistribution _distribution(List<double?> values) {
    final observed = values.whereType<double>().toList()..sort();
    if (observed.isEmpty) {
      return NbaPlayerCareerMetricDistribution(
        observed: 0,
        missing: values.length,
        mean: null,
        median: null,
        minimum: null,
        maximum: null,
        standardDeviation: null,
        lowerQuartile: null,
        upperQuartile: null,
      );
    }
    final mean = observed.reduce((a, b) => a + b) / observed.length;
    final variance = observed
            .map((value) => math.pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        observed.length;
    return NbaPlayerCareerMetricDistribution(
      observed: observed.length,
      missing: values.length - observed.length,
      mean: mean,
      median: _median(observed),
      minimum: observed.first,
      maximum: observed.last,
      standardDeviation: math.sqrt(variance),
      lowerQuartile: _quartile(observed, lower: true),
      upperQuartile: _quartile(observed, lower: false),
    );
  }

  double? _quartile(List<double> sorted, {required bool lower}) {
    if (sorted.length < 2) return sorted.isEmpty ? null : sorted.single;
    final middle = sorted.length ~/ 2;
    final half = lower
        ? sorted.sublist(0, middle)
        : sorted.sublist(sorted.length.isOdd ? middle + 1 : middle);
    return half.isEmpty ? sorted[middle] : _median(half);
  }

  double? _value(NbaPlayerCareerSeason? season, NbaPlayerCareerMetric metric) {
    if (season == null) return null;
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
      NbaPlayerCareerMetric.valueOverReplacement => season.valueOverReplacement,
    };
  }
}

double _median(List<double> sorted) {
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
}
