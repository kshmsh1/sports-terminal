import 'package:flutter/material.dart';

import '../services/nba_player_career_comparison_engine.dart';
import '../services/nba_player_career_comparison_metric_engine.dart';

class NbaPlayerCareerComparisonSummaryPanel extends StatelessWidget {
  const NbaPlayerCareerComparisonSummaryPanel({
    super.key,
    required this.comparison,
    required this.metric,
  });

  final NbaPlayerCareerComparisonSnapshot comparison;
  final NbaPlayerCareerComparisonMetricResult metric;

  @override
  Widget build(BuildContext context) {
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
            'CAREER COMPARISON SNAPSHOT',
            style: TextStyle(
              color: Color(0xFF63A9FF),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final left = _playerCard(
                comparison.left.playerName,
                comparison.left.careerRangeLabel,
                comparison.left.careerGames,
                comparison.left.careerPoints,
                comparison.left.tenureCoverageLabel,
              );
              final right = _playerCard(
                comparison.right.playerName,
                comparison.right.careerRangeLabel,
                comparison.right.careerGames,
                comparison.right.careerPoints,
                comparison.right.tenureCoverageLabel,
              );
              return compact
                  ? Column(children: [left, const SizedBox(height: 8), right])
                  : Row(children: [Expanded(child: left), const SizedBox(width: 8), Expanded(child: right)]);
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('ALIGNMENT', comparison.alignment.label),
              _pill('COVERAGE', comparison.coverageLabel),
              _pill('SHARED CALENDAR SEASONS', '${comparison.sharedCalendarSeasons.length}'),
              _pill('PAIRED ${metric.metric.label}', '${metric.paired}'),
              _pill('LEFT AHEAD', '${metric.leftAhead}'),
              _pill('RIGHT AHEAD', '${metric.rightAhead}'),
              _pill('TIES', '${metric.tied}'),
              _pill(
                'MEAN Δ L−R',
                metric.meanDelta == null ? '—' : metric.meanDelta!.toStringAsFixed(2),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            comparison.alignment == NbaPlayerCareerComparisonAlignment.careerYear
                ? 'Career-year alignment pairs ordinal source rows only. It does not claim equal age, role, rules, pace, league environment, or era difficulty.'
                : 'Calendar alignment compares only exact shared season IDs. Non-overlapping seasons remain one-sided observations rather than being shifted or imputed.',
            style: const TextStyle(color: Color(0xFF8895A5), fontSize: 9, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _playerCard(
    String name,
    String range,
    double? games,
    double? points,
    String coverage,
  ) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF141C25),
          border: Border.all(color: const Color(0xFF263342)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Color(0xFFE8EDF3),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              range,
              style: const TextStyle(color: Color(0xFF8895A5), fontSize: 10),
            ),
            const SizedBox(height: 7),
            Text(
              'Games ${_total(games)} · Points ${_total(points)}',
              style: const TextStyle(color: Color(0xFFE8EDF3), fontSize: 10),
            ),
            const SizedBox(height: 4),
            Text(
              coverage,
              style: const TextStyle(color: Color(0xFF8895A5), fontSize: 8),
            ),
          ],
        ),
      );

  Widget _pill(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF141C25),
          border: Border.all(color: const Color(0xFF263342)),
        ),
        child: Text(
          '$label · $value',
          style: const TextStyle(
            color: Color(0xFFE8EDF3),
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  String _total(double? value) =>
      value == null ? '—' : value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}
