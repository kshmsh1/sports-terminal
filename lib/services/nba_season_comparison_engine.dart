import 'nba_season_intelligence_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// Compares two explicitly selected canonical NBA seasons.
///
/// The caller supplies both season identities and their seed snapshots. This
/// engine never guesses an adjacent/previous season and never backfills teams
/// that are absent from either canonical season. Performance is derived only
/// from scored games through [NbaSeasonIntelligenceEngine].
class NbaSeasonComparisonEngine {
  const NbaSeasonComparisonEngine();

  NbaSeasonComparisonResult build({
    required NbaTerminalSeedSnapshot leftSeed,
    required String leftSeasonId,
    required NbaTerminalSeedSnapshot rightSeed,
    required String rightSeasonId,
    String seasonType = 'Regular Season',
  }) {
    final left = const NbaSeasonIntelligenceEngine().build(
      leftSeed,
      seasonId: leftSeasonId,
      seasonType: seasonType,
    );
    final right = const NbaSeasonIntelligenceEngine().build(
      rightSeed,
      seasonId: rightSeasonId,
      seasonType: seasonType,
    );
    final leftByTeam = {
      for (final row in left.standings) _normalize(row.teamId): row,
    };
    final rightByTeam = {
      for (final row in right.standings) _normalize(row.teamId): row,
    };
    final commonKeys = leftByTeam.keys.toSet().intersection(rightByTeam.keys.toSet())
      ..removeWhere((key) => key.isEmpty);
    final common = <NbaSeasonTeamComparison>[];
    for (final key in commonKeys) {
      final l = leftByTeam[key]!;
      final r = rightByTeam[key]!;
      common.add(
        NbaSeasonTeamComparison(
          teamId: r.teamId.isNotEmpty ? r.teamId : l.teamId,
          teamName: r.teamName.isNotEmpty ? r.teamName : l.teamName,
          abbreviation: r.abbreviation.isNotEmpty ? r.abbreviation : l.abbreviation,
          leftGames: l.games,
          rightGames: r.games,
          leftWinPct: l.winPct,
          rightWinPct: r.winPct,
          leftPointsFor: l.averagePointsFor,
          rightPointsFor: r.averagePointsFor,
          leftPointsAgainst: l.averagePointsAgainst,
          rightPointsAgainst: r.averagePointsAgainst,
          leftDifferential: l.averageDifferential,
          rightDifferential: r.averageDifferential,
        ),
      );
    }
    common.sort((a, b) {
      final compared = b.differentialDelta.compareTo(a.differentialDelta);
      if (compared != 0) return compared;
      return a.abbreviation.compareTo(b.abbreviation);
    });

    final onlyLeft = [
      for (final key in leftByTeam.keys)
        if (!rightByTeam.containsKey(key)) leftByTeam[key]!,
    ]..sort((a, b) => a.abbreviation.compareTo(b.abbreviation));
    final onlyRight = [
      for (final key in rightByTeam.keys)
        if (!leftByTeam.containsKey(key)) rightByTeam[key]!,
    ]..sort((a, b) => a.abbreviation.compareTo(b.abbreviation));

    return NbaSeasonComparisonResult(
      leftSeasonId: leftSeasonId,
      rightSeasonId: rightSeasonId,
      seasonType: seasonType,
      left: _aggregate(left),
      right: _aggregate(right),
      commonTeams: List.unmodifiable(common),
      onlyLeftTeams: List.unmodifiable(onlyLeft),
      onlyRightTeams: List.unmodifiable(onlyRight),
      leftDatasetStatus: left.datasetStatus,
      rightDatasetStatus: right.datasetStatus,
      leftHistorical: left.historicalContext,
      rightHistorical: right.historicalContext,
    );
  }

  NbaSeasonComparisonAggregate _aggregate(NbaSeasonIntelligenceSnapshot season) {
    final scored = season.standings.where((row) => row.games > 0).toList();
    double average(double Function(NbaSeasonTeamStanding row) value) =>
        scored.isEmpty ? 0 : scored.map(value).reduce((a, b) => a + b) / scored.length;
    return NbaSeasonComparisonAggregate(
      seasonId: season.seasonId,
      completedGames: season.completedGames,
      scheduledGames: season.scheduledGames,
      teamCount: scored.length,
      averageWinPct: average((row) => row.winPct),
      averagePointsFor: average((row) => row.averagePointsFor),
      averagePointsAgainst: average((row) => row.averagePointsAgainst),
      averageDifferential: average((row) => row.averageDifferential),
    );
  }
}

class NbaSeasonComparisonResult {
  const NbaSeasonComparisonResult({
    required this.leftSeasonId,
    required this.rightSeasonId,
    required this.seasonType,
    required this.left,
    required this.right,
    required this.commonTeams,
    required this.onlyLeftTeams,
    required this.onlyRightTeams,
    required this.leftDatasetStatus,
    required this.rightDatasetStatus,
    required this.leftHistorical,
    required this.rightHistorical,
  });

  final String leftSeasonId;
  final String rightSeasonId;
  final String seasonType;
  final NbaSeasonComparisonAggregate left;
  final NbaSeasonComparisonAggregate right;
  final List<NbaSeasonTeamComparison> commonTeams;
  final List<NbaSeasonTeamStanding> onlyLeftTeams;
  final List<NbaSeasonTeamStanding> onlyRightTeams;
  final String leftDatasetStatus;
  final String rightDatasetStatus;
  final bool leftHistorical;
  final bool rightHistorical;

  bool get hasComparableTeams => commonTeams.isNotEmpty;
  int get commonTeamCount => commonTeams.length;
  double get leaguePointsForDelta => right.averagePointsFor - left.averagePointsFor;
  double get leaguePointsAgainstDelta =>
      right.averagePointsAgainst - left.averagePointsAgainst;
}

class NbaSeasonComparisonAggregate {
  const NbaSeasonComparisonAggregate({
    required this.seasonId,
    required this.completedGames,
    required this.scheduledGames,
    required this.teamCount,
    required this.averageWinPct,
    required this.averagePointsFor,
    required this.averagePointsAgainst,
    required this.averageDifferential,
  });

  final String seasonId;
  final int completedGames;
  final int scheduledGames;
  final int teamCount;
  final double averageWinPct;
  final double averagePointsFor;
  final double averagePointsAgainst;
  final double averageDifferential;
}

class NbaSeasonTeamComparison {
  const NbaSeasonTeamComparison({
    required this.teamId,
    required this.teamName,
    required this.abbreviation,
    required this.leftGames,
    required this.rightGames,
    required this.leftWinPct,
    required this.rightWinPct,
    required this.leftPointsFor,
    required this.rightPointsFor,
    required this.leftPointsAgainst,
    required this.rightPointsAgainst,
    required this.leftDifferential,
    required this.rightDifferential,
  });

  final String teamId;
  final String teamName;
  final String abbreviation;
  final int leftGames;
  final int rightGames;
  final double leftWinPct;
  final double rightWinPct;
  final double leftPointsFor;
  final double rightPointsFor;
  final double leftPointsAgainst;
  final double rightPointsAgainst;
  final double leftDifferential;
  final double rightDifferential;

  double get winPctDelta => rightWinPct - leftWinPct;
  double get pointsForDelta => rightPointsFor - leftPointsFor;
  double get pointsAgainstDelta => rightPointsAgainst - leftPointsAgainst;
  double get differentialDelta => rightDifferential - leftDifferential;
}

String _normalize(String value) => value.trim().toUpperCase();
