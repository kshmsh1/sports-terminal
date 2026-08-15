import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/nba_player_career_comparison_metric_engine.dart';

class NbaPlayerCareerComparisonChart extends StatelessWidget {
  const NbaPlayerCareerComparisonChart({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.metricLabel,
    required this.points,
    this.height = 250,
  });

  final String leftLabel;
  final String rightLabel;
  final String metricLabel;
  final List<NbaPlayerCareerComparisonMetricPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final observed = <double>[
      for (final point in points) ...[
        if (point.leftValue != null) point.leftValue!,
        if (point.rightValue != null) point.rightValue!,
      ],
    ];
    if (observed.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF263342)),
          color: const Color(0xFF0B1118),
        ),
        child: Text(
          '$metricLabel comparison unavailable — no paired or unpaired source observations.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF8895A5)),
        ),
      );
    }
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF263342)),
        color: const Color(0xFF0B1118),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _legend(leftLabel, const Color(0xFF63A9FF)),
              _legend(rightLabel, const Color(0xFFE2B866)),
              Text(
                metricLabel,
                style: const TextStyle(
                  color: Color(0xFF8895A5),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Expanded(
            child: CustomPaint(
              painter: _CareerComparisonPainter(points),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 14, height: 2, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE8EDF3),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
}

class _CareerComparisonPainter extends CustomPainter {
  const _CareerComparisonPainter(this.points);

  final List<NbaPlayerCareerComparisonMetricPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final values = <double>[
      for (final point in points) ...[
        if (point.leftValue != null) point.leftValue!,
        if (point.rightValue != null) point.rightValue!,
      ],
    ];
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;
    var minValue = values.reduce(math.min);
    var maxValue = values.reduce(math.max);
    if ((maxValue - minValue).abs() < .000001) {
      minValue -= 1;
      maxValue += 1;
    }
    final pad = (maxValue - minValue) * .08;
    minValue -= pad;
    maxValue += pad;

    final gridPaint = Paint()
      ..color = const Color(0xFF263342)
      ..strokeWidth = .6;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    _drawSeries(
      canvas,
      size,
      minValue,
      maxValue,
      const Color(0xFF63A9FF),
      (point) => point.leftValue,
    );
    _drawSeries(
      canvas,
      size,
      minValue,
      maxValue,
      const Color(0xFFE2B866),
      (point) => point.rightValue,
    );
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    double minValue,
    double maxValue,
    Color color,
    double? Function(NbaPlayerCareerComparisonMetricPoint point) valueOf,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = color;
    Offset? previous;
    for (var index = 0; index < points.length; index++) {
      final value = valueOf(points[index]);
      if (value == null) {
        previous = null;
        continue;
      }
      final x = points.length == 1
          ? size.width / 2
          : size.width * index / (points.length - 1);
      final ratio = (value - minValue) / (maxValue - minValue);
      final y = size.height - (ratio * size.height);
      final current = Offset(x, y);
      if (previous != null) canvas.drawLine(previous, current, paint);
      canvas.drawCircle(current, 2.7, dotPaint);
      previous = current;
    }
  }

  @override
  bool shouldRepaint(covariant _CareerComparisonPainter oldDelegate) =>
      oldDelegate.points != points;
}
