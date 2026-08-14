import 'nba_season_team_distribution_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// Places every scored-game-derived team observation inside its selected
/// season distribution. Percentiles are descriptive within this exact season;
/// they are not historical priors, power ratings, or modeled forecasts.
class NbaSeasonBenchmarkEngine {
  const NbaSeasonBenchmarkEngine();

  NbaSeasonBenchmarkResult build(
    NbaTerminalSeedSnapshot seed, {
    required String seasonId,
    String seasonType = 'Regular Season',
    NbaSeasonTeamDistributionMetric metric =
        NbaSeasonTeamDistributionMetric.differential,
  }) {
    final distribution = const NbaSeasonTeamDistributionEngine().build(
      seed,
      seasonId: seasonId,
      seasonType: seasonType,
      metric: metric,
    );
    final source = distribution.observations;
    final higherIsBetter = metric != NbaSeasonTeamDistributionMetric.pointsAgainst;
    final ranked = [...source]
      ..sort((a, b) {
        final comparison = higherIsBetter
            ? b.value.compareTo(a.value)
            : a.value.compareTo(b.value);
        if (comparison != 0) return comparison;
        return a.abbreviation.compareTo(b.abbreviation);
      });
    final rows = <NbaSeasonBenchmarkRow>[];
    for (var index = 0; index < ranked.length; index++) {
      final row = ranked[index];
      final better = source.where((candidate) => higherIsBetter
              ? candidate.value > row.value
              : candidate.value < row.value)
          .length;
      final equal = source.where((candidate) => candidate.value == row.value).length;
      final averageRank = better + 1 + (equal - 1) / 2;
      final percentile = source.length <= 1
          ? 100.0
          : ((source.length - averageRank) / (source.length - 1) * 100)
              .clamp(0.0, 100.0)
              .toDouble();
      rows.add(
        NbaSeasonBenchmarkRow(
          teamId: row.teamId,
          teamName: row.teamName,
          abbreviation: row.abbreviation,
          games: row.games,
          value: row.value,
          rank: better + 1,
          tiedTeams: equal,
          percentile: percentile,
          deltaFromMedian: distribution.median == null
              ? null
              : row.value - distribution.median!,
          deltaFromMean: distribution.mean == null
              ? null
              : row.value - distribution.mean!,
        ),
      );
    }
    rows.sort((a, b) {
      final rank = a.rank.compareTo(b.rank);
      if (rank != 0) return rank;
      return a.abbreviation.compareTo(b.abbreviation);
    });

    return NbaSeasonBenchmarkResult(
      seasonId: seasonId,
      seasonType: seasonType,
      metric: metric,
      rows: List.unmodifiable(rows),
      mean: distribution.mean,
      median: distribution.median,
      lowerQuartile: distribution.lowerQuartile,
      upperQuartile: distribution.upperQuartile,
      higherIsBetter: higherIsBetter,
      datasetStatus: distribution.datasetStatus,
      validationStatus: distribution.validationStatus,
      historicalContext: distribution.historicalContext,
      usedFallbackDataset: distribution.usedFallbackDataset,
    );
  }
}

class NbaSeasonBenchmarkResult {
  const NbaSeasonBenchmarkResult({
    required this.seasonId,
    required this.seasonType,
    required this.metric,
    required this.rows,
    required this.mean,
    required this.median,
    required this.lowerQuartile,
    required this.upperQuartile,
    required this.higherIsBetter,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String seasonId;
  final String seasonType;
  final NbaSeasonTeamDistributionMetric metric;
  final List<NbaSeasonBenchmarkRow> rows;
  final double? mean;
  final double? median;
  final double? lowerQuartile;
  final double? upperQuartile;
  final bool higherIsBetter;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  int get teamCount => rows.length;
  bool get available => rows.isNotEmpty;

  NbaSeasonBenchmarkRow? team(String teamId) {
    final normalized = teamId.trim().toUpperCase();
    for (final row in rows) {
      if (row.teamId.trim().toUpperCase() == normalized) return row;
    }
    return null;
  }
}

class NbaSeasonBenchmarkRow {
  const NbaSeasonBenchmarkRow({
    required this.teamId,
    required this.teamName,
    required this.abbreviation,
    required this.games,
    required this.value,
    required this.rank,
    required this.tiedTeams,
    required this.percentile,
    required this.deltaFromMedian,
    required this.deltaFromMean,
  });

  final String teamId;
  final String teamName;
  final String abbreviation;
  final int games;
  final double value;
  final int rank;
  final int tiedTeams;
  final double percentile;
  final double? deltaFromMedian;
  final double? deltaFromMean;

  String get rankLabel => tiedTeams > 1 ? 'T$rank' : '$rank';
}
