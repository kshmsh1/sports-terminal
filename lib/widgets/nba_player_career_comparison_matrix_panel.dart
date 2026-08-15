import 'package:flutter/material.dart';

import '../services/nba_player_career_comparison_matrix_engine.dart';

class NbaPlayerCareerComparisonMatrixPanel extends StatelessWidget {
  const NbaPlayerCareerComparisonMatrixPanel({
    super.key,
    required this.result,
    required this.leftLabel,
    required this.rightLabel,
  });

  final NbaPlayerCareerComparisonMatrixResult result;
  final String leftLabel;
  final String rightLabel;

  static const _panel = Color(0xFF0F151C);
  static const _line = Color(0xFF263342);
  static const _muted = Color(0xFF8895A5);
  static const _blue = Color(0xFF63A9FF);
  static const _amber = Color(0xFFE2B866);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('career-comparison-multi-metric-matrix'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MULTI-METRIC SEASON MATRIX',
            style: TextStyle(
              color: _amber,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${result.scope.coverageLabel} · left-minus-right deltas · no composite score',
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
          const SizedBox(height: 10),
          if (!result.available)
            const Text('No matrix rows are available in this scope.', style: TextStyle(color: _muted))
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final summary in result.summaries)
                  _SummaryPill(
                    label: summary.metric.label,
                    value:
                        '${summary.pairedRows} paired · ${summary.leftAhead}/${summary.rightAhead}/${summary.tied}',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 34,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 40,
                columnSpacing: 18,
                columns: [
                  const DataColumn(label: Text('AXIS')),
                  for (final metric in result.metrics) ...[
                    DataColumn(label: Text('$leftLabel ${metric.label}')),
                    DataColumn(label: Text('$rightLabel ${metric.label}')),
                    DataColumn(label: Text('Δ ${metric.label}')),
                  ],
                ],
                rows: [
                  for (final row in result.rows)
                    DataRow(
                      cells: [
                        DataCell(Text(row.axisLabel)),
                        for (final cell in row.cells) ...[
                          DataCell(Text(_format(cell.leftValue))),
                          DataCell(Text(_format(cell.rightValue))),
                          DataCell(
                            Text(
                              _format(cell.delta, signed: true),
                              style: const TextStyle(color: _blue),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _format(double? value, {bool signed = false}) {
    if (value == null) return '—';
    final prefix = signed && value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}';
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF141C25),
          border: Border.all(color: const Color(0xFF263342)),
        ),
        child: Text(
          '$label · $value',
          style: const TextStyle(
            color: Color(0xFFE8EDF3),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
