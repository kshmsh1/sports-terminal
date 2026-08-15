import 'dart:convert';

import 'nba_player_career_comparison_distribution_engine.dart';
import 'nba_player_career_comparison_matrix_engine.dart';
import 'nba_player_career_peak_window_engine.dart';

class NbaPlayerCareerComparisonExportBundle {
  const NbaPlayerCareerComparisonExportBundle({
    required this.columns,
    required this.rows,
    required this.metadata,
  });

  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> metadata;

  String get tsv => _delimited('\t');
  String get csv => _delimited(',');
  String get json => const JsonEncoder.withIndent('  ').convert({
        'metadata': metadata,
        'columns': columns,
        'rows': rows,
      });

  String _delimited(String separator) {
    String cell(Object? value) {
      if (value == null) return '';
      final text = value.toString();
      if (separator == ',' &&
          (text.contains(',') || text.contains('"') || text.contains('\n'))) {
        return '"${text.replaceAll('"', '""')}"';
      }
      return text.replaceAll('\t', ' ').replaceAll('\n', ' ');
    }

    final lines = <String>[
      columns.map(cell).join(separator),
      for (final row in rows)
        columns.map((column) => cell(row[column])).join(separator),
    ];
    return lines.join('\n');
  }
}

/// Exports the already-resolved comparison evidence without re-querying data or
/// widening scope. Every row preserves exact axis/season identity and nulls.
class NbaPlayerCareerComparisonExportService {
  const NbaPlayerCareerComparisonExportService();

  NbaPlayerCareerComparisonExportBundle build({
    required NbaPlayerCareerComparisonMatrixResult matrix,
    required NbaPlayerCareerComparisonDistributionResult distribution,
    required NbaPlayerCareerPeakWindowComparison peak,
    String league = 'NBA',
    String seasonType = 'regular',
  }) {
    final comparison = matrix.scope.comparison;
    final metricColumns = <String>[];
    for (final metric in matrix.metrics) {
      metricColumns.addAll([
        'left_${metric.name}',
        'right_${metric.name}',
        'delta_${metric.name}',
      ]);
    }
    final columns = <String>[
      'axis',
      'left_player_key',
      'left_player',
      'left_season_id',
      'right_player_key',
      'right_player',
      'right_season_id',
      ...metricColumns,
    ];
    final rows = <Map<String, dynamic>>[
      for (final row in matrix.rows)
        {
          'axis': row.axisLabel,
          'left_player_key': comparison.left.playerKey,
          'left_player': comparison.left.playerName,
          'left_season_id': row.leftSeasonId,
          'right_player_key': comparison.right.playerKey,
          'right_player': comparison.right.playerName,
          'right_season_id': row.rightSeasonId,
          for (final cell in row.cells) ...{
            'left_${cell.metric.name}': cell.leftValue,
            'right_${cell.metric.name}': cell.rightValue,
            'delta_${cell.metric.name}': cell.delta,
          },
        },
    ];
    return NbaPlayerCareerComparisonExportBundle(
      columns: List.unmodifiable(columns),
      rows: List.unmodifiable(rows),
      metadata: {
        'objectType': 'NBA Player Career Comparison',
        'league': league.trim().isEmpty ? 'NBA' : league.trim().toUpperCase(),
        'seasonType': seasonType,
        'alignment': comparison.alignment.name,
        'sharedOnly': matrix.scope.sharedOnly,
        'coverage': matrix.scope.coverageLabel,
        'normalization': 'none',
        'distributionMetric': distribution.metric.label,
        'leftDistributionObserved': distribution.left.observed,
        'rightDistributionObserved': distribution.right.observed,
        'distributionMeanDelta': distribution.meanDelta,
        'peakMetric': peak.metric.label,
        'peakWindow': peak.window,
        'leftPeakRange': peak.left?.seasonRangeLabel,
        'leftPeakMean': peak.left?.mean,
        'rightPeakRange': peak.right?.seasonRangeLabel,
        'rightPeakMean': peak.right?.mean,
        'peakDelta': peak.delta,
      },
    );
  }
}
