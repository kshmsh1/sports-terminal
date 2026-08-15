import 'nba_player_game_log_engine.dart';
import 'nba_terminal_seed_repository.dart';

enum NbaPlayerTrendMetric {
  points('PTS'),
  rebounds('REB'),
  assists('AST'),
  steals('STL'),
  blocks('BLK'),
  turnovers('TOV'),
  plusMinus('+/-');

  const NbaPlayerTrendMetric(this.label);
  final String label;
}

class NbaPlayerTrendEngine {
  const NbaPlayerTrendEngine();

  NbaPlayerTrendResult build(
    NbaTerminalSeedSnapshot seed, {
    required String playerId,
    String playerName = '',
    String seasonType = 'Regular Season',
    NbaPlayerTrendMetric metric = NbaPlayerTrendMetric.points,
    int rollingWindow = 5,
    int? maxGames = 20,
  }) {
    if (rollingWindow <= 0) {
      throw ArgumentError.value(rollingWindow, 'rollingWindow', 'must be positive');
    }
    final log = const NbaPlayerGameLogEngine().build(
      seed,
      playerId: playerId,
      playerName: playerName,
      seasonType: seasonType,
      ascending: true,
    );
    var rows = log.rows.where((row) => row.linkedCanonicalGame).toList();
    if (maxGames != null && maxGames >= 0 && rows.length > maxGames) {
      rows = rows.sublist(rows.length - maxGames);
    }

    final observations = <NbaPlayerTrendObservation>[];
    final rollingValues = <double>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final value = _metricValue(row, metric)?.toDouble();
      if (value != null) rollingValues.add(value);
      final start = index - rollingWindow + 1;
      final windowRows = rows.sublist(start < 0 ? 0 : start, index + 1);
      final availableWindow = [
        for (final candidate in windowRows)
          if (_metricValue(candidate, metric) case final num value) value.toDouble(),
      ];
      final rollingAverage = availableWindow.isEmpty
          ? null
          : availableWindow.reduce((a, b) => a + b) / availableWindow.length;
      observations.add(
        NbaPlayerTrendObservation(
          gameId: row.gameId,
          gameDate: row.gameDate,
          parsedDate: row.parsedDate,
          opponentId: row.opponent.id,
          opponentLabel: row.opponent.abbreviation.isEmpty
              ? row.opponent.id
              : row.opponent.abbreviation,
          resultLabel: row.resultLabel,
          value: value,
          rollingAverage: rollingAverage,
          rollingSampleSize: availableWindow.length,
          sourceId: row.sourceId,
        ),
      );
    }

    final available = [
      for (final observation in observations)
        if (observation.value != null) observation.value!,
    ];
    final average = available.isEmpty
        ? null
        : available.reduce((a, b) => a + b) / available.length;
    final recentFive = observations.reversed
        .where((observation) => observation.value != null)
        .take(5)
        .map((observation) => observation.value!)
        .toList();
    final recentFiveAverage = recentFive.isEmpty
        ? null
        : recentFive.reduce((a, b) => a + b) / recentFive.length;
    final priorFive = observations.reversed
        .where((observation) => observation.value != null)
        .skip(5)
        .take(5)
        .map((observation) => observation.value!)
        .toList();
    final priorFiveAverage = priorFive.isEmpty
        ? null
        : priorFive.reduce((a, b) => a + b) / priorFive.length;

    return NbaPlayerTrendResult(
      playerId: playerId,
      playerName: playerName,
      seasonType: seasonType,
      metric: metric,
      rollingWindow: rollingWindow,
      observations: List.unmodifiable(observations),
      average: average,
      recentFiveAverage: recentFiveAverage,
      priorFiveAverage: priorFiveAverage,
      datasetStatus: log.datasetStatus,
      validationStatus: log.validationStatus,
      historicalContext: log.historicalContext,
      usedFallbackDataset: log.usedFallbackDataset,
      unlinkedRows: log.unlinkedRows,
    );
  }

  num? _metricValue(NbaPlayerGameLogRow row, NbaPlayerTrendMetric metric) {
    return switch (metric) {
      NbaPlayerTrendMetric.points => row.points,
      NbaPlayerTrendMetric.rebounds => row.rebounds,
      NbaPlayerTrendMetric.assists => row.assists,
      NbaPlayerTrendMetric.steals => row.steals,
      NbaPlayerTrendMetric.blocks => row.blocks,
      NbaPlayerTrendMetric.turnovers => row.turnovers,
      NbaPlayerTrendMetric.plusMinus => row.plusMinus,
    };
  }
}

class NbaPlayerTrendResult {
  const NbaPlayerTrendResult({
    required this.playerId,
    required this.playerName,
    required this.seasonType,
    required this.metric,
    required this.rollingWindow,
    required this.observations,
    required this.average,
    required this.recentFiveAverage,
    required this.priorFiveAverage,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
    required this.unlinkedRows,
  });

  final String playerId;
  final String playerName;
  final String seasonType;
  final NbaPlayerTrendMetric metric;
  final int rollingWindow;
  final List<NbaPlayerTrendObservation> observations;
  final double? average;
  final double? recentFiveAverage;
  final double? priorFiveAverage;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;
  final int unlinkedRows;

  int get availableObservations =>
      observations.where((observation) => observation.value != null).length;
  int get missingObservations => observations.length - availableObservations;
  double? get recentDelta =>
      recentFiveAverage == null || priorFiveAverage == null
          ? null
          : recentFiveAverage! - priorFiveAverage!;
  String get trendLabel {
    final delta = recentDelta;
    if (delta == null) return 'INSUFFICIENT HISTORY';
    if (delta.abs() < 0.05) return 'FLAT';
    return delta > 0 ? 'UP' : 'DOWN';
  }
}

class NbaPlayerTrendObservation {
  const NbaPlayerTrendObservation({
    required this.gameId,
    required this.gameDate,
    required this.parsedDate,
    required this.opponentId,
    required this.opponentLabel,
    required this.resultLabel,
    required this.value,
    required this.rollingAverage,
    required this.rollingSampleSize,
    required this.sourceId,
  });

  final String gameId;
  final String gameDate;
  final DateTime? parsedDate;
  final String opponentId;
  final String opponentLabel;
  final String resultLabel;
  final double? value;
  final double? rollingAverage;
  final int rollingSampleSize;
  final String sourceId;
}
