import 'nba_player_career_engine.dart';

enum NbaPlayerCareerComparisonAlignment {
  calendarSeason('CALENDAR SEASON'),
  careerYear('CAREER YEAR');

  const NbaPlayerCareerComparisonAlignment(this.label);
  final String label;
}

class NbaPlayerCareerComparisonPair {
  const NbaPlayerCareerComparisonPair({
    required this.axisLabel,
    required this.ordinal,
    required this.left,
    required this.right,
  });

  final String axisLabel;
  final int ordinal;
  final NbaPlayerCareerSeason? left;
  final NbaPlayerCareerSeason? right;

  bool get bothObserved => left != null && right != null;
  bool get leftOnly => left != null && right == null;
  bool get rightOnly => left == null && right != null;
}

class NbaPlayerCareerComparisonSnapshot {
  const NbaPlayerCareerComparisonSnapshot({
    required this.left,
    required this.right,
    required this.alignment,
    required this.pairs,
    required this.sharedCalendarSeasons,
    required this.leftOnlyCalendarSeasons,
    required this.rightOnlyCalendarSeasons,
  });

  final NbaPlayerCareerSnapshot left;
  final NbaPlayerCareerSnapshot right;
  final NbaPlayerCareerComparisonAlignment alignment;
  final List<NbaPlayerCareerComparisonPair> pairs;
  final List<String> sharedCalendarSeasons;
  final List<String> leftOnlyCalendarSeasons;
  final List<String> rightOnlyCalendarSeasons;

  bool get available => left.available && right.available;
  bool get samePlayer => left.playerKey == right.playerKey;
  bool get hasCalendarOverlap => sharedCalendarSeasons.isNotEmpty;
  int get pairedObservations => pairs.where((pair) => pair.bothObserved).length;

  String get coverageLabel {
    if (!available) return 'PLAYER IDENTITY INCOMPLETE';
    if (samePlayer) return 'SAME CANONICAL PLAYER';
    if (alignment == NbaPlayerCareerComparisonAlignment.calendarSeason &&
        !hasCalendarOverlap) {
      return 'NON-OVERLAPPING CALENDAR ERAS';
    }
    return '$pairedObservations PAIRED · ${pairs.length} AXIS ROWS';
  }
}

/// Aligns two independently canonicalized Player careers without era
/// normalization, interpolation, or inferred team-season reconstruction.
///
/// Calendar alignment uses the exact season IDs exposed by each career.
/// Career-year alignment only pairs the first exposed row with the first
/// exposed row, second with second, and so on; it does not claim equivalent
/// age, role, competition, rules, pace, or league environment.
class NbaPlayerCareerComparisonEngine {
  const NbaPlayerCareerComparisonEngine();

  NbaPlayerCareerComparisonSnapshot build({
    required NbaPlayerCareerSnapshot left,
    required NbaPlayerCareerSnapshot right,
    NbaPlayerCareerComparisonAlignment alignment =
        NbaPlayerCareerComparisonAlignment.calendarSeason,
  }) {
    final leftBySeason = _oneRowPerSeason(left.seasons);
    final rightBySeason = _oneRowPerSeason(right.seasons);
    final leftSeasons = leftBySeason.keys.toSet();
    final rightSeasons = rightBySeason.keys.toSet();
    final shared = leftSeasons.intersection(rightSeasons).toList()..sort();
    final leftOnly = leftSeasons.difference(rightSeasons).toList()..sort();
    final rightOnly = rightSeasons.difference(leftSeasons).toList()..sort();

    final pairs = alignment == NbaPlayerCareerComparisonAlignment.calendarSeason
        ? _calendarPairs(leftBySeason, rightBySeason)
        : _careerYearPairs(
            leftBySeason.values.toList(),
            rightBySeason.values.toList(),
          );

    return NbaPlayerCareerComparisonSnapshot(
      left: left,
      right: right,
      alignment: alignment,
      pairs: List.unmodifiable(pairs),
      sharedCalendarSeasons: List.unmodifiable(shared),
      leftOnlyCalendarSeasons: List.unmodifiable(leftOnly),
      rightOnlyCalendarSeasons: List.unmodifiable(rightOnly),
    );
  }

  Map<String, NbaPlayerCareerSeason> _oneRowPerSeason(
    List<NbaPlayerCareerSeason> rows,
  ) {
    final sorted = [...rows]
      ..sort((a, b) {
        final bySeason = a.seasonId.compareTo(b.seasonId);
        if (bySeason != 0) return bySeason;
        if (a.syntheticAggregate != b.syntheticAggregate) {
          return a.syntheticAggregate ? -1 : 1;
        }
        return a.teamLabel.compareTo(b.teamLabel);
      });
    final result = <String, NbaPlayerCareerSeason>{};
    for (final row in sorted) {
      // Prefer an explicit aggregate when the source supplies one because it is
      // the only row representing the full player-season. Otherwise retain the
      // first exact row and never sum traded-team rows here.
      final current = result[row.seasonId];
      if (current == null || row.syntheticAggregate) {
        result[row.seasonId] = row;
      }
    }
    return result;
  }

  List<NbaPlayerCareerComparisonPair> _calendarPairs(
    Map<String, NbaPlayerCareerSeason> left,
    Map<String, NbaPlayerCareerSeason> right,
  ) {
    final seasons = {...left.keys, ...right.keys}.toList()..sort();
    return [
      for (var index = 0; index < seasons.length; index++)
        NbaPlayerCareerComparisonPair(
          axisLabel: seasons[index],
          ordinal: index + 1,
          left: left[seasons[index]],
          right: right[seasons[index]],
        ),
    ];
  }

  List<NbaPlayerCareerComparisonPair> _careerYearPairs(
    List<NbaPlayerCareerSeason> left,
    List<NbaPlayerCareerSeason> right,
  ) {
    left.sort((a, b) => a.seasonId.compareTo(b.seasonId));
    right.sort((a, b) => a.seasonId.compareTo(b.seasonId));
    final count = left.length > right.length ? left.length : right.length;
    return [
      for (var index = 0; index < count; index++)
        NbaPlayerCareerComparisonPair(
          axisLabel: 'YEAR ${index + 1}',
          ordinal: index + 1,
          left: index < left.length ? left[index] : null,
          right: index < right.length ? right[index] : null,
        ),
    ];
  }
}
