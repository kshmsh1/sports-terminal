import 'package:flutter/material.dart';

import '../services/nba_player_career_comparison_engine.dart';
import '../services/nba_player_career_comparison_metric_engine.dart';

class NbaPlayerCareerComparisonTable extends StatelessWidget {
  const NbaPlayerCareerComparisonTable({
    super.key,
    required this.comparison,
    required this.metric,
    this.onOpenLeftSeason,
    this.onOpenRightSeason,
  });

  final NbaPlayerCareerComparisonSnapshot comparison;
  final NbaPlayerCareerComparisonMetricResult metric;
  final ValueChanged<String>? onOpenLeftSeason;
  final ValueChanged<String>? onOpenRightSeason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F151C),
        border: Border.all(color: const Color(0xFF263342)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'ALIGNED SEASON EVIDENCE · ${metric.metric.label}',
              style: const TextStyle(
                color: Color(0xFFE2B866),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF263342)),
          if (comparison.pairs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No source-backed season rows are available for this comparison.',
                style: TextStyle(color: Color(0xFF8895A5)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFF141C25)),
                columns: [
                  const DataColumn(label: Text('AXIS')),
                  DataColumn(label: Text('${comparison.left.playerName} SEASON')),
                  const DataColumn(label: Text('TEAM')),
                  DataColumn(label: Text(metric.metric.label)),
                  DataColumn(label: Text('${comparison.right.playerName} SEASON')),
                  const DataColumn(label: Text('TEAM')),
                  DataColumn(label: Text(metric.metric.label)),
                  const DataColumn(label: Text('Δ L−R')),
                ],
                rows: [
                  for (var index = 0; index < comparison.pairs.length; index++)
                    DataRow(
                      cells: [
                        DataCell(Text(comparison.pairs[index].axisLabel)),
                        DataCell(_seasonLink(
                          metric.points[index].leftSeasonId,
                          onOpenLeftSeason,
                        )),
                        DataCell(Text(comparison.pairs[index].left?.teamLabel ?? '—')),
                        DataCell(Text(_metric(metric.points[index].leftValue))),
                        DataCell(_seasonLink(
                          metric.points[index].rightSeasonId,
                          onOpenRightSeason,
                        )),
                        DataCell(Text(comparison.pairs[index].right?.teamLabel ?? '—')),
                        DataCell(Text(_metric(metric.points[index].rightValue))),
                        DataCell(Text(_signed(metric.points[index].delta))),
                      ],
                    ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'A blank side means that Player has no source-backed row on this axis. Team labels are descriptive source context only; no stint is reconstructed for multi-team aggregates.',
              style: TextStyle(color: Color(0xFF8895A5), fontSize: 9, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seasonLink(String seasonId, ValueChanged<String>? callback) {
    if (seasonId.isEmpty) return const Text('—');
    if (callback == null) return Text(seasonId);
    return TextButton(
      onPressed: () => callback(seasonId),
      child: Text(seasonId),
    );
  }

  String _metric(double? value) => value == null ? '—' : value.toStringAsFixed(2);
  String _signed(double? value) {
    if (value == null) return '—';
    if (value > 0) return '+${value.toStringAsFixed(2)}';
    return value.toStringAsFixed(2);
  }
}
