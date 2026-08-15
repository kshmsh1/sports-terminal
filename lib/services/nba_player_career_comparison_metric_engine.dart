import 'nba_player_career_analytics_engine.dart';
import 'nba_player_career_comparison_engine.dart';
import 'nba_player_career_engine.dart';

class NbaPlayerCareerComparisonMetricPoint {
  const NbaPlayerCareerComparisonMetricPoint({
    required this.axisLabel,
    required this.leftSeasonId,
    required this.rightSeasonId,
    required this.leftValue,
    required this.rightValue,
    required this.delta,
  });

  final String axisLabel;
  final String leftSeasonId;
  final String rightSeasonId;
  final double? leftValue;
  final double? rightValue;
  final double? delta;

  bool get paired => leftValue != null && rightValue != null;
}

class NbaPlayerCareerComparisonMetricResult {
  const NbaPlayerCareerComparisonMetricResult({
    required this.metric,
    required this.points,
    required this.paired,
    required this.leftObserved,
    required this.rightObserved,
    required this.leftAhead,
    required this.rightAhead,
    required this.tied,
    required this.meanDelta,
  });

  final NbaPlayerCareerMetric metric;
  final List<NbaPlayerCareerComparisonMetricPoint> points;
  final int paired;
  final int leftObserved;
  final int rightObserved;
  final int leftAhead;
  final int rightAhead;
  final int tied;
  final double? meanDelta;

  bool get comparable => paired > 0;
}

/// Metric comparison over an already-aligned canonical career comparison.
///
/// The engine reports direct observed differences only. It does not pace-, era-,
/// age-, role-, minutes-, possession-, or league-normalize values.
class NbaPlayerCareerComparisonMetricEngine {
  const NbaPlayerCareerComparisonMetricEngine();

  NbaPlayerCareerComparisonMetricResult build(
    NbaPlayerCareerComparisonSnapshot comparison, {
    NbaPlayerCareerMetric metric = NbaPlayerCareerMetric.pointsPerGame,
  }) {
    final points = <NbaPlayerCareerComparisonMetricPoint>[];
    var paired = 0;
    var leftObserved = 0;
    var rightObserved = 0;
    var leftAhead = 0;
    var rightAhead = 0;
    var tied = 0;
    var deltaTotal = 0.0;

    for (final pair in comparison.pairs) {
      final left = _value(pair.left, metric);
      final right = _value(pair.right, metric);
      if (left != null) leftObserved++;
      if (right != null) rightObserved++;
      double? delta;
      if (left != null && right != null) {
        paired++;
        delta = left - right;
        deltaTotal += delta;
        if (delta.abs() < 0.0000001) {
          tied++;
        } else if (delta > 0) {
          leftAhead++;
        } else {
          rightAhead++;
        }
      }
      points.add(
        NbaPlayerCareerComparisonMetricPoint(
          axisLabel: pair.axisLabel,
          leftSeasonId: pair.left?.seasonId ?? '',
          rightSeasonId: pair.right?.seasonId ?? '',
          leftValue: left,
          rightValue: right,
          delta: delta,
        ),
      );
    }

    return NbaPlayerCareerComparisonMetricResult(
      metric: metric,
      points: List.unmodifiable(points),
      paired: paired,
      leftObserved: leftObserved,
      rightObserved: rightObserved,
      leftAhead: leftAhead,
      rightAhead: rightAhead,
      tied: tied,
      meanDelta: paired == 0 ? null : deltaTotal / paired,
    );
  }

  double? _value(
    NbaPlayerCareerSeason? season,
    NbaPlayerCareerMetric metric,
  ) {
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
