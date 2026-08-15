import 'nba_franchise_intelligence_engine.dart';

class NbaFranchisePerformanceSeason {
  const NbaFranchisePerformanceSeason({
    required this.seasonId,
    required this.teamKeys,
    required this.teamLabels,
    required this.wins,
    required this.losses,
    required this.winPct,
  });

  final String seasonId;
  final List<String> teamKeys;
  final List<String> teamLabels;
  final int wins;
  final int losses;
  final double? winPct;

  int get decisions => wins + losses;
  String get recordLabel => decisions == 0 ? '—' : '$wins-$losses';
}

class NbaFranchisePerformanceResult {
  const NbaFranchisePerformanceResult({
    required this.franchiseKey,
    required this.franchiseName,
    required this.seasons,
    required this.totalWins,
    required this.totalLosses,
    required this.weightedWinPct,
    required this.bestSeason,
    required this.worstSeason,
    required this.regularSeasonRows,
    required this.playoffRowsExcluded,
  });

  final String franchiseKey;
  final String franchiseName;
  final List<NbaFranchisePerformanceSeason> seasons;
  final int totalWins;
  final int totalLosses;
  final double? weightedWinPct;
  final NbaFranchisePerformanceSeason? bestSeason;
  final NbaFranchisePerformanceSeason? worstSeason;
  final int regularSeasonRows;
  final int playoffRowsExcluded;

  bool get available => seasons.isNotEmpty;
  int get observedSeasons => seasons.length;
  int get totalDecisions => totalWins + totalLosses;

  String get methodologyLabel =>
      'Observed regular-season team-season rows only. Wins/losses are summed across canonical team identities sharing a franchise in the same season; playoffs, championships and advancement are not inferred.';
}

/// Aggregates source-backed regular-season observations across all canonical
/// team identities belonging to one Franchise.
class NbaFranchisePerformanceEngine {
  const NbaFranchisePerformanceEngine();

  NbaFranchisePerformanceResult build(NbaFranchiseIntelligenceSnapshot franchise) {
    final regularRows = franchise.seasons.where(_isRegular).toList(growable: false);
    final bySeason = <String, List<NbaFranchiseSeasonObservation>>{};
    for (final row in regularRows) {
      bySeason.putIfAbsent(row.seasonId, () => []).add(row);
    }

    final seasons = <NbaFranchisePerformanceSeason>[];
    for (final entry in bySeason.entries) {
      var wins = 0;
      var losses = 0;
      final teamKeys = <String>[];
      final teamLabels = <String>[];
      for (final row in entry.value) {
        wins += row.wins?.toInt() ?? 0;
        losses += row.losses?.toInt() ?? 0;
        if (row.teamKey.isNotEmpty && !teamKeys.contains(row.teamKey)) {
          teamKeys.add(row.teamKey);
        }
        final label = row.teamName.isNotEmpty
            ? row.teamName
            : row.abbreviation.isNotEmpty
                ? row.abbreviation
                : row.teamKey;
        if (label.isNotEmpty && !teamLabels.contains(label)) teamLabels.add(label);
      }
      final decisions = wins + losses;
      final explicitObservedPct = entry.value.length == 1 ? entry.value.first.winPct : null;
      seasons.add(
        NbaFranchisePerformanceSeason(
          seasonId: entry.key,
          teamKeys: List.unmodifiable(teamKeys),
          teamLabels: List.unmodifiable(teamLabels),
          wins: wins,
          losses: losses,
          winPct: explicitObservedPct ?? (decisions == 0 ? null : wins / decisions),
        ),
      );
    }
    seasons.sort((left, right) => left.seasonId.compareTo(right.seasonId));

    final totalWins = seasons.fold<int>(0, (sum, row) => sum + row.wins);
    final totalLosses = seasons.fold<int>(0, (sum, row) => sum + row.losses);
    final totalDecisions = totalWins + totalLosses;
    final ranked = seasons.where((row) => row.winPct != null).toList()
      ..sort((left, right) {
        final byPct = right.winPct!.compareTo(left.winPct!);
        if (byPct != 0) return byPct;
        final byWins = right.wins.compareTo(left.wins);
        if (byWins != 0) return byWins;
        return right.seasonId.compareTo(left.seasonId);
      });

    return NbaFranchisePerformanceResult(
      franchiseKey: franchise.franchiseKey,
      franchiseName: franchise.franchiseName,
      seasons: List.unmodifiable(seasons),
      totalWins: totalWins,
      totalLosses: totalLosses,
      weightedWinPct: totalDecisions == 0 ? null : totalWins / totalDecisions,
      bestSeason: ranked.isEmpty ? null : ranked.first,
      worstSeason: ranked.isEmpty ? null : ranked.last,
      regularSeasonRows: regularRows.length,
      playoffRowsExcluded: franchise.seasons.length - regularRows.length,
    );
  }

  bool _isRegular(NbaFranchiseSeasonObservation row) {
    final normalized = row.seasonType.trim().toLowerCase().replaceAll('-', '_');
    return normalized == 'regular' ||
        normalized == 'regular_season' ||
        normalized == 'regular season';
  }
}
