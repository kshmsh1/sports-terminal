import 'dart:math' as math;

import 'nba_season_intelligence_engine.dart';
import 'nba_terminal_seed_repository.dart';

enum NbaSeasonTeamDistributionMetric {
  winPct('WIN%', 'Win percentage'),
  pointsFor('PF/G', 'Points for per game'),
  pointsAgainst('PA/G', 'Points against per game'),
  differential('DIFF', 'Average scoring differential');

  const NbaSeasonTeamDistributionMetric(this.label, this.description);
  final String label;
  final String description;
}

class NbaSeasonTeamDistributionEngine {
  const NbaSeasonTeamDistributionEngine();

  NbaSeasonTeamDistributionResult build(
    NbaTerminalSeedSnapshot seed, {
    required String seasonId,
    String seasonType = 'Regular Season',
    NbaSeasonTeamDistributionMetric metric =
        NbaSeasonTeamDistributionMetric.differential,
  }) {
    final season = const NbaSeasonIntelligenceEngine().build(
      seed,
      seasonId: seasonId,
      seasonType: seasonType,
    );
    final observations = [
      for (final standing in season.standings)
        if (standing.games > 0)
          NbaSeasonTeamDistributionObservation(
            teamId: standing.teamId,
            teamName: standing.teamName,
            abbreviation: standing.abbreviation,
            games: standing.games,
            value: _value(standing, metric),
          ),
    ]..sort((left, right) {
        final compared = left.value.compareTo(right.value);
        if (compared != 0) return compared;
        return left.abbreviation.compareTo(right.abbreviation);
      });
    final values = [for (final row in observations) row.value];

    return NbaSeasonTeamDistributionResult(
      seasonId: seasonId,
      seasonType: seasonType,
      metric: metric,
      observations: List.unmodifiable(observations),
      mean: _mean(values),
      median: _quantile(values, .5),
      lowerQuartile: _quantile(values, .25),
      upperQuartile: _quantile(values, .75),
      minimum: values.isEmpty ? null : values.first,
      maximum: values.isEmpty ? null : values.last,
      standardDeviation: _standardDeviation(values),
      datasetStatus: season.datasetStatus,
      validationStatus: season.validationStatus,
      historicalContext: season.historicalContext,
      usedFallbackDataset: season.usedFallbackDataset,
    );
  }
}

class NbaSeasonTeamDistributionResult {
  const NbaSeasonTeamDistributionResult({
    required this.seasonId,
    required this.seasonType,
    required this.metric,
    required this.observations,
    required this.mean,
    required this.median,
    required this.lowerQuartile,
    required this.upperQuartile,
    required this.minimum,
    required this.maximum,
    required this.standardDeviation,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String seasonId;
  final String seasonType;
  final NbaSeasonTeamDistributionMetric metric;
  final List<NbaSeasonTeamDistributionObservation> observations;
  final double? mean;
  final double? median;
  final double? lowerQuartile;
  final double? upperQuartile;
  final double? minimum;
  final double? maximum;
  final double? standardDeviation;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  bool get hasObservations => observations.isNotEmpty;
  int get teamCount => observations.length;
  double? get spread =>
      minimum == null || maximum == null ? null : maximum! - minimum!;
}

class NbaSeasonTeamDistributionObservation {
  const NbaSeasonTeamDistributionObservation({
    required this.teamId,
    required this.teamName,
    required this.abbreviation,
    required this.games,
    required this.value,
  });

  final String teamId;
  final String teamName;
  final String abbreviation;
  final int games;
  final double value;
}

double _value(
  NbaSeasonTeamStanding standing,
  NbaSeasonTeamDistributionMetric metric,
) =>
    switch (metric) {
      NbaSeasonTeamDistributionMetric.winPct => standing.winPct,
      NbaSeasonTeamDistributionMetric.pointsFor => standing.averagePointsFor,
      NbaSeasonTeamDistributionMetric.pointsAgainst =>
        standing.averagePointsAgainst,
      NbaSeasonTeamDistributionMetric.differential =>
        standing.averageDifferential,
    };

double? _mean(List<double> values) =>
    values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

double? _quantile(List<double> sortedValues, double percentile) {
  if (sortedValues.isEmpty) return null;
  if (sortedValues.length == 1) return sortedValues.single;
  final position = (sortedValues.length - 1) * percentile;
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return sortedValues[lower];
  final weight = position - lower;
  return sortedValues[lower] * (1 - weight) + sortedValues[upper] * weight;
}

double? _standardDeviation(List<double> values) {
  final mean = _mean(values);
  if (mean == null || values.length < 2) return values.isEmpty ? null : 0;
  final variance = values
          .map((value) => math.pow(value - mean, 2).toDouble())
          .reduce((a, b) => a + b) /
      values.length;
  return math.sqrt(variance);
}
