import 'nba_player_career_analytics_engine.dart';
import 'nba_player_career_engine.dart';

class NbaPlayerCareerSeasonTypeMetricSummary {
  const NbaPlayerCareerSeasonTypeMetricSummary({
    required this.regularObserved,
    required this.playoffObserved,
    required this.regularMean,
    required this.playoffMean,
  });

  final int regularObserved;
  final int playoffObserved;
  final double? regularMean;
  final double? playoffMean;

  double? get playoffMinusRegular =>
      regularMean == null || playoffMean == null
          ? null
          : playoffMean! - regularMean!;
}

class NbaPlayerCareerSeasonTypeDeltaResult {
  const NbaPlayerCareerSeasonTypeDeltaResult({
    required this.metric,
    required this.left,
    required this.right,
  });

  final NbaPlayerCareerMetric metric;
  final NbaPlayerCareerSeasonTypeMetricSummary left;
  final NbaPlayerCareerSeasonTypeMetricSummary right;

  double? get deltaDifference {
    final leftDelta = left.playoffMinusRegular;
    final rightDelta = right.playoffMinusRegular;
    if (leftDelta == null || rightDelta == null) return null;
    return leftDelta - rightDelta;
  }
}

/// Compares each Player's observed Regular Season and Playoffs career samples.
///
/// The samples are loaded independently and are not forced into matched years.
/// This reports only observed mean differences; it is not a postseason uplift
/// model and does not adjust for opponent quality, role, minutes, era or pace.
class NbaPlayerCareerSeasonTypeDeltaEngine {
  const NbaPlayerCareerSeasonTypeDeltaEngine();

  NbaPlayerCareerSeasonTypeDeltaResult build({
    required NbaPlayerCareerSnapshot leftRegular,
    required NbaPlayerCareerSnapshot leftPlayoffs,
    required NbaPlayerCareerSnapshot rightRegular,
    required NbaPlayerCareerSnapshot rightPlayoffs,
    NbaPlayerCareerMetric metric = NbaPlayerCareerMetric.pointsPerGame,
  }) {
    return NbaPlayerCareerSeasonTypeDeltaResult(
      metric: metric,
      left: _summary(leftRegular, leftPlayoffs, metric),
      right: _summary(rightRegular, rightPlayoffs, metric),
    );
  }

  NbaPlayerCareerSeasonTypeMetricSummary _summary(
    NbaPlayerCareerSnapshot regular,
    NbaPlayerCareerSnapshot playoffs,
    NbaPlayerCareerMetric metric,
  ) {
    final engine = const NbaPlayerCareerAnalyticsEngine();
    final regularResult = engine.build(regular, metric: metric);
    final playoffResult = engine.build(playoffs, metric: metric);
    return NbaPlayerCareerSeasonTypeMetricSummary(
      regularObserved: regularResult.distribution.observed,
      playoffObserved: playoffResult.distribution.observed,
      regularMean: regularResult.distribution.mean,
      playoffMean: playoffResult.distribution.mean,
    );
  }
}
