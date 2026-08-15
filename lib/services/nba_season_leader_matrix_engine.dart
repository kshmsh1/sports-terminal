import 'nba_season_player_leader_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// Builds a multi-metric player leader matrix for one explicit Season scope.
///
/// Every metric column delegates to [NbaSeasonPlayerLeaderEngine], preserving
/// its season-type isolation, minimum-games qualification, and metric evidence
/// checks. A player appears in the matrix only if they are actually ranked in
/// the requested top-N for at least one selected metric.
class NbaSeasonLeaderMatrixEngine {
  const NbaSeasonLeaderMatrixEngine();

  NbaSeasonLeaderMatrixResult build(
    NbaTerminalSeedSnapshot seed, {
    required String seasonId,
    String seasonType = 'Regular Season',
    List<NbaSeasonLeaderMetric> metrics = NbaSeasonLeaderMetric.values,
    int topPerMetric = 5,
    double minimumGames = 0,
  }) {
    final normalizedSeason = seasonId.trim();
    if (normalizedSeason.isEmpty) {
      throw ArgumentError.value(seasonId, 'seasonId', 'Season is required.');
    }
    final boundedTop = topPerMetric.clamp(1, 25);
    final uniqueMetrics = <NbaSeasonLeaderMetric>[];
    for (final metric in metrics) {
      if (!uniqueMetrics.contains(metric)) uniqueMetrics.add(metric);
    }

    final columns = <NbaSeasonLeaderMatrixColumn>[];
    final players = <String, _MutableMatrixPlayer>{};
    for (final metric in uniqueMetrics) {
      final ranking = const NbaSeasonPlayerLeaderEngine().build(
        seed,
        seasonId: normalizedSeason,
        seasonType: seasonType,
        metric: metric,
        limit: 100,
        minimumGames: minimumGames,
      );
      final leaders = ranking.leaders.take(boundedTop).toList(growable: false);
      columns.add(
        NbaSeasonLeaderMatrixColumn(
          metric: metric,
          eligiblePlayers: ranking.eligiblePlayers,
          leaders: List.unmodifiable(leaders),
        ),
      );
      for (final leader in leaders) {
        final key = leader.playerId.trim().isNotEmpty
            ? leader.playerId.trim().toUpperCase()
            : leader.playerName.trim().toUpperCase();
        if (key.isEmpty) continue;
        final player = players.putIfAbsent(
          key,
          () => _MutableMatrixPlayer(
            playerId: leader.playerId,
            playerName: leader.playerName,
            teamLabel: leader.teamLabel,
            position: leader.position,
            games: leader.games,
          ),
        );
        player.cells[metric] = NbaSeasonLeaderMatrixCell(
          metric: metric,
          rank: leader.rank,
          value: leader.value,
        );
      }
    }

    final matrixRows = players.values.map((player) => player.freeze()).toList()
      ..sort((left, right) {
        final leftBest = left.bestRank ?? 1 << 30;
        final rightBest = right.bestRank ?? 1 << 30;
        if (leftBest != rightBest) return leftBest.compareTo(rightBest);
        return left.playerName.compareTo(right.playerName);
      });

    return NbaSeasonLeaderMatrixResult(
      seasonId: normalizedSeason,
      seasonType: seasonType,
      topPerMetric: boundedTop,
      minimumGames: minimumGames,
      columns: List.unmodifiable(columns),
      players: List.unmodifiable(matrixRows),
      datasetStatus: seed.datasetStatus,
      validationStatus: seed.validationStatus,
      historicalContext: seed.isHistorical,
      usedFallbackDataset: seed.usedFallback,
    );
  }
}

class NbaSeasonLeaderMatrixResult {
  const NbaSeasonLeaderMatrixResult({
    required this.seasonId,
    required this.seasonType,
    required this.topPerMetric,
    required this.minimumGames,
    required this.columns,
    required this.players,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String seasonId;
  final String seasonType;
  final int topPerMetric;
  final double minimumGames;
  final List<NbaSeasonLeaderMatrixColumn> columns;
  final List<NbaSeasonLeaderMatrixPlayer> players;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  bool get hasLeaders => players.isNotEmpty;
  int get metricCount => columns.length;
}

class NbaSeasonLeaderMatrixColumn {
  const NbaSeasonLeaderMatrixColumn({
    required this.metric,
    required this.eligiblePlayers,
    required this.leaders,
  });

  final NbaSeasonLeaderMetric metric;
  final int eligiblePlayers;
  final List<NbaSeasonPlayerLeader> leaders;
}

class NbaSeasonLeaderMatrixPlayer {
  const NbaSeasonLeaderMatrixPlayer({
    required this.playerId,
    required this.playerName,
    required this.teamLabel,
    required this.position,
    required this.games,
    required this.cells,
  });

  final String playerId;
  final String playerName;
  final String teamLabel;
  final String position;
  final double games;
  final Map<NbaSeasonLeaderMetric, NbaSeasonLeaderMatrixCell> cells;

  int? get bestRank {
    if (cells.isEmpty) return null;
    return cells.values.map((cell) => cell.rank).reduce(
          (left, right) => left < right ? left : right,
        );
  }
}

class NbaSeasonLeaderMatrixCell {
  const NbaSeasonLeaderMatrixCell({
    required this.metric,
    required this.rank,
    required this.value,
  });

  final NbaSeasonLeaderMetric metric;
  final int rank;
  final double value;
}

class _MutableMatrixPlayer {
  _MutableMatrixPlayer({
    required this.playerId,
    required this.playerName,
    required this.teamLabel,
    required this.position,
    required this.games,
  });

  final String playerId;
  final String playerName;
  final String teamLabel;
  final String position;
  final double games;
  final Map<NbaSeasonLeaderMetric, NbaSeasonLeaderMatrixCell> cells = {};

  NbaSeasonLeaderMatrixPlayer freeze() => NbaSeasonLeaderMatrixPlayer(
        playerId: playerId,
        playerName: playerName,
        teamLabel: teamLabel,
        position: position,
        games: games,
        cells: Map.unmodifiable(cells),
      );
}
