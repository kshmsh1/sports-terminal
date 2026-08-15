import 'nba_season_intelligence_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// Date-only schedule density for one explicit canonical NBA Season scope.
///
/// This engine uses calendar dates only. It does not infer travel, tip times,
/// time zones, fatigue, or performance effects. Scheduled games count toward
/// future schedule density when they have explicit dates, but never become
/// completed results or standings observations.
class NbaSeasonRestDensityEngine {
  const NbaSeasonRestDensityEngine();

  NbaSeasonRestDensityResult build(
    NbaTerminalSeedSnapshot seed, {
    required String seasonId,
    String seasonType = 'All',
  }) {
    final season = const NbaSeasonIntelligenceEngine().build(
      seed,
      seasonId: seasonId,
      seasonType: seasonType,
    );
    final builders = <String, _MutableRestDensity>{};

    for (final game in season.games) {
      void collect(String teamId, String name, String abbreviation, bool home) {
        final normalized = teamId.trim().toUpperCase();
        if (normalized.isEmpty) return;
        final builder = builders.putIfAbsent(
          normalized,
          () => _MutableRestDensity(
            teamId: teamId,
            teamName: name,
            abbreviation: abbreviation,
          ),
        );
        if (home) {
          builder.homeGames += 1;
        } else {
          builder.awayGames += 1;
        }
        final date = game.parsedDate;
        if (date == null) {
          builder.undatedGames += 1;
        } else {
          builder.dates.add(DateTime(date.year, date.month, date.day));
        }
      }

      collect(
        game.homeTeamId,
        game.homeTeamName,
        game.homeTeamAbbreviation,
        true,
      );
      collect(
        game.awayTeamId,
        game.awayTeamName,
        game.awayTeamAbbreviation,
        false,
      );
    }

    final teams = builders.values.map((builder) => builder.freeze()).toList()
      ..sort((left, right) {
        final leftLabel = left.abbreviation.isEmpty ? left.teamId : left.abbreviation;
        final rightLabel =
            right.abbreviation.isEmpty ? right.teamId : right.abbreviation;
        return leftLabel.compareTo(rightLabel);
      });

    return NbaSeasonRestDensityResult(
      seasonId: season.seasonId,
      seasonType: season.seasonType,
      teams: List.unmodifiable(teams),
      datasetStatus: season.datasetStatus,
      validationStatus: season.validationStatus,
      historicalContext: season.historicalContext,
      usedFallbackDataset: season.usedFallbackDataset,
    );
  }
}

class NbaSeasonRestDensityResult {
  const NbaSeasonRestDensityResult({
    required this.seasonId,
    required this.seasonType,
    required this.teams,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String seasonId;
  final String seasonType;
  final List<NbaSeasonRestDensityTeamProfile> teams;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  bool get hasTeams => teams.isNotEmpty;
  int get datedGamesAcrossTeamSchedules =>
      teams.fold(0, (total, team) => total + team.datedGames);
  int get undatedGamesAcrossTeamSchedules =>
      teams.fold(0, (total, team) => total + team.undatedGames);
  int get backToBackOccurrences =>
      teams.fold(0, (total, team) => total + team.backToBacks);
  int get maxObservedGamesInSevenDays => teams.isEmpty
      ? 0
      : teams
          .map((team) => team.maxGamesInSevenDays)
          .reduce((left, right) => left > right ? left : right);
}

class NbaSeasonRestDensityTeamProfile {
  const NbaSeasonRestDensityTeamProfile({
    required this.teamId,
    required this.teamName,
    required this.abbreviation,
    required this.datedGames,
    required this.undatedGames,
    required this.homeGames,
    required this.awayGames,
    required this.backToBacks,
    required this.oneDayRestOccurrences,
    required this.averageRestDays,
    required this.minimumRestDays,
    required this.maximumRestDays,
    required this.maxGamesInSevenDays,
    required this.fourPlusInSixDayWindows,
  });

  final String teamId;
  final String teamName;
  final String abbreviation;
  final int datedGames;
  final int undatedGames;
  final int homeGames;
  final int awayGames;
  final int backToBacks;
  final int oneDayRestOccurrences;
  final double? averageRestDays;
  final int? minimumRestDays;
  final int? maximumRestDays;
  final int maxGamesInSevenDays;
  final int fourPlusInSixDayWindows;

  int get totalGames => datedGames + undatedGames;
}

class _MutableRestDensity {
  _MutableRestDensity({
    required this.teamId,
    required this.teamName,
    required this.abbreviation,
  });

  final String teamId;
  final String teamName;
  final String abbreviation;
  final List<DateTime> dates = [];
  int undatedGames = 0;
  int homeGames = 0;
  int awayGames = 0;

  NbaSeasonRestDensityTeamProfile freeze() {
    dates.sort();
    final restDays = <int>[];
    var backToBacks = 0;
    var oneDayRestOccurrences = 0;
    for (var index = 1; index < dates.length; index++) {
      final calendarGap = dates[index].difference(dates[index - 1]).inDays;
      final rest = calendarGap <= 1 ? 0 : calendarGap - 1;
      restDays.add(rest);
      if (calendarGap == 1) backToBacks += 1;
      if (calendarGap == 2) oneDayRestOccurrences += 1;
    }

    var maxGamesInSevenDays = dates.isEmpty ? 0 : 1;
    var fourPlusInSixDayWindows = 0;
    for (var start = 0; start < dates.length; start++) {
      var sevenDayCount = 0;
      var sixDayCount = 0;
      for (var end = start; end < dates.length; end++) {
        final span = dates[end].difference(dates[start]).inDays;
        if (span <= 6) sevenDayCount += 1;
        if (span <= 5) sixDayCount += 1;
        if (span > 6) break;
      }
      if (sevenDayCount > maxGamesInSevenDays) {
        maxGamesInSevenDays = sevenDayCount;
      }
      if (sixDayCount >= 4) fourPlusInSixDayWindows += 1;
    }

    final averageRestDays = restDays.isEmpty
        ? null
        : restDays.reduce((left, right) => left + right) / restDays.length;
    final minimumRestDays = restDays.isEmpty
        ? null
        : restDays.reduce((left, right) => left < right ? left : right);
    final maximumRestDays = restDays.isEmpty
        ? null
        : restDays.reduce((left, right) => left > right ? left : right);

    return NbaSeasonRestDensityTeamProfile(
      teamId: teamId,
      teamName: teamName,
      abbreviation: abbreviation,
      datedGames: dates.length,
      undatedGames: undatedGames,
      homeGames: homeGames,
      awayGames: awayGames,
      backToBacks: backToBacks,
      oneDayRestOccurrences: oneDayRestOccurrences,
      averageRestDays: averageRestDays,
      minimumRestDays: minimumRestDays,
      maximumRestDays: maximumRestDays,
      maxGamesInSevenDays: maxGamesInSevenDays,
      fourPlusInSixDayWindows: fourPlusInSixDayWindows,
    );
  }
}
