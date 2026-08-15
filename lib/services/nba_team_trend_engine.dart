import 'nba_game_schedule_engine.dart';
import 'nba_terminal_seed_repository.dart';

enum NbaTeamTrendMetric {
  pointsFor('PTS FOR'),
  pointsAgainst('PTS AGAINST'),
  differential('DIFF');

  const NbaTeamTrendMetric(this.label);
  final String label;
}

class NbaTeamTrendEngine {
  const NbaTeamTrendEngine();

  NbaTeamTrendResult build(
    NbaTerminalSeedSnapshot seed, {
    required String teamId,
    String seasonType = 'Regular Season',
    NbaTeamTrendMetric metric = NbaTeamTrendMetric.differential,
    int rollingWindow = 5,
    int? maxGames = 20,
  }) {
    if (teamId.trim().isEmpty) throw ArgumentError('teamId is required.');
    if (rollingWindow <= 0) {
      throw ArgumentError.value(rollingWindow, 'rollingWindow', 'must be positive');
    }
    final schedule = const NbaGameScheduleEngine().build(
      seed,
      teamId: teamId,
      seasonType: seasonType,
      ascending: true,
    );
    var games = schedule.rows.where((row) => row.hasScore).toList();
    if (maxGames != null && maxGames >= 0 && games.length > maxGames) {
      games = games.sublist(games.length - maxGames);
    }
    final normalizedTeam = teamId.trim().toUpperCase();
    final observations = <NbaTeamTrendObservation>[];

    for (var index = 0; index < games.length; index++) {
      final game = games[index];
      final isHome = game.homeTeamId.trim().toUpperCase() == normalizedTeam;
      final teamScore = isHome ? game.homeScore! : game.awayScore!;
      final opponentScore = isHome ? game.awayScore! : game.homeScore!;
      final value = switch (metric) {
        NbaTeamTrendMetric.pointsFor => teamScore.toDouble(),
        NbaTeamTrendMetric.pointsAgainst => opponentScore.toDouble(),
        NbaTeamTrendMetric.differential => (teamScore - opponentScore).toDouble(),
      };
      final start = index - rollingWindow + 1;
      final window = games.sublist(start < 0 ? 0 : start, index + 1);
      final windowValues = <double>[];
      for (final candidate in window) {
        final home = candidate.homeTeamId.trim().toUpperCase() == normalizedTeam;
        final scored = home ? candidate.homeScore! : candidate.awayScore!;
        final allowed = home ? candidate.awayScore! : candidate.homeScore!;
        windowValues.add(switch (metric) {
          NbaTeamTrendMetric.pointsFor => scored.toDouble(),
          NbaTeamTrendMetric.pointsAgainst => allowed.toDouble(),
          NbaTeamTrendMetric.differential => (scored - allowed).toDouble(),
        });
      }
      observations.add(
        NbaTeamTrendObservation(
          gameId: game.gameId,
          gameDate: game.gameDate,
          parsedDate: game.parsedDate,
          opponentId: isHome ? game.awayTeamId : game.homeTeamId,
          opponentLabel: isHome
              ? game.awayTeamAbbreviation
              : game.homeTeamAbbreviation,
          home: isHome,
          teamScore: teamScore,
          opponentScore: opponentScore,
          value: value,
          rollingAverage:
              windowValues.reduce((a, b) => a + b) / windowValues.length,
          rollingSampleSize: windowValues.length,
          sourceId: game.sourceId,
        ),
      );
    }

    final values = observations.map((row) => row.value).toList();
    final average = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final recent = observations.reversed.take(5).toList().reversed.toList();
    final wins = recent.where((row) => row.won).length;
    final losses = recent.where((row) => row.lost).length;
    final ties = recent.length - wins - losses;
    final recentDifferentials = [
      for (final row in recent) (row.teamScore - row.opponentScore).toDouble(),
    ];
    final recentAverageDifferential = recentDifferentials.isEmpty
        ? null
        : recentDifferentials.reduce((a, b) => a + b) /
            recentDifferentials.length;

    return NbaTeamTrendResult(
      teamId: teamId,
      seasonType: seasonType,
      metric: metric,
      rollingWindow: rollingWindow,
      observations: List.unmodifiable(observations),
      average: average,
      recentWins: wins,
      recentLosses: losses,
      recentTies: ties,
      recentAverageDifferential: recentAverageDifferential,
      currentStreak: _streak(observations),
      datasetStatus: schedule.datasetStatus,
      validationStatus: schedule.validationStatus,
      historicalContext: schedule.historicalContext,
      usedFallbackDataset: schedule.usedFallbackDataset,
    );
  }

  String _streak(List<NbaTeamTrendObservation> observations) {
    if (observations.isEmpty) return '—';
    final last = observations.last;
    final kind = last.won ? 'W' : last.lost ? 'L' : 'T';
    var count = 0;
    for (final row in observations.reversed) {
      final rowKind = row.won ? 'W' : row.lost ? 'L' : 'T';
      if (rowKind != kind) break;
      count += 1;
    }
    return '$kind$count';
  }
}

class NbaTeamTrendResult {
  const NbaTeamTrendResult({
    required this.teamId,
    required this.seasonType,
    required this.metric,
    required this.rollingWindow,
    required this.observations,
    required this.average,
    required this.recentWins,
    required this.recentLosses,
    required this.recentTies,
    required this.recentAverageDifferential,
    required this.currentStreak,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String teamId;
  final String seasonType;
  final NbaTeamTrendMetric metric;
  final int rollingWindow;
  final List<NbaTeamTrendObservation> observations;
  final double? average;
  final int recentWins;
  final int recentLosses;
  final int recentTies;
  final double? recentAverageDifferential;
  final String currentStreak;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  int get completedGames => observations.length;
  String get recentRecord =>
      '$recentWins-$recentLosses${recentTies > 0 ? '-$recentTies' : ''}';
}

class NbaTeamTrendObservation {
  const NbaTeamTrendObservation({
    required this.gameId,
    required this.gameDate,
    required this.parsedDate,
    required this.opponentId,
    required this.opponentLabel,
    required this.home,
    required this.teamScore,
    required this.opponentScore,
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
  final bool home;
  final int teamScore;
  final int opponentScore;
  final double value;
  final double rollingAverage;
  final int rollingSampleSize;
  final String sourceId;

  bool get won => teamScore > opponentScore;
  bool get lost => teamScore < opponentScore;
  String get resultLabel =>
      '${won ? 'W' : lost ? 'L' : 'T'} $teamScore–$opponentScore';
  String get matchupLabel => '${home ? 'vs' : '@'} $opponentLabel';
}
