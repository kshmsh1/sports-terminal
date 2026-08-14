import 'nba_game_schedule_engine.dart';
import 'nba_season_intelligence_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// Evidence-bounded playoff matchup projection.
///
/// Games are grouped only by the two canonical team IDs exposed by the season
/// schedule. The engine deliberately does not infer playoff rounds, seeds,
/// elimination state, best-of-seven completion, or bracket advancement unless
/// those concepts are explicitly supplied by a future certified dataset.
class NbaSeasonPlayoffSeriesEngine {
  const NbaSeasonPlayoffSeriesEngine();

  NbaSeasonPlayoffSeriesResult build(
    NbaTerminalSeedSnapshot seed, {
    required String seasonId,
  }) {
    final season = const NbaSeasonIntelligenceEngine().build(
      seed,
      seasonId: seasonId,
      seasonType: 'Playoffs',
    );
    final builders = <String, _SeriesBuilder>{};
    for (final game in season.games) {
      final away = _team(
        id: game.awayTeamId,
        name: game.awayTeamName,
        abbreviation: game.awayTeamAbbreviation,
      );
      final home = _team(
        id: game.homeTeamId,
        name: game.homeTeamName,
        abbreviation: game.homeTeamAbbreviation,
      );
      if (away.id.isEmpty || home.id.isEmpty || away.id == home.id) continue;
      final ordered = [away, home]..sort((a, b) => a.id.compareTo(b.id));
      final key = '${ordered.first.id}__${ordered.last.id}';
      final builder = builders.putIfAbsent(
        key,
        () => _SeriesBuilder(teamA: ordered.first, teamB: ordered.last),
      );
      builder.games.add(game);
      if (!game.hasScore) {
        builder.scheduledGames += 1;
        continue;
      }
      builder.completedGames += 1;
      final winner = game.homeScore! > game.awayScore!
          ? _normalize(game.homeTeamId)
          : game.awayScore! > game.homeScore!
              ? _normalize(game.awayTeamId)
              : '';
      if (winner == builder.teamA.id) {
        builder.teamAWins += 1;
      } else if (winner == builder.teamB.id) {
        builder.teamBWins += 1;
      } else {
        builder.ties += 1;
      }
    }

    final series = [for (final builder in builders.values) builder.freeze()]
      ..sort((left, right) {
        final l = left.latestGameDate;
        final r = right.latestGameDate;
        if (l == null && r == null) return left.matchupLabel.compareTo(right.matchupLabel);
        if (l == null) return 1;
        if (r == null) return -1;
        return r.compareTo(l);
      });

    return NbaSeasonPlayoffSeriesResult(
      seasonId: seasonId,
      series: List.unmodifiable(series),
      playoffGameCount: season.gameCount,
      completedGames: season.completedGames,
      scheduledGames: season.scheduledGames,
      datasetStatus: season.datasetStatus,
      validationStatus: season.validationStatus,
      historicalContext: season.historicalContext,
      usedFallbackDataset: season.usedFallbackDataset,
    );
  }
}

class NbaSeasonPlayoffSeriesResult {
  const NbaSeasonPlayoffSeriesResult({
    required this.seasonId,
    required this.series,
    required this.playoffGameCount,
    required this.completedGames,
    required this.scheduledGames,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String seasonId;
  final List<NbaObservedPlayoffSeries> series;
  final int playoffGameCount;
  final int completedGames;
  final int scheduledGames;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  bool get available => playoffGameCount > 0;
  int get observedMatchups => series.length;
  String get methodologyLabel =>
      'Observed canonical playoff matchups only; rounds and advancement are not inferred.';
}

class NbaObservedPlayoffSeries {
  const NbaObservedPlayoffSeries({
    required this.teamA,
    required this.teamB,
    required this.teamAWins,
    required this.teamBWins,
    required this.ties,
    required this.completedGames,
    required this.scheduledGames,
    required this.games,
    required this.latestGameDate,
  });

  final NbaSeasonPlayoffTeam teamA;
  final NbaSeasonPlayoffTeam teamB;
  final int teamAWins;
  final int teamBWins;
  final int ties;
  final int completedGames;
  final int scheduledGames;
  final List<NbaGameScheduleRow> games;
  final DateTime? latestGameDate;

  String get matchupLabel => '${teamA.abbreviation} vs ${teamB.abbreviation}';
  String get observedRecordLabel =>
      '$teamAWins-$teamBWins${ties > 0 ? '-$ties' : ''}';
  String get leaderTeamId {
    if (teamAWins == teamBWins) return '';
    return teamAWins > teamBWins ? teamA.id : teamB.id;
  }

  String get leaderLabel {
    if (completedGames == 0) return 'No completed games';
    if (teamAWins == teamBWins) return 'Observed series tied $teamAWins-$teamBWins';
    final leader = teamAWins > teamBWins ? teamA : teamB;
    final wins = teamAWins > teamBWins ? teamAWins : teamBWins;
    final losses = teamAWins > teamBWins ? teamBWins : teamAWins;
    return '${leader.abbreviation} leads observed games $wins-$losses';
  }
}

class NbaSeasonPlayoffTeam {
  const NbaSeasonPlayoffTeam({
    required this.id,
    required this.name,
    required this.abbreviation,
  });

  final String id;
  final String name;
  final String abbreviation;
}

class _SeriesBuilder {
  _SeriesBuilder({required this.teamA, required this.teamB});

  final NbaSeasonPlayoffTeam teamA;
  final NbaSeasonPlayoffTeam teamB;
  final List<NbaGameScheduleRow> games = [];
  int teamAWins = 0;
  int teamBWins = 0;
  int ties = 0;
  int completedGames = 0;
  int scheduledGames = 0;

  NbaObservedPlayoffSeries freeze() {
    final orderedGames = [...games]
      ..sort((a, b) {
        final left = a.parsedDate;
        final right = b.parsedDate;
        if (left == null && right == null) return a.gameId.compareTo(b.gameId);
        if (left == null) return 1;
        if (right == null) return -1;
        return left.compareTo(right);
      });
    DateTime? latest;
    for (final game in orderedGames) {
      if (game.parsedDate != null) latest = game.parsedDate;
    }
    return NbaObservedPlayoffSeries(
      teamA: teamA,
      teamB: teamB,
      teamAWins: teamAWins,
      teamBWins: teamBWins,
      ties: ties,
      completedGames: completedGames,
      scheduledGames: scheduledGames,
      games: List.unmodifiable(orderedGames),
      latestGameDate: latest,
    );
  }
}

NbaSeasonPlayoffTeam _team({
  required String id,
  required String name,
  required String abbreviation,
}) {
  final normalizedId = _normalize(id);
  return NbaSeasonPlayoffTeam(
    id: normalizedId,
    name: name.trim().isEmpty ? normalizedId : name.trim(),
    abbreviation:
        abbreviation.trim().isEmpty ? normalizedId : abbreviation.trim().toUpperCase(),
  );
}

String _normalize(String value) => value.trim().toUpperCase();
