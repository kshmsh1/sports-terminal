import 'package:flutter/material.dart';

import '../services/nba_player_career_peak_window_engine.dart';

class NbaPlayerCareerPeakWindowPanel extends StatelessWidget {
  const NbaPlayerCareerPeakWindowPanel({
    super.key,
    required this.result,
    required this.leftLabel,
    required this.rightLabel,
  });

  final NbaPlayerCareerPeakWindowComparison result;
  final String leftLabel;
  final String rightLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('career-comparison-peak-window'),
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
            'PEAK WINDOW LAB',
            style: TextStyle(
              color: Color(0xFFE2B866),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${result.window}-season complete observed windows · ${result.metric.label} · independent career chronology',
            style: const TextStyle(color: Color(0xFF8895A5), fontSize: 10),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PeakCard(label: leftLabel, peak: result.left),
              _PeakCard(label: rightLabel, peak: result.right),
              _DeltaCard(delta: result.delta, metric: result.metric.label),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Peak windows require every row in the selected window to expose the metric. No missing-season interpolation, era normalization, age matching or rules adjustment is applied.',
            style: TextStyle(color: Color(0xFF8895A5), fontSize: 9, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PeakCard extends StatelessWidget {
  const _PeakCard({required this.label, required this.peak});
  final String label;
  final NbaPlayerCareerPeakWindow? peak;

  @override
  Widget build(BuildContext context) => Container(
        width: 250,
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
            const SizedBox(height: 5),
            Text(
              peak == null ? 'UNAVAILABLE' : peak!.mean.toStringAsFixed(2),
              style: const TextStyle(
                color: Color(0xFFE8EDF3),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              peak?.seasonRangeLabel ?? 'No complete observed window',
              style: const TextStyle(color: Color(0xFF8895A5), fontSize: 9),
            ),
          ],
        ),
      );
}

class _DeltaCard extends StatelessWidget {
  const _DeltaCard({required this.delta, required this.metric});
  final double? delta;
  final String metric;

  @override
  Widget build(BuildContext context) => Container(
        width: 220,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF141C25),
          border: Border.all(color: const Color(0xFF263342)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LEFT − RIGHT $metric',
              style: const TextStyle(
                color: Color(0xFFE2B866),
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              delta == null
                  ? '—'
                  : '${delta! > 0 ? '+' : ''}${delta!.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFFE8EDF3),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}
