import 'nba_player_career_analytics_engine.dart';
import 'nba_player_career_comparison_engine.dart';
import 'nba_player_career_comparison_scope_engine.dart';
import 'nba_player_career_engine.dart';

class NbaPlayerCareerComparisonMatrixCell {
  const NbaPlayerCareerComparisonMatrixCell({
    required this.metric,
    required this.leftValue,
    required this.rightValue,
  });

  final NbaPlayerCareerMetric metric;
  final double? leftValue;
  final double? rightValue;

  bool get paired => leftValue != null && rightValue != null;
  double? get delta => paired ? leftValue! - rightValue! : null;
}

class NbaPlayerCareerComparisonMatrixRow {
  const NbaPlayerCareerComparisonMatrixRow({
    required this.axisLabel,
    required this.leftSeasonId,
    required this.rightSeasonId,
    required this.cells,
  });

  final String axisLabel;
  final String leftSeasonId;
  final String rightSeasonId;
  final List<NbaPlayerCareerComparisonMatrixCell> cells;
}

class NbaPlayerCareerComparisonMatrixMetricSummary {
  const NbaPlayerCareerComparisonMatrixMetricSummary({
    required this.metric,
    required this.pairedRows,
    required this.leftAhead,
    required this.rightAhead,
    required this.tied,
    required this.meanDelta,
  });

  final NbaPlayerCareerMetric metric;
  final int pairedRows;
  final int leftAhead;
  final int rightAhead;
  final int tied;
  final double? meanDelta;
}

class NbaPlayerCareerComparisonMatrixResult {
  const NbaPlayerCareerComparisonMatrixResult({
    required this.scope,
    required this.metrics,
    required this.rows,
    required this.summaries,
  });

  final NbaPlayerCareerComparisonScopeResult scope;
  final List<NbaPlayerCareerMetric> metrics;
  final List<NbaPlayerCareerComparisonMatrixRow> rows;
  final List<NbaPlayerCareerComparisonMatrixMetricSummary> summaries;

  bool get available => rows.isNotEmpty && metrics.isNotEmpty;
}

/// Produces a descriptive multi-metric matrix over one explicit comparison
/// scope. Metrics are source observations only; missing cells remain null and
/// every delta is simple left-minus-right in the metric's exposed units.
class NbaPlayerCareerComparisonMatrixEngine {
  const NbaPlayerCareerComparisonMatrixEngine();

  NbaPlayerCareerComparisonMatrixResult build(
    NbaPlayerCareerComparisonScopeResult scope, {
    List<NbaPlayerCareerMetric> metrics = const [
      NbaPlayerCareerMetric.pointsPerGame,
      NbaPlayerCareerMetric.reboundsPerGame,
      NbaPlayerCareerMetric.assistsPerGame,
      NbaPlayerCareerMetric.trueShootingPct,
      NbaPlayerCareerMetric.playerEfficiencyRating,
      NbaPlayerCareerMetric.winShares,
      NbaPlayerCareerMetric.boxPlusMinus,
      NbaPlayerCareerMetric.valueOverReplacement,
    ],
  }) {
    final uniqueMetrics = <NbaPlayerCareerMetric>[];
    for (final metric in metrics) {
      if (!uniqueMetrics.contains(metric)) uniqueMetrics.add(metric);
    }

    final rows = <NbaPlayerCareerComparisonMatrixRow>[];
    for (final pair in scope.pairs) {
      rows.add(
        NbaPlayerCareerComparisonMatrixRow(
          axisLabel: pair.axisLabel,
          leftSeasonId: pair.left?.seasonId ?? '',
          rightSeasonId: pair.right?.seasonId ?? '',
          cells: [
            for (final metric in uniqueMetrics)
              NbaPlayerCareerComparisonMatrixCell(
                metric: metric,
                leftValue: _value(pair.left, metric),
                rightValue: _value(pair.right, metric),
              ),
          ],
        ),
      );
    }

    final summaries = <NbaPlayerCareerComparisonMatrixMetricSummary>[];
    for (final metric in uniqueMetrics) {
      final deltas = <double>[];
      var leftAhead = 0;
      var rightAhead = 0;
      var tied = 0;
      for (final row in rows) {
        final cell = row.cells.firstWhere((cell) => cell.metric == metric);
        final delta = cell.delta;
        if (delta == null) continue;
        deltas.add(delta);
        if (delta > 0) {
          leftAhead++;
        } else if (delta < 0) {
          rightAhead++;
        } else {
          tied++;
        }
      }
      summaries.add(
        NbaPlayerCareerComparisonMatrixMetricSummary(
          metric: metric,
          pairedRows: deltas.length,
          leftAhead: leftAhead,
          rightAhead: rightAhead,
          tied: tied,
          meanDelta: deltas.isEmpty
              ? null
              : deltas.reduce((a, b) => a + b) / deltas.length,
        ),
      );
    }

    return NbaPlayerCareerComparisonMatrixResult(
      scope: scope,
      metrics: List.unmodifiable(uniqueMetrics),
      rows: List.unmodifiable(rows),
      summaries: List.unmodifiable(summaries),
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
