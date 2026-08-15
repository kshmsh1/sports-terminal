import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_context_engine.dart';

void main() {
  test('projects only explicit awards All-Star draft and Game rows', () {
    final result = const NbaPlayerCareerContextEngine().build({
      'awards': [
        {
          'season_id': '2019-20',
          'award': 'Most Valuable Player',
          'rank': 1,
          'votes': 90,
          'primary_source': 'awards_source',
        },
      ],
      'all_star': [
        {
          'season_id': '2019-20',
          'selection_type': 'All-Star',
          'conference': 'West',
          'starter': true,
          'primary_source': 'all_star_source',
        },
      ],
      'draft': [
        {
          'draft_year': 2010,
          'round': 1,
          'pick_number': 5,
          'team_key': 'alpha',
          'team_abbreviation': 'ALP',
          'primary_source': 'draft_source',
        },
      ],
      'recent_games': [
        {
          'game_key': 'g1',
          'season_id': '2020-21',
          'game_date': '2021-01-03',
          'team_key': 'alpha',
          'team_name': 'Alpha',
          'opponent_team_key': 'beta',
          'opponent_name': 'Beta',
          'pts': 30,
          'reb': 8,
          'ast': 7,
          'home_team_key': 'alpha',
          'away_team_key': 'beta',
          'home_score': 110,
          'away_score': 104,
        },
      ],
      'identities': [
        {'source_key': 'nba'},
        {'source_key': 'bref'},
      ],
      'conflicts': [
        {'field_name': 'birth_date'},
      ],
      'field_provenance': [
        {'field_name': 'canonical_name'},
      ],
    });

    expect(result.awards.single.award, 'Most Valuable Player');
    expect(result.awards.single.rank, 1);
    expect(result.allStarSelections.single.starter, isTrue);
    expect(result.draftRecords.single.pick, 5);
    expect(result.draftRecords.single.teamKey, 'alpha');
    expect(result.recentGames.single.gameKey, 'g1');
    expect(result.recentGames.single.matchupLabel, 'Alpha vs Beta');
    expect(result.identityRows, 2);
    expect(result.conflictRows, 1);
    expect(result.fieldProvenanceRows, 1);
    expect(result.sourceBoundaryLabel, 'SOURCE-BACKED CAREER CONTEXT');
  });

  test('missing award context stays unavailable instead of inferring accolades', () {
    final result = const NbaPlayerCareerContextEngine().build({
      'all_star': [
        {'season_id': '2019-20'},
      ],
    });

    expect(result.hasAwards, isFalse);
    expect(result.hasDraft, isFalse);
    expect(result.hasGames, isFalse);
    expect(result.sourceBoundaryLabel, contains('AWARDS NOT EXPOSED'));
    expect(result.sourceBoundaryLabel, contains('DRAFT NOT EXPOSED'));
  });

  test('starter status remains null when source row does not expose it', () {
    final result = const NbaPlayerCareerContextEngine().build({
      'all_star': [
        {
          'season_id': '2021-22',
          'selection': 'All-Star selection',
        },
      ],
    });

    expect(result.allStarSelections.single.starter, isNull);
  });

  test('draft fields remain unknown rather than being reconstructed', () {
    final result = const NbaPlayerCareerContextEngine().build({
      'draft': [
        {
          'draft_year': 2010,
          'team_key': 'alpha',
        },
      ],
    });

    expect(result.draftRecords.single.draftYear, 2010);
    expect(result.draftRecords.single.round, isNull);
    expect(result.draftRecords.single.pick, isNull);
  });

  test('malformed context rows are discarded', () {
    final result = const NbaPlayerCareerContextEngine().build({
      'awards': [const {}],
      'all_star': [const {}],
      'draft': [const {}],
      'recent_games': [const {}, {'game_date': '2020-01-01'}],
    });

    expect(result.awards, isEmpty);
    expect(result.allStarSelections, isEmpty);
    expect(result.draftRecords, isEmpty);
    expect(result.recentGames, isEmpty);
  });
}
