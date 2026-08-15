import 'nba_game_schedule_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// Canonical season projection over the active NBA seed.
///
/// Standings below are derived only from explicit scored games in the selected
/// season scope. Scheduled/unscored games never affect records, and games from
/// another season ID never leak into the season object.
class NbaSeasonIntelligenceEngine {
  const NbaSeasonIntelligenceEngine();

  NbaSeasonIntelligenceSnapshot build(
    NbaTerminalSeedSnapshot seed, {
    required String seasonId,
    String seasonType = 'All',
  }) {
    final normalizedSeason = _normalize(seasonId);
    if (normalizedSeason.isEmpty) throw ArgumentError('seasonId is required.');
    final schedule = const NbaGameScheduleEngine().build(
      seed,
      seasonType: seasonType,
      ascending: true,
    );
    final games = schedule.rows
        .where((row) => _normalize(row.seasonId) == normalizedSeason)
        .toList(growable: false);
    final records = <String, _MutableRecord>{};
    for (final game in games) {
      if (game.awayTeamId.isNotEmpty) {
        records.putIfAbsent(
          _normalize(game.awayTeamId),
          () => _MutableRecord(
            teamId: game.awayTeamId,
            teamName: game.awayTeamName,
            abbreviation: game.awayTeamAbbreviation,
          ),
        );
      }
      if (game.homeTeamId.isNotEmpty) {
        records.putIfAbsent(
          _normalize(game.homeTeamId),
          () => _MutableRecord(
            teamId: game.homeTeamId,
            teamName: game.homeTeamName,
            abbreviation: game.homeTeamAbbreviation,
          ),
        );
      }
      if (!game.hasScore) continue;
      final away = records[_normalize(game.awayTeamId)];
      final home = records[_normalize(game.homeTeamId)];
      if (away == null || home == null) continue;
      away.games += 1;
      home.games += 1;
      away.pointsFor += game.awayScore!;
      away.pointsAgainst += game.homeScore!;
      home.pointsFor += game.homeScore!;
      home.pointsAgainst += game.awayScore!;
      if (game.awayScore! > game.homeScore!) {
        away.wins += 1;
        home.losses += 1;
      } else if (game.homeScore! > game.awayScore!) {
        home.wins += 1;
        away.losses += 1;
      } else {
        away.ties += 1;
        home.ties += 1;
      }
    }

    final standings = [
      for (final record in records.values) record.freeze(),
    ]
      ..sort((left, right) {
        final pct = right.winPct.compareTo(left.winPct);
        if (pct != 0) return pct;
        final diff = right.averageDifferential.compareTo(left.averageDifferential);
        if (diff != 0) return diff;
        return left.abbreviation.compareTo(right.abbreviation);
      });
    final dated = games.where((game) => game.parsedDate != null).toList();
    final regularGames = games.where(
      (game) => _normalizeSeasonType(game.seasonType) == 'regular_season',
    ).length;
    final playoffGames = games.where(
      (game) => _normalizeSeasonType(game.seasonType) == 'playoffs',
    ).length;

    return NbaSeasonIntelligenceSnapshot(
      seasonId: seasonId,
      seasonType: seasonType,
      games: List.unmodifiable(games),
      standings: List.unmodifiable(standings),
      completedGames: games.where((game) => game.hasScore).length,
      scheduledGames: games.where((game) => !game.hasScore).length,
      regularSeasonGames: regularGames,
      playoffGames: playoffGames,
      firstGameDate: dated.isEmpty ? null : dated.first.parsedDate,
      lastGameDate: dated.isEmpty ? null : dated.last.parsedDate,
      datasetStatus: schedule.datasetStatus,
      validationStatus: schedule.validationStatus,
      historicalContext: schedule.historicalContext,
      usedFallbackDataset: schedule.usedFallbackDataset,
    );
  }
}

class NbaSeasonIntelligenceSnapshot {
  const NbaSeasonIntelligenceSnapshot({
    required this.seasonId,
    required this.seasonType,
    required this.games,
    required this.standings,
    required this.completedGames,
    required this.scheduledGames,
    required this.regularSeasonGames,
    required this.playoffGames,
    required this.firstGameDate,
    required this.lastGameDate,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String seasonId;
  final String seasonType;
  final List<NbaGameScheduleRow> games;
  final List<NbaSeasonTeamStanding> standings;
  final int completedGames;
  final int scheduledGames;
  final int regularSeasonGames;
  final int playoffGames;
  final DateTime? firstGameDate;
  final DateTime? lastGameDate;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  int get gameCount => games.length;
  int get teamCount => standings.length;
  bool get hasGames => games.isNotEmpty;
  String get dateRangeLabel {
    String format(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    if (firstGameDate == null && lastGameDate == null) return '—';
    if (firstGameDate == lastGameDate || lastGameDate == null) {
      return format(firstGameDate!);
    }
    return '${format(firstGameDate!)} → ${format(lastGameDate!)}';
  }
}

class NbaSeasonTeamStanding {
  const NbaSeasonTeamStanding({
    required this.teamId,
    required this.teamName,
    required this.abbreviation,
    required this.games,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.pointsFor,
    required this.pointsAgainst,
  });

  final String teamId;
  final String teamName;
  final String abbreviation;
  final int games;
  final int wins;
  final int losses;
  final int ties;
  final int pointsFor;
  final int pointsAgainst;

  double get winPct => games == 0 ? 0 : wins / games;
  double get averagePointsFor => games == 0 ? 0 : pointsFor / games;
  double get averagePointsAgainst => games == 0 ? 0 : pointsAgainst / games;
  double get averageDifferential =>
      games == 0 ? 0 : (pointsFor - pointsAgainst) / games;
  String get recordLabel => '$wins-$losses${ties > 0 ? '-$ties' : ''}';
}

class _MutableRecord {
  _MutableRecord({
    required this.teamId,
    required this.teamName,
    required this.abbreviation,
  });

  final String teamId;
  final String teamName;
  final String abbreviation;
  int games = 0;
  int wins = 0;
  int losses = 0;
  int ties = 0;
  int pointsFor = 0;
  int pointsAgainst = 0;

  NbaSeasonTeamStanding freeze() => NbaSeasonTeamStanding(
        teamId: teamId,
        teamName: teamName,
        abbreviation: abbreviation,
        games: games,
        wins: wins,
        losses: losses,
        ties: ties,
        pointsFor: pointsFor,
        pointsAgainst: pointsAgainst,
      );
}

String _normalize(String value) => value.trim().toUpperCase();

String _normalizeSeasonType(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
  if (normalized.contains('postseason') || normalized.contains('playoff')) {
    return 'playoffs';
  }
  if (normalized == 'regular' || normalized.contains('regular_season')) {
    return 'regular_season';
  }
  return normalized;
}
