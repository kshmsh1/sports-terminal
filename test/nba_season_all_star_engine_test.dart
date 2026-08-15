import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_season_all_star_engine.dart';

void main() {
  test('keeps explicit starters separate from generic selections', () {
    final result = const NbaSeasonAllStarEngine().build({
      'all_star': [
        {
          'player_key': 'p2',
          'player_name': 'Beta Wing',
          'team_key': 'BBB',
        },
        {
          'player_key': 'p1',
          'player_name': 'Alpha Guard',
          'team_key': 'AAA',
          'starter': true,
        },
      ],
    }, seasonId: '2025-26');

    expect(result.selections, 2);
    expect(result.explicitStarters, 1);
    expect(result.rows.first.playerId, 'p1');
    expect(result.rows.first.statusLabel, 'STARTER');
    expect(result.rows.last.statusLabel, 'SELECTED');
  });

  test('preserves optional conference roster and selection labels exactly', () {
    final result = const NbaSeasonAllStarEngine().build({
      'all_star': [
        {
          'player_id': 'p1',
          'canonical_name': 'Alpha Guard',
          'team_id': 'AAA',
          'team_name': 'Alpha',
          'conference': 'East',
          'roster_label': 'Team One',
          'selection_type': 'replacement',
          'source_key': 'all-star-source',
        },
      ],
    }, seasonId: '2025-26');

    final row = result.rows.single;
    expect(row.conference, 'East');
    expect(row.rosterLabel, 'Team One');
    expect(row.selectionType, 'replacement');
    expect(row.source, 'all-star-source');
    expect(result.conferences, ['East']);
    expect(result.rowsWithRosterLabel, 1);
    expect(result.rowsWithSelectionType, 1);
  });

  test('non-starter rows are not relabeled as reserves', () {
    final result = const NbaSeasonAllStarEngine().build({
      'all_star': [
        {'player_name': 'Selection One', 'starter': false},
      ],
    }, seasonId: '2025-26');

    expect(result.rows.single.statusLabel, 'SELECTED');
    expect(result.rows.single.selectionType, isEmpty);
  });

  test('malformed All-Star rows remain absent', () {
    final result = const NbaSeasonAllStarEngine().build({
      'all_star': [const {}, {'team_key': 'AAA'}],
    }, seasonId: '2025-26');

    expect(result.hasRows, isFalse);
    expect(result.selections, 0);
  });
}
