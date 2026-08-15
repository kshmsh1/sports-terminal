import 'package:flutter/material.dart';

import '../services/nba_player_career_comparison_context_engine.dart';
import '../services/nba_player_career_engine.dart';

class NbaPlayerCareerComparisonContextPanel extends StatelessWidget {
  const NbaPlayerCareerComparisonContextPanel({
    super.key,
    required this.left,
    required this.right,
    required this.context,
  });

  final NbaPlayerCareerSnapshot left;
  final NbaPlayerCareerSnapshot right;
  final NbaPlayerCareerComparisonContextResult context;

  @override
  Widget build(BuildContext contextBuild) {
    return Container(
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
            'CAREER CONTEXT EVIDENCE',
            style: TextStyle(
              color: Color(0xFFE2B866),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF141C25)),
              columns: [
                const DataColumn(label: Text('EVIDENCE')),
                DataColumn(label: Text(left.playerName)),
                DataColumn(label: Text(right.playerName)),
              ],
              rows: [
                _row('AWARD ROWS', context.leftAwardRows, context.rightAwardRows),
                _row('ALL-STAR ROWS', context.leftAllStarRows, context.rightAllStarRows),
                _row('DRAFT ROWS', context.leftDraftRows, context.rightDraftRows),
                _row('RECENT GAME ROWS', context.leftRecentGames, context.rightRecentGames),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _list('SHARED EXACT AWARD LABELS', context.sharedAwardLabels),
          _list('${left.playerName.toUpperCase()}-ONLY LABELS', context.leftOnlyAwardLabels),
          _list('${right.playerName.toUpperCase()}-ONLY LABELS', context.rightOnlyAwardLabels),
          _list('SHARED ALL-STAR SEASON IDS', context.sharedAllStarSeasons),
          const SizedBox(height: 7),
          Text(
            context.boundaryLabel,
            style: const TextStyle(
              color: Color(0xFF8895A5),
              fontSize: 9,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(String label, int leftValue, int rightValue) => DataRow(
        cells: [
          DataCell(Text(label)),
          DataCell(Text('$leftValue')),
          DataCell(Text('$rightValue')),
        ],
      );

  Widget _list(String label, List<String> values) => Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          '$label · ${values.isEmpty ? 'NONE EXPLICITLY SHARED/EXPOSED' : values.join(', ')}',
          style: const TextStyle(color: Color(0xFF8895A5), fontSize: 9, height: 1.35),
        ),
      );
}
