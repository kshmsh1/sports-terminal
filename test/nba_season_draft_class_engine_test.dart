import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_season_draft_class_engine.dart';

void main() {
  test('orders exact source-backed draft rows by explicit year and pick', () {
    final result = const NbaSeasonDraftClassEngine().build({
      'draft': [
        {
          'draft_year': 2026,
          'pick_number': 3,
          'round': 1,
          'player_key': 'p3',
          'player_name': 'Third Pick',
          'team_key': 'CCC',
        },
        {
          'draft_year': 2026,
          'pick_number': 1,
          'round': 1,
          'player_key': 'p1',
          'player_name': 'First Pick',
          'team_key': 'AAA',
          'source_key': 'draft-source',
        },
        {
          'draft_year': 2025,
          'pick_number': 2,
          'round': 1,
          'player_key': 'old2',
          'player_name': 'Prior Draft Row',
        },
      ],
    }, seasonId: '2025-26');

    expect(result.draftYears, [2025, 2026]);
    expect(result.rows.map((row) => row.playerId), ['old2', 'p1', 'p3']);
    expect(result.rows[1].source, 'draft-source');
    expect(result.numberedPicks, 3);
    expect(result.firstRoundRows, 3);
  });

  test('season id never implies or filters a draft year', () {
    final result = const NbaSeasonDraftClassEngine().build({
      'draft': [
        {'draft_year': 2024, 'pick_number': 1, 'player_name': 'One'},
        {'draft_year': 2026, 'pick_number': 1, 'player_name': 'Two'},
      ],
    }, seasonId: '2025-26');

    expect(result.rows.length, 2);
    expect(result.draftYears, [2024, 2026]);
  });

  test('missing round and pick remain unknown rather than inferred', () {
    final result = const NbaSeasonDraftClassEngine().build({
      'draft': [
        {
          'draft_year': 2026,
          'player_key': 'p1',
          'player_name': 'Unknown Slot',
          'team_key': 'AAA',
        },
      ],
    }, seasonId: '2025-26');

    final row = result.rows.single;
    expect(row.pickNumber, isNull);
    expect(row.round, isNull);
    expect(row.pickLabel, '—');
    expect(row.roundLabel, '—');
    expect(result.rowsWithoutPickNumber, 1);
    expect(result.explicitTeamRows, 1);
  });

  test('malformed rows do not become synthetic draft selections', () {
    final result = const NbaSeasonDraftClassEngine().build({
      'draft': [const {}, {'draft_year': 2026, 'team_key': 'AAA'}],
    }, seasonId: '2025-26');

    expect(result.hasRows, isFalse);
    expect(result.sourceRows, 0);
  });
}
