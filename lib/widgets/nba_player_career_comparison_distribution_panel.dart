import 'package:flutter/material.dart';

import '../services/nba_player_career_comparison_distribution_engine.dart';

class NbaPlayerCareerComparisonDistributionPanel extends StatelessWidget {
  const NbaPlayerCareerComparisonDistributionPanel({
    super.key,
    required this.result,
    required this.leftLabel,
    required this.rightLabel,
  });

  final NbaPlayerCareerComparisonDistributionResult result;
  final String leftLabel;
  final String rightLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('career-comparison-distribution-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151C),
        border: Border.all(color: const Color(0xFF263342)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SEASON DISTRIBUTION PROFILE',
            style: TextStyle(
              color: Color(0xFFE2B866),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${result.metric.label} across exposed rows in the active comparison scope',
            style: const TextStyle(color: Color(0xFF8895A5), fontSize: 10),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 40,
              columns: const [
                DataColumn(label: Text('PLAYER')),
                DataColumn(label: Text('OBS')),
                DataColumn(label: Text('MISS')),
                DataColumn(label: Text('MEAN')),
                DataColumn(label: Text('MEDIAN')),
                DataColumn(label: Text('Q1')),
                DataColumn(label: Text('Q3')),
                DataColumn(label: Text('MIN')),
                DataColumn(label: Text('MAX')),
                DataColumn(label: Text('σ')),
              ],
              rows: [
                _row(leftLabel, result.left),
                _row(rightLabel, result.right),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'MEAN Δ ${_fmt(result.meanDelta, signed: true)} · MEDIAN Δ ${_fmt(result.medianDelta, signed: true)} · population σ over observed rows only',
            style: const TextStyle(
              color: Color(0xFF63A9FF),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(String label, NbaPlayerCareerMetricDistribution distribution) =>
      DataRow(
        cells: [
          DataCell(Text(label)),
          DataCell(Text('${distribution.observed}')),
          DataCell(Text('${distribution.missing}')),
          DataCell(Text(_fmt(distribution.mean))),
          DataCell(Text(_fmt(distribution.median))),
          DataCell(Text(_fmt(distribution.lowerQuartile))),
          DataCell(Text(_fmt(distribution.upperQuartile))),
          DataCell(Text(_fmt(distribution.minimum))),
          DataCell(Text(_fmt(distribution.maximum))),
          DataCell(Text(_fmt(distribution.standardDeviation))),
        ],
      );

  String _fmt(double? value, {bool signed = false}) {
    if (value == null) return '—';
    final prefix = signed && value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}';
  }
}
