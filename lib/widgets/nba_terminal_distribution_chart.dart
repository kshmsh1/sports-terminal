import 'dart:math' as math;

import 'package:flutter/material.dart';

class NbaTerminalDistributionPoint {
  const NbaTerminalDistributionPoint({
    required this.label,
    required this.value,
    this.entityId = '',
  });

  final String label;
  final double value;
  final String entityId;
}

/// Zero-dependency compact distribution visualization for terminal analytics.
///
/// Values are rendered exactly as supplied. Negative observations stay below
/// the zero baseline; the chart never shifts or imputes values to make a shape
/// look smoother.
class NbaTerminalDistributionChart extends StatelessWidget {
  const NbaTerminalDistributionChart({
    super.key,
    required this.points,
    this.height = 190,
    this.referenceValue,
    this.referenceLabel = 'MEDIAN',
  });

  final List<NbaTerminalDistributionPoint> points;
  final double height;
  final double? referenceValue;
  final String referenceLabel;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 110,
        child: Center(
          child: Text(
            'No observed distribution rows.',
            style: TextStyle(color: Color(0xFF8895A5), fontSize: 10),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        key: const ValueKey('nba-terminal-distribution-chart'),
        painter: _DistributionPainter(
          points: points,
          referenceValue: referenceValue,
        ),
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, right: 6),
            child: Text(
              referenceValue == null
                  ? '${points.length} OBSERVED'
                  : '$referenceLabel ${referenceValue!.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF8895A5),
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DistributionPainter extends CustomPainter {
  const _DistributionPainter({
    required this.points,
    required this.referenceValue,
  });

  final List<NbaTerminalDistributionPoint> points;
  final double? referenceValue;

  @override
  void paint(Canvas canvas, Size size) {
    const padLeft = 12.0;
    const padRight = 12.0;
    const padTop = 28.0;
    const padBottom = 28.0;
    final values = [for (final point in points) point.value];
    final minimum = math.min(0.0, values.reduce(math.min));
    final maximum = math.max(0.0, values.reduce(math.max));
    final span = math.max(1e-9, maximum - minimum);
    final top = padTop;
    final bottom = size.height - padBottom;
    final plotHeight = math.max(1.0, bottom - top);
    final plotWidth = math.max(1.0, size.width - padLeft - padRight);
    double yFor(double value) => bottom - ((value - minimum) / span) * plotHeight;
    final baselineY = yFor(0);

    final axis = Paint()
      ..color = const Color(0xFF263342)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(padLeft, baselineY),
      Offset(size.width - padRight, baselineY),
      axis,
    );

    if (referenceValue != null &&
        referenceValue! >= minimum &&
        referenceValue! <= maximum) {
      final reference = Paint()
        ..color = const Color(0xFFE2B866).withValues(alpha: .75)
        ..strokeWidth = 1;
      final y = yFor(referenceValue!);
      canvas.drawLine(Offset(padLeft, y), Offset(size.width - padRight, y), reference);
    }

    final slot = plotWidth / math.max(1, points.length);
    final width = math.max(2.0, math.min(20.0, slot * .62));
    final bar = Paint()..color = const Color(0xFF63A9FF).withValues(alpha: .82);
    for (var index = 0; index < points.length; index++) {
      final centerX = padLeft + slot * index + slot / 2;
      final valueY = yFor(points[index].value);
      final rect = Rect.fromLTRB(
        centerX - width / 2,
        math.min(baselineY, valueY),
        centerX + width / 2,
        math.max(baselineY, valueY),
      );
      canvas.drawRect(rect, bar);
    }
  }

  @override
  bool shouldRepaint(covariant _DistributionPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.referenceValue != referenceValue;
}
