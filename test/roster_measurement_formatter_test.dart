import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/roster_measurement_formatter.dart';

void main() {
  const formatter = RosterMeasurementFormatter();

  test('parses height and formats meters', () {
    expect(formatter.heightInches('6\' 9"'), 81);
    expect(formatter.heightMeters('6\' 9"').toStringAsFixed(2), '2.06');
    expect(formatter.heightLabel('6\' 9"'), '6\' 9" (2.06 m)');
  });

  test('accepts compact and typographic height notation', () {
    expect(formatter.heightInches('5\'11"'), 71);
    expect(formatter.heightInches('7′ 1″'), 85);
    expect(formatter.heightInches('6’ 4”'), 76);
  });

  test('rejects malformed height values', () {
    expect(formatter.heightInches('6 feet 9 inches'), -1);
    expect(formatter.heightInches('bad-height'), -1);
    expect(formatter.heightInches(''), -1);
  });

  test('formats pounds and kilograms', () {
    expect(formatter.weightKilograms(250).toStringAsFixed(1), '113.4');
    expect(formatter.weightLabel(250), '250 lbs (113.4 kg)');
  });

  test('handles missing values safely', () {
    expect(formatter.heightInches(null), -1);
    expect(formatter.heightLabel(null), '—');
    expect(formatter.weightKilograms(null), -1);
    expect(formatter.weightLabel(null), '—');
    expect(formatter.jerseySortValue('00'), 0);
    expect(formatter.jerseySortValue(null), 999);
  });
}
