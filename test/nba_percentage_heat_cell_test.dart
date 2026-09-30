import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/widgets/nba_percentage_heat_cell.dart';

void main() {
  Future<Color?> colorFor(
    WidgetTester tester,
    NbaPercentageHeatMetric metric,
    double value,
  ) async {
    Color? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            result = nbaPercentageHeatColor(context, metric, value);
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('eFG and TS use requested thresholds', (tester) async {
    expect(
      await colorFor(tester, NbaPercentageHeatMetric.effectiveFieldGoal, .60),
      const Color(0xFF14532D),
    );
    expect(
      await colorFor(tester, NbaPercentageHeatMetric.effectiveFieldGoal, .55),
      const Color(0xFF15803D),
    );
    expect(
      await colorFor(tester, NbaPercentageHeatMetric.effectiveFieldGoal, .51),
      const Color(0xFF8A6D00),
    );
    expect(
      await colorFor(tester, NbaPercentageHeatMetric.effectiveFieldGoal, .509),
      const Color(0xFF7F1D1D),
    );

    expect(
      await colorFor(tester, NbaPercentageHeatMetric.trueShooting, .62),
      const Color(0xFF14532D),
    );
    expect(
      await colorFor(tester, NbaPercentageHeatMetric.trueShooting, .57),
      const Color(0xFF15803D),
    );
    expect(
      await colorFor(tester, NbaPercentageHeatMetric.trueShooting, .545),
      const Color(0xFF8A6D00),
    );
    expect(
      await colorFor(tester, NbaPercentageHeatMetric.trueShooting, .544),
      const Color(0xFF7F1D1D),
    );
  });

  testWidgets('AST:TO and Box Out percentage use requested thresholds', (tester) async {
    expect(
      await colorFor(tester, NbaPercentageHeatMetric.assistTurnover, 3.0),
      const Color(0xFF14532D),
    );
    expect(
      await colorFor(tester, NbaPercentageHeatMetric.assistTurnover, 2.0),
      const Color(0xFF15803D),
    );
    expect(
      await colorFor(tester, NbaPercentageHeatMetric.assistTurnover, 1.3),
      const Color(0xFF8A6D00),
    );
    expect(
      await colorFor(tester, NbaPercentageHeatMetric.assistTurnover, 1.29),
      const Color(0xFF7F1D1D),
    );

    expect(
      await colorFor(tester, NbaPercentageHeatMetric.boxOut, .75),
      const Color(0xFF14532D),
    );
    expect(
      await colorFor(tester, NbaPercentageHeatMetric.boxOut, .60),
      const Color(0xFF15803D),
    );
    expect(
      await colorFor(tester, NbaPercentageHeatMetric.boxOut, .50),
      const Color(0xFF8A6D00),
    );
    expect(
      await colorFor(tester, NbaPercentageHeatMetric.boxOut, .499),
      const Color(0xFF7F1D1D),
    );
  });

  test('clutch percentages inherit standard shooting heat families', () {
    expect(
      nbaPercentageHeatMetricForKey('clutch_fg_pct'),
      NbaPercentageHeatMetric.fieldGoal,
    );
    expect(
      nbaPercentageHeatMetricForKey('clutch_three_pct'),
      NbaPercentageHeatMetric.threePoint,
    );
    expect(
      nbaPercentageHeatMetricForKey('clutch_ft_pct'),
      NbaPercentageHeatMetric.freeThrow,
    );
  });
}
