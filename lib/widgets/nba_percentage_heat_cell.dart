import 'package:flutter/material.dart';

enum NbaPercentageHeatMetric {
  fieldGoal,
  threePoint,
  freeThrow,
  defensiveFieldGoal,
  rimDefensiveFieldGoal,
  threePointDefensiveFieldGoal,
}

class NbaPercentageHeatCell extends StatelessWidget {
  const NbaPercentageHeatCell({
    super.key,
    required this.metric,
    required this.value,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    this.borderRadius = 6,
  });

  final NbaPercentageHeatMetric metric;
  final double? value;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final color = nbaPercentageHeatColor(context, metric, value);
    if (color == null) return child;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        child: child,
      ),
    );
  }
}

Color? nbaPercentageHeatColor(
  BuildContext context,
  NbaPercentageHeatMetric metric,
  double? rawValue,
) {
  if (rawValue == null || rawValue.isNaN || rawValue.isInfinite) return null;
  final value = rawValue > 1.5 ? rawValue / 100 : rawValue;

  const darkGreen = Color(0xFF14532D);
  const green = Color(0xFF15803D);
  const darkYellow = Color(0xFF8A6D00);
  const maroon = Color(0xFF7F1D1D);

  switch (metric) {
    case NbaPercentageHeatMetric.fieldGoal:
      if (value >= .50) return darkGreen;
      if (value >= .45) return green;
      if (value >= .40) return darkYellow;
      return maroon;
    case NbaPercentageHeatMetric.threePoint:
      if (value >= .40) return darkGreen;
      if (value >= .355) return green;
      if (value >= .32) return darkYellow;
      return maroon;
    case NbaPercentageHeatMetric.freeThrow:
      if (value >= .88) return darkGreen;
      if (value >= .78) return green;
      if (value >= .70) return darkYellow;
      return maroon;
    case NbaPercentageHeatMetric.defensiveFieldGoal:
      if (value < .43) return darkGreen;
      if (value < .45) return green;
      if (value < .48) return darkYellow;
      return maroon;
    case NbaPercentageHeatMetric.rimDefensiveFieldGoal:
      if (value < .50) return darkGreen;
      if (value < .57) return green;
      if (value < .63) return darkYellow;
      return maroon;
    case NbaPercentageHeatMetric.threePointDefensiveFieldGoal:
      if (value < .33) return darkGreen;
      if (value < .355) return green;
      if (value < .375) return darkYellow;
      return maroon;
  }
}

NbaPercentageHeatMetric? nbaPercentageHeatMetricForKey(String key) {
  final normalized = key.trim().toLowerCase();
  switch (normalized) {
    case 'fg_pct':
    case 'field_goal_pct':
    case 'field_goal_percentage':
      return NbaPercentageHeatMetric.fieldGoal;
    case 'three_pct':
    case 'fg3_pct':
    case 'three_point_pct':
    case 'three_point_percentage':
      return NbaPercentageHeatMetric.threePoint;
    case 'ft_pct':
    case 'free_throw_pct':
    case 'free_throw_percentage':
      return NbaPercentageHeatMetric.freeThrow;
    case 'd_fg_pct':
    case 'dfg_pct':
    case 'defensive_field_goal_pct':
      return NbaPercentageHeatMetric.defensiveFieldGoal;
    case 'rim_dfg_pct':
    case 'lt6_dfg_pct':
    case 'lt6_defensive_field_goal_pct':
      return NbaPercentageHeatMetric.rimDefensiveFieldGoal;
    case 'three_dfg_pct':
    case 'three_point_dfg_pct':
    case 'three_point_defensive_field_goal_pct':
      return NbaPercentageHeatMetric.threePointDefensiveFieldGoal;
    default:
      return null;
  }
}
