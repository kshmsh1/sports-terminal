import 'dart:math' as math;

import 'package:flutter/material.dart';

const _panel2 = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _amber = Color(0xFFE2B866);

class NbaTerminalTrendPoint {
  const NbaTerminalTrendPoint({
    required this.label,
    required this.value,
    this.rollingValue,
    this.gameId = '',
  });

  final String label;
  final double? value;
  final double? rollingValue;
  final String gameId;
}

/// Reusable zero-dependency terminal chart for observed cross-game series.
/// Null observations remain gaps; they are never interpolated into values.
class NbaTerminalTrendChart extends StatelessWidget {
  const NbaTerminalTrendChart({
    super.key,
    required this.points,
    required this.metricLabel,
    this.height = 190,
  });

  final List<NbaTerminalTrendPoint> points;
  final String metricLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final available = points.where((point) => point.value != null).length;
    return Container(
      key: ValueKey('terminal-trend-chart-$metricLabel'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$metricLabel TREND',
                  style: const TextStyle(
                    color: _text,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$available/${points.length} observed',
                style: const TextStyle(color: _muted, fontSize: 8),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (points.isEmpty || available == 0)
            SizedBox(
              height: height,
              child: const Center(
                child: Text(
                  'Trend unavailable in the active game-log scope.',
                  style: TextStyle(color: _muted, fontSize: 9),
                ),
              ),
            )
          else
            SizedBox(
              height: height,
              child: CustomPaint(
                painter: _TrendPainter(points),
                child: const SizedBox.expand(),
              ),
            ),
          const SizedBox(height: 7),
          const Wrap(
            spacing: 14,
            runSpacing: 5,
            children: [
              _Legend(label: 'OBSERVED', color: _blue),
              _Legend(label: 'ROLLING AVG', color: _amber),
              Text(
                'Missing rows remain gaps',
                style: TextStyle(color: _muted, fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 2, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900),
          ),
        ],
      );
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.points);

  final List<NbaTerminalTrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final values = <double>[
      for (final point in points) ...[
        if (point.value != null) point.value!,
        if (point.rollingValue != null) point.rollingValue!,
      ],
    ];
    if (values.isEmpty) return;
    var minValue = values.reduce(math.min);
    var maxValue = values.reduce(math.max);
    if ((maxValue - minValue).abs() < .0001) {
      minValue -= 1;
      maxValue += 1;
    }
    final padding = math.max((maxValue - minValue) * .08, .5);
    minValue -= padding;
    maxValue += padding;

    final gridPaint = Paint()
      ..color = _line.withValues(alpha: .65)
      ..strokeWidth = 1;
    for (var index = 0; index <= 4; index++) {
      final y = size.height * index / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    _drawSeries(canvas, size, minValue, maxValue, false, _blue);
    _drawSeries(canvas, size, minValue, maxValue, true, _amber);
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    double minValue,
    double maxValue,
    bool rolling,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = rolling ? 1.5 : 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = color;
    final path = Path();
    var hasOpenSegment = false;

    for (var index = 0; index < points.length; index++) {
      final value = rolling ? points[index].rollingValue : points[index].value;
      if (value == null) {
        hasOpenSegment = false;
        continue;
      }
      final x = points.length == 1
          ? size.width / 2
          : size.width * index / (points.length - 1);
      final fraction = (value - minValue) / (maxValue - minValue);
      final y = size.height - (fraction * size.height);
      final offset = Offset(x, y);
      if (!hasOpenSegment) {
        path.moveTo(offset.dx, offset.dy);
        hasOpenSegment = true;
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
      if (!rolling) canvas.drawCircle(offset, 2.5, dotPaint);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points;
}
