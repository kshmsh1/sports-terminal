import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_profile_format.dart';

void main() {
  test('positions are ordered by point guard through center and deduplicated', () {
    expect(nbaOrderedPositions('SG, SF, PF, PG, C'), 'PG, SG, SF, PF, C');
    expect(nbaOrderedPositions('PF, PF, C'), 'PF, C');
    expect(nbaOrderedPositions(''), '');
  });

  test('four MVP wins are grouped by award and displayed as ending years', () {
    final honors = nbaPlayerHonors([
      for (final year in ['2008-09', '2009-10', '2011-12', '2012-13'])
        {'award': 'nba_mvp', 'season_id': year, 'winner': 1},
      {'award': 'nba_mvp', 'season_id': '2010-11', 'winner': 0},
    ]);
    final mvp = honors.singleWhere((h) => h.title == 'Most Valuable Player (MVP)');
    expect(mvp.years, [2009, 2010, 2012, 2013]);
    expect(mvp.years.length, 4);
  });

  test('selection duplicates are deduplicated; nomination-only wins are excluded', () {
    final honors = nbaPlayerHonors([
      {'award': 'all_nba', 'season_id': '2014-15', 'winner': 0},
      {'award': 'All-NBA', 'season_id': '2014-15', 'winner': 0},
      {'award': 'nba_mvp', 'season_id': '2014-15', 'winner': 0},
    ], allStar: [
      {'season_id': '2015-16'}, {'season_id': '2015-16'},
    ]);
    expect(honors.singleWhere((h) => h.title == 'All-NBA Team').years, [2015]);
    expect(honors.singleWhere((h) => h.title == 'NBA All-Star').years, [2016]);
    expect(honors.any((h) => h.title == 'Most Valuable Player (MVP)'), isFalse);
  });
}
