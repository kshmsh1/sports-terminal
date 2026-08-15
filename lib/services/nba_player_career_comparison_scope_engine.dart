import 'nba_player_career_comparison_engine.dart';

class NbaPlayerCareerComparisonScopeResult {
  const NbaPlayerCareerComparisonScopeResult({
    required this.comparison,
    required this.sharedOnly,
    required this.pairs,
    required this.excludedLeftOnly,
    required this.excludedRightOnly,
  });

  final NbaPlayerCareerComparisonSnapshot comparison;
  final bool sharedOnly;
  final List<NbaPlayerCareerComparisonPair> pairs;
  final int excludedLeftOnly;
  final int excludedRightOnly;

  int get paired => pairs.where((pair) => pair.bothObserved).length;
  int get leftOnly => pairs.where((pair) => pair.leftOnly).length;
  int get rightOnly => pairs.where((pair) => pair.rightOnly).length;

  String get coverageLabel {
    if (!sharedOnly) return comparison.coverageLabel;
    if (comparison.alignment !=
        NbaPlayerCareerComparisonAlignment.calendarSeason) {
      return 'SHARED-SEASON FILTER REQUIRES CALENDAR ALIGNMENT';
    }
    if (pairs.isEmpty) return 'NO SHARED CALENDAR SEASONS';
    return '$paired SHARED CALENDAR SEASON(S)';
  }
}

/// Applies an explicit analyst scope to an already-canonical career comparison.
///
/// `sharedOnly` is meaningful only for calendar-season alignment. Career-year
/// alignment is ordinal by definition, so this engine never silently converts
/// that axis into calendar overlap. No season rows are synthesized.
class NbaPlayerCareerComparisonScopeEngine {
  const NbaPlayerCareerComparisonScopeEngine();

  NbaPlayerCareerComparisonScopeResult build(
    NbaPlayerCareerComparisonSnapshot comparison, {
    bool sharedOnly = false,
  }) {
    if (!sharedOnly ||
        comparison.alignment !=
            NbaPlayerCareerComparisonAlignment.calendarSeason) {
      return NbaPlayerCareerComparisonScopeResult(
        comparison: comparison,
        sharedOnly: sharedOnly,
        pairs: List.unmodifiable(comparison.pairs),
        excludedLeftOnly: 0,
        excludedRightOnly: 0,
      );
    }

    final pairs = comparison.pairs.where((pair) => pair.bothObserved).toList();
    return NbaPlayerCareerComparisonScopeResult(
      comparison: comparison,
      sharedOnly: true,
      pairs: List.unmodifiable(pairs),
      excludedLeftOnly:
          comparison.pairs.where((pair) => pair.leftOnly).length,
      excludedRightOnly:
          comparison.pairs.where((pair) => pair.rightOnly).length,
    );
  }
}
