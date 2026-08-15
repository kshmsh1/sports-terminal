import 'nba_player_career_context_engine.dart';

class NbaPlayerCareerComparisonContextResult {
  const NbaPlayerCareerComparisonContextResult({
    required this.leftAwardRows,
    required this.rightAwardRows,
    required this.leftAllStarRows,
    required this.rightAllStarRows,
    required this.leftDraftRows,
    required this.rightDraftRows,
    required this.leftRecentGames,
    required this.rightRecentGames,
    required this.sharedAwardLabels,
    required this.leftOnlyAwardLabels,
    required this.rightOnlyAwardLabels,
    required this.sharedAllStarSeasons,
  });

  final int leftAwardRows;
  final int rightAwardRows;
  final int leftAllStarRows;
  final int rightAllStarRows;
  final int leftDraftRows;
  final int rightDraftRows;
  final int leftRecentGames;
  final int rightRecentGames;
  final List<String> sharedAwardLabels;
  final List<String> leftOnlyAwardLabels;
  final List<String> rightOnlyAwardLabels;
  final List<String> sharedAllStarSeasons;

  String get boundaryLabel =>
      'EVIDENCE ROW COUNTS ONLY · NO AWARD-WIN OR ERA EQUIVALENCE INFERENCE';
}

/// Compares descriptive career context without converting evidence rows into
/// inferred accolade totals. Exact award labels and All-Star season IDs can be
/// intersected; winner status, voting meaning, starter status, or cross-era
/// award equivalence are never inferred.
class NbaPlayerCareerComparisonContextEngine {
  const NbaPlayerCareerComparisonContextEngine();

  NbaPlayerCareerComparisonContextResult build({
    required NbaPlayerCareerContext left,
    required NbaPlayerCareerContext right,
  }) {
    final leftAwards = left.awards
        .map((row) => row.award.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final rightAwards = right.awards
        .map((row) => row.award.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final leftAllStarSeasons = left.allStarSelections
        .map((row) => row.seasonId.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final rightAllStarSeasons = right.allStarSelections
        .map((row) => row.seasonId.trim())
        .where((value) => value.isNotEmpty)
        .toSet();

    List<String> sorted(Set<String> values) => values.toList()..sort();

    return NbaPlayerCareerComparisonContextResult(
      leftAwardRows: left.awards.length,
      rightAwardRows: right.awards.length,
      leftAllStarRows: left.allStarSelections.length,
      rightAllStarRows: right.allStarSelections.length,
      leftDraftRows: left.draftRecords.length,
      rightDraftRows: right.draftRecords.length,
      leftRecentGames: left.recentGames.length,
      rightRecentGames: right.recentGames.length,
      sharedAwardLabels: sorted(leftAwards.intersection(rightAwards)),
      leftOnlyAwardLabels: sorted(leftAwards.difference(rightAwards)),
      rightOnlyAwardLabels: sorted(rightAwards.difference(leftAwards)),
      sharedAllStarSeasons:
          sorted(leftAllStarSeasons.intersection(rightAllStarSeasons)),
    );
  }
}
