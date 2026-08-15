import 'nba_player_career_analytics_engine.dart';
import 'nba_player_career_engine.dart';

class NbaPlayerCareerPeakWindow {
  const NbaPlayerCareerPeakWindow({
    required this.metric,
    required this.window,
    required this.startSeason,
    required this.endSeason,
    required this.mean,
    required this.values,
  });

  final NbaPlayerCareerMetric metric;
  final int window;
  final String startSeason;
  final String endSeason;
  final double mean;
  final List<double> values;

  String get seasonRangeLabel =>
      startSeason == endSeason ? startSeason : '$startSeason → $endSeason';
}

class NbaPlayerCareerPeakWindowComparison {
  const NbaPlayerCareerPeakWindowComparison({
    required this.metric,
    required this.window,
    required this.left,
    required this.right,
  });

  final NbaPlayerCareerMetric metric;
  final int window;
  final NbaPlayerCareerPeakWindow? left;
  final NbaPlayerCareerPeakWindow? right;

  bool get paired => left != null && right != null;
  double? get delta => paired ? left!.mean - right!.mean : null;
}

/// Finds each Player's best contiguous observed career window independently.
///
/// A candidate window is valid only when every row in that window exposes the
/// requested metric. Missing seasons break eligibility; no interpolation or
/// cross-era adjustment is performed. The window is chronological career data,
/// not an age-equivalent or rules-adjusted claim; it does not claim equivalent
/// age, role, competition, rules, pace, or league environment.
class NbaPlayerCareerPeakWindowEngine {
  const NbaPlayerCareerPeakWindowEngine();

  NbaPlayerCareerPeakWindowComparison build({
    required NbaPlayerCareerSnapshot left,
    required NbaPlayerCareerSnapshot right,
    NbaPlayerCareerMetric metric = NbaPlayerCareerMetric.pointsPerGame,
    int window = 3,
  }) {
    final normalizedWindow = window.clamp(1, 10).toInt();
    return NbaPlayerCareerPeakWindowComparison(
      metric: metric,
      window: normalizedWindow,
      left: _peak(left, metric, normalizedWindow),
      right: _peak(right, metric, normalizedWindow),
    );
  }

  NbaPlayerCareerPeakWindow? _peak(
    NbaPlayerCareerSnapshot career,
    NbaPlayerCareerMetric metric,
    int window,
  ) {
    final seasons = [...career.seasons]
      ..sort((a, b) => a.seasonId.compareTo(b.seasonId));
    if (seasons.length < window) return null;

    NbaPlayerCareerPeakWindow? best;
    for (var start = 0; start + window <= seasons.length; start++) {
      final slice = seasons.sublist(start, start + window);
      final values = [for (final season in slice) _value(season, metric)];
      if (values.any((value) => value == null)) continue;
      final observed = values.whereType<double>().toList();
      final mean = observed.reduce((a, b) => a + b) / observed.length;
      if (best == null || mean > best.mean) {
        best = NbaPlayerCareerPeakWindow(
          metric: metric,
          window: window,
          startSeason: slice.first.seasonId,
          endSeason: slice.last.seasonId,
          mean: mean,
          values: List.unmodifiable(observed),
        );
      }
    }
    return best;
  }

  double? _value(NbaPlayerCareerSeason season, NbaPlayerCareerMetric metric) {
    return switch (metric) {
      NbaPlayerCareerMetric.pointsPerGame => season.pointsPerGame,
      NbaPlayerCareerMetric.reboundsPerGame => season.reboundsPerGame,
      NbaPlayerCareerMetric.assistsPerGame => season.assistsPerGame,
      NbaPlayerCareerMetric.stealsPerGame => season.stealsPerGame,
      NbaPlayerCareerMetric.blocksPerGame => season.blocksPerGame,
      NbaPlayerCareerMetric.turnoversPerGame => season.turnoversPerGame,
      NbaPlayerCareerMetric.trueShootingPct =>
        season.trueShootingPct == null ? null : season.trueShootingPct! * 100,
      NbaPlayerCareerMetric.playerEfficiencyRating =>
        season.playerEfficiencyRating,
      NbaPlayerCareerMetric.winShares => season.winShares,
      NbaPlayerCareerMetric.boxPlusMinus => season.boxPlusMinus,
      NbaPlayerCareerMetric.valueOverReplacement => season.valueOverReplacement,
    };
  }
}