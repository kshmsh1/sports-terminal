import 'nba_player_career_analytics_engine.dart';
import 'nba_player_career_comparison_engine.dart';

class NbaPlayerCareerComparisonPreset {
  const NbaPlayerCareerComparisonPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.metrics,
    this.alignment = NbaPlayerCareerComparisonAlignment.calendarSeason,
    this.sharedOnly = false,
    this.peakWindow = 3,
  });

  final String id;
  final String label;
  final String description;
  final List<NbaPlayerCareerMetric> metrics;
  final NbaPlayerCareerComparisonAlignment alignment;
  final bool sharedOnly;
  final int peakWindow;
}

/// Static analyst-view presets. Presets only select visible source metrics and
/// comparison scope; they do not assign weights, composite scores, rankings or
/// era adjustments.
class NbaPlayerCareerComparisonPresetCatalog {
  const NbaPlayerCareerComparisonPresetCatalog();

  static const presets = <NbaPlayerCareerComparisonPreset>[
    NbaPlayerCareerComparisonPreset(
      id: 'core-box',
      label: 'CORE BOX',
      description: 'Scoring, rebounding and creation season values.',
      metrics: [
        NbaPlayerCareerMetric.pointsPerGame,
        NbaPlayerCareerMetric.reboundsPerGame,
        NbaPlayerCareerMetric.assistsPerGame,
      ],
    ),
    NbaPlayerCareerComparisonPreset(
      id: 'two-way-box',
      label: 'TWO-WAY BOX',
      description: 'Observed scoring, steals, blocks and turnovers.',
      metrics: [
        NbaPlayerCareerMetric.pointsPerGame,
        NbaPlayerCareerMetric.stealsPerGame,
        NbaPlayerCareerMetric.blocksPerGame,
        NbaPlayerCareerMetric.turnoversPerGame,
      ],
    ),
    NbaPlayerCareerComparisonPreset(
      id: 'efficiency',
      label: 'EFFICIENCY',
      description: 'Source-backed TS%, PER and BPM without a composite score.',
      metrics: [
        NbaPlayerCareerMetric.trueShootingPct,
        NbaPlayerCareerMetric.playerEfficiencyRating,
        NbaPlayerCareerMetric.boxPlusMinus,
      ],
    ),
    NbaPlayerCareerComparisonPreset(
      id: 'value',
      label: 'VALUE',
      description: 'Source-backed win shares, BPM and VORP.',
      metrics: [
        NbaPlayerCareerMetric.winShares,
        NbaPlayerCareerMetric.boxPlusMinus,
        NbaPlayerCareerMetric.valueOverReplacement,
      ],
    ),
    NbaPlayerCareerComparisonPreset(
      id: 'shared-prime',
      label: 'SHARED-SEASON PEAK',
      description: 'Shared calendar seasons with a three-row peak window.',
      metrics: [
        NbaPlayerCareerMetric.pointsPerGame,
        NbaPlayerCareerMetric.trueShootingPct,
        NbaPlayerCareerMetric.boxPlusMinus,
      ],
      sharedOnly: true,
      peakWindow: 3,
    ),
    NbaPlayerCareerComparisonPreset(
      id: 'career-year',
      label: 'CAREER-YEAR',
      description: 'Ordinal career-year view; no age or era equivalence claim.',
      metrics: [
        NbaPlayerCareerMetric.pointsPerGame,
        NbaPlayerCareerMetric.reboundsPerGame,
        NbaPlayerCareerMetric.assistsPerGame,
        NbaPlayerCareerMetric.trueShootingPct,
      ],
      alignment: NbaPlayerCareerComparisonAlignment.careerYear,
    ),
  ];

  NbaPlayerCareerComparisonPreset? resolve(String id) {
    final normalized = id.trim().toLowerCase();
    for (final preset in presets) {
      if (preset.id == normalized) return preset;
    }
    return null;
  }
}
