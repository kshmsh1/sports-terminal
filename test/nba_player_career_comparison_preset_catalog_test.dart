import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_analytics_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_preset_catalog.dart';

void main() {
  test('catalog exposes distinct source-metric analyst presets', () {
    final ids = NbaPlayerCareerComparisonPresetCatalog.presets
        .map((preset) => preset.id)
        .toList();
    expect(ids.toSet().length, ids.length);
    expect(ids, containsAll(['core-box', 'efficiency', 'value', 'career-year']));
  });

  test('presets never duplicate a metric inside the same view', () {
    for (final preset in NbaPlayerCareerComparisonPresetCatalog.presets) {
      expect(preset.metrics.toSet().length, preset.metrics.length);
      expect(preset.metrics, isNotEmpty);
    }
  });

  test('shared-season preset is calendar aligned', () {
    final preset = const NbaPlayerCareerComparisonPresetCatalog()
        .resolve('shared-prime')!;
    expect(preset.sharedOnly, isTrue);
    expect(preset.alignment, NbaPlayerCareerComparisonAlignment.calendarSeason);
    expect(preset.peakWindow, 3);
  });

  test('career-year preset stays ordinal and does not claim shared seasons', () {
    final preset = const NbaPlayerCareerComparisonPresetCatalog()
        .resolve('career-year')!;
    expect(preset.alignment, NbaPlayerCareerComparisonAlignment.careerYear);
    expect(preset.sharedOnly, isFalse);
    expect(preset.metrics, contains(NbaPlayerCareerMetric.trueShootingPct));
  });

  test('resolve is case-insensitive and unknown ids stay unresolved', () {
    const catalog = NbaPlayerCareerComparisonPresetCatalog();
    expect(catalog.resolve('CORE-BOX')?.id, 'core-box');
    expect(catalog.resolve('not-a-preset'), isNull);
  });
}
