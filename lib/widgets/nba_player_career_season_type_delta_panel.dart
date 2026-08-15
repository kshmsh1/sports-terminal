import 'package:flutter/material.dart';

import '../services/nba_player_career_season_type_delta_engine.dart';

class NbaPlayerCareerSeasonTypeDeltaPanel extends StatelessWidget {
  const NbaPlayerCareerSeasonTypeDeltaPanel({
    super.key,
    required this.result,
    required this.leftLabel,
    required this.rightLabel,
  });

  final NbaPlayerCareerSeasonTypeDeltaResult result;
  final String leftLabel;
  final String rightLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('career-comparison-season-type-delta'),
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
            'REGULAR SEASON ↔ PLAYOFFS',
            style: TextStyle(
              color: Color(0xFFE2B866),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${result.metric.label} observed career-sample means · not matched-year or opponent-adjusted',
            style: const TextStyle(color: Color(0xFF8895A5), fontSize: 10),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SeasonTypeCard(label: leftLabel, summary: result.left),
              _SeasonTypeCard(label: rightLabel, summary: result.right),
              Container(
                width: 230,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFF141C25),
                  border: Border.all(color: const Color(0xFF263342)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Δ DIFFERENCE',
                      style: TextStyle(
                        color: Color(0xFF63A9FF),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _fmt(result.deltaDifference, signed: true),
                      style: const TextStyle(
                        color: Color(0xFFE8EDF3),
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      '(left playoff−regular) − (right playoff−regular)',
                      style: TextStyle(color: Color(0xFF8895A5), fontSize: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double? value, {bool signed = false}) {
    if (value == null) return '—';
    final prefix = signed && value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}';
  }
}

class _SeasonTypeCard extends StatelessWidget {
  const _SeasonTypeCard({required this.label, required this.summary});
  final String label;
  final NbaPlayerCareerSeasonTypeMetricSummary summary;

  @override
  Widget build(BuildContext context) => Container(
        width: 275,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF141C25),
          border: Border.all(color: const Color(0xFF263342)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF63A9FF),
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'REG ${_fmt(summary.regularMean)} (${summary.regularObserved}) · PO ${_fmt(summary.playoffMean)} (${summary.playoffObserved})',
              style: const TextStyle(
                color: Color(0xFFE8EDF3),
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'PLAYOFF − REGULAR ${_fmt(summary.playoffMinusRegular, signed: true)}',
              style: const TextStyle(color: Color(0xFFE2B866), fontSize: 9),
            ),
          ],
        ),
      );

  String _fmt(double? value, {bool signed = false}) {
    if (value == null) return '—';
    final prefix = signed && value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}';
  }
}
