import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_season_awards_voting_engine.dart';

void main() {
  test('groups source-backed award rows without inferring winners', () {
    final result = const NbaSeasonAwardsVotingEngine().build({
      'awards': [
        {
          'award': 'Most Valuable Player',
          'player_key': 'p1',
          'player_name': 'Alpha Guard',
          'winner': true,
          'rank': 1,
          'vote_points': 900,
          'first_place_votes': 80,
          'source_key': 'official-awards',
        },
        {
          'award': 'Most Valuable Player',
          'player_key': 'p2',
          'player_name': 'Beta Wing',
          'rank': 2,
          'vote_points': 650,
        },
        {
          'award': 'Defensive Player of the Year',
          'player_key': 'p3',
          'player_name': 'Gamma Big',
          'rank': 1,
        },
      ],
    }, seasonId: '2025-26');

    expect(result.awardCount, 2);
    expect(result.explicitWinnerRows, 1);
    final mvp = result.awards.firstWhere(
      (award) => award.award == 'Most Valuable Player',
    );
    expect(mvp.explicitWinner?.playerId, 'p1');
    expect(mvp.rows.map((row) => row.playerId), ['p1', 'p2']);
    final dpoy = result.awards.firstWhere(
      (award) => award.award == 'Defensive Player of the Year',
    );
    expect(dpoy.explicitWinner, isNull);
    expect(dpoy.rows.single.rank, 1);
  });

  test('preserves only explicit voting detail and source metadata', () {
    final result = const NbaSeasonAwardsVotingEngine().build({
      'awards': [
        {
          'award_name': 'Rookie of the Year',
          'canonical_name': 'Rookie One',
          'player_id': 'r1',
          'vote_share': 0.72,
          'total_votes': 100,
          'provenance': {'source_key': 'vote-table'},
        },
        {
          'award_name': 'Rookie of the Year',
          'canonical_name': 'Rookie Two',
          'player_id': 'r2',
        },
      ],
    }, seasonId: '2025-26');

    expect(result.rowsWithVoteDetail, 1);
    final row = result.awards.single.rows.firstWhere(
      (candidate) => candidate.playerId == 'r1',
    );
    expect(row.voteShare, 0.72);
    expect(row.totalVotes, 100);
    expect(row.source, 'vote-table');
    expect(result.awards.single.rows.last.hasVoteDetail, isFalse);
  });

  test('winner ordering does not manufacture rank or voting fields', () {
    final result = const NbaSeasonAwardsVotingEngine().build({
      'awards': [
        {
          'award': 'Sixth Man',
          'player_name': 'Ranked First',
          'player_key': 'p1',
          'rank': 1,
        },
        {
          'award': 'Sixth Man',
          'player_name': 'Explicit Winner',
          'player_key': 'p2',
          'winner': 1,
        },
      ],
    }, seasonId: '2025-26');

    expect(result.awards.single.rows.first.playerId, 'p2');
    expect(result.awards.single.rows.first.rank, isNull);
    expect(result.awards.single.rows.first.votePoints, isNull);
    expect(result.awards.single.rows.last.winner, isFalse);
  });

  test('malformed award rows remain absent', () {
    final result = const NbaSeasonAwardsVotingEngine().build({
      'awards': [const {}, {'award': '', 'player_name': ''}],
    }, seasonId: '2025-26');

    expect(result.hasAwards, isFalse);
    expect(result.sourceRows, 0);
  });
}
