import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_stats_query_engine.dart';

void main() {
  const engine = NbaStatsQueryEngine();

  test('parses the product requirement natural-language query', () {
    final plan = engine.parse(
      'List all players over the age of 29 who averaged more than 15 PPG '
      'but less than 4 RPG with FG% > 50 in the playoffs',
    );

    expect(plan.seasonType, 'Playoffs');
    expect(
      plan.constraints.any(
        (value) =>
            value.field == 'age' &&
            value.operator == NbaStatOperator.greaterThan &&
            value.value == 29,
      ),
      isTrue,
    );
    expect(
      plan.constraints.any(
        (value) =>
            value.field == 'ppg' &&
            value.operator == NbaStatOperator.greaterThan &&
            value.value == 15,
      ),
      isTrue,
    );
    expect(
      plan.constraints.any(
        (value) =>
            value.field == 'rpg' &&
            value.operator == NbaStatOperator.lessThan &&
            value.value == 4,
      ),
      isTrue,
    );
    expect(
      plan.constraints.any(
        (value) =>
            value.field == 'fg_pct' &&
            value.operator == NbaStatOperator.greaterThan &&
            value.value == .50,
      ),
      isTrue,
    );
  });

  test('supports field-first and operator-first comparisons together', () {
    final plan = engine.parse(
      'ppg >= 20 and fewer than 6 assists and rebounds at least 8',
    );

    expect(
      plan.constraints.any(
        (value) =>
            value.field == 'ppg' &&
            value.operator == NbaStatOperator.greaterThanOrEqual &&
            value.value == 20,
      ),
      isTrue,
    );
    expect(
      plan.constraints.any(
        (value) =>
            value.field == 'apg' &&
            value.operator == NbaStatOperator.lessThan &&
            value.value == 6,
      ),
      isTrue,
    );
    expect(
      plan.constraints.any(
        (value) =>
            value.field == 'rpg' &&
            value.operator == NbaStatOperator.greaterThanOrEqual &&
            value.value == 8,
      ),
      isTrue,
    );
  });

  test('does not parse GP from inside RPG', () {
    final plan = engine.parse('rpg > 4');

    expect(plan.constraints.where((value) => value.field == 'rpg'), hasLength(1));
    expect(plan.constraints.where((value) => value.field == 'gp'), isEmpty);
  });

  test('parses between ranges and normalizes percentages', () {
    final plan = engine.parse('fg% between 45 and 55 and age between 24 and 29');

    final shooting = plan.constraints.firstWhere(
      (value) => value.field == 'fg_pct',
    );
    final age = plan.constraints.firstWhere(
      (value) => value.field == 'age',
    );

    expect(shooting.operator, NbaStatOperator.between);
    expect(shooting.value, .45);
    expect(shooting.secondValue, .55);
    expect(age.operator, NbaStatOperator.between);
    expect(age.value, 24);
    expect(age.secondValue, 29);
  });
}
