import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_context_engine.dart';
import 'package:sports_terminal/services/nba_player_career_context_engine.dart';

NbaPlayerCareerAward _award(String season, String name) => NbaPlayerCareerAward(
      seasonId: season,
      award: name,
      result: '',
      rank: null,
      votes: null,
      points: null,
      source: 'test',
    );

NbaPlayerCareerAllStarSelection _allStar(String season) =>
    NbaPlayerCareerAllStarSelection(
      seasonId: season,
      selection: 'All-Star',
      conference: '',
      starter: null,
      source: 'test',
    );

NbaPlayerCareerContext _context({
  List<NbaPlayerCareerAward> awards = const [],
  List<NbaPlayerCareerAllStarSelection> allStar = const [],
}) =>
    NbaPlayerCareerContext(
      awards: awards,
      allStarSelections: allStar,
      draftRecords: const [],
      recentGames: const [],
      identityRows: 1,
      conflictRows: 0,
      fieldProvenanceRows: 1,
    );

void main() {
  test('intersects exact award labels without inferring wins', () {
    final result = const NbaPlayerCareerComparisonContextEngine().build(
      left: _context(awards: [_award('2020-21', 'MVP'), _award('2021-22', 'All-NBA')]),
      right: _context(awards: [_award('2022-23', 'MVP'), _award('2023-24', 'DPOY')]),
    );
    expect(result.sharedAwardLabels, ['MVP']);
    expect(result.leftOnlyAwardLabels, ['All-NBA']);
    expect(result.rightOnlyAwardLabels, ['DPOY']);
    expect(result.leftAwardRows, 2);
    expect(result.boundaryLabel, contains('EVIDENCE ROW COUNTS ONLY'));
  });

  test('All-Star overlap uses only explicit season ids', () {
    final result = const NbaPlayerCareerComparisonContextEngine().build(
      left: _context(allStar: [_allStar('2020-21'), _allStar('2021-22')]),
      right: _context(allStar: [_allStar('2021-22'), _allStar('2022-23')]),
    );
    expect(result.sharedAllStarSeasons, ['2021-22']);
  });

  test('missing context remains zero evidence rather than inferred absence', () {
    final result = const NbaPlayerCareerComparisonContextEngine().build(
      left: _context(),
      right: _context(),
    );
    expect(result.leftAwardRows, 0);
    expect(result.rightAllStarRows, 0);
    expect(result.sharedAwardLabels, isEmpty);
  });
}
