import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_season_source_context_engine.dart';

void main() {
  test('projects only source-backed season context collections', () {
    final result = const NbaSeasonSourceContextEngine().build({
      'league': 'NBA',
      'season_type': 'regular',
      'awards': [
        {
          'award': 'Most Valuable Player',
          'player_key': 'p1',
          'player_name': 'Player One',
          'winner': 1,
          'source_key': 'award-source',
        },
      ],
      'all_star': [
        {'player_key': 'p2', 'player_name': 'Player Two', 'starter': true},
      ],
      'draft': [
        {
          'draft_year': 2026,
          'pick_number': 1,
          'player_key': 'p3',
          'player_name': 'Player Three',
          'team_key': 'AAA',
        },
      ],
      'coverage': [
        {'domain': 'awards', 'status': 'available', 'row_count': 5},
      ],
      'summary': {'teams': 30, 'players': 540, 'games': 1230},
    }, seasonId: '2025-26');

    expect(result.seasonId, '2025-26');
    expect(result.awards.single.winner, isTrue);
    expect(result.awards.single.source, 'award-source');
    expect(result.allStar.single.playerId, 'p2');
    expect(result.draft.single.pickNumber, 1);
    expect(result.coverage.single.rows, 5);
    expect(result.declaredTeamCount, 30);
    expect(result.declaredPlayerCount, 540);
    expect(result.declaredGameCount, 1230);
  });

  test('missing transaction collection stays explicitly unavailable', () {
    final result = const NbaSeasonSourceContextEngine().build({
      'awards': const [],
      'all_star': const [],
      'draft': const [],
      'coverage': const [],
    }, seasonId: '2025-26');

    expect(result.transactionCoverageAvailable, isFalse);
    expect(result.hasTransactions, isFalse);
  });

  test('compatible transaction rows remain exact and are ordered only by explicit date', () {
    final result = const NbaSeasonSourceContextEngine().build({
      'transactions': [
        {
          'transaction_date': '2026-02-02',
          'transaction_type': 'trade',
          'description': 'Explicit transaction B',
          'team_key': 'BBB',
        },
        {
          'transaction_date': '2026-01-01',
          'transaction_type': 'waiver',
          'description': 'Explicit transaction A',
          'player_key': 'p1',
        },
      ],
    }, seasonId: '2025-26');

    expect(result.transactionCoverageAvailable, isTrue);
    expect(result.transactions.map((row) => row.description), [
      'Explicit transaction A',
      'Explicit transaction B',
    ]);
    expect(result.transactions.first.playerId, 'p1');
    expect(result.transactions.last.teamId, 'BBB');
  });

  test('empty malformed rows are discarded instead of becoming fake context', () {
    final result = const NbaSeasonSourceContextEngine().build({
      'awards': [const {}, {'award': ''}],
      'all_star': [const {}],
      'draft': [const {}],
      'coverage': [const {}],
      'transactions': [const {}],
    }, seasonId: '2025-26');

    expect(result.awards, isEmpty);
    expect(result.allStar, isEmpty);
    expect(result.draft, isEmpty);
    expect(result.coverage, isEmpty);
    expect(result.transactions, isEmpty);
    expect(result.transactionCoverageAvailable, isTrue);
  });
}
