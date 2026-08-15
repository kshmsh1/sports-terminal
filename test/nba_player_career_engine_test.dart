import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_engine.dart';

void main() {
  test('projects canonical Player identity, career rows and source-backed tenure', () {
    final result = const NbaPlayerCareerEngine().build(
      {
        'profile': {
          'player_key': 'p1',
          'canonical_name': 'Example Star',
          'primary_position': 'G',
          'active_from': '2010-11',
          'active_to': '2020-21',
          'nba_id': '1001',
          'bref_id': 'star01',
          'identity_confidence': 0.99,
          'source_count': 3,
        },
        'seasons': [
          {
            'season_id': '2010-11',
            'season_type': 'regular',
            'team_key': 'alpha',
            'team_name': 'Alpha',
            'team_abbreviation': 'ALP',
            'league_id': 'NBA',
            'games': 80,
            'pts': 1600,
            'reb': 400,
            'ast': 480,
          },
          {
            'season_id': '2011-12',
            'season_type': 'regular',
            'team_key': 'alpha',
            'team_name': 'Alpha',
            'team_abbreviation': 'ALP',
            'league_id': 'NBA',
            'games': 66,
            'pts': 1320,
            'reb': 330,
            'ast': 396,
          },
        ],
        'summary': {
          'first_season': '2010-11',
          'last_season': '2011-12',
          'season_rows': 2,
          'material_conflicts': 0,
        },
      },
      playerKey: 'ignored',
      teamDossiers: {
        'alpha': {
          'profile': {
            'team_key': 'alpha',
            'canonical_name': 'Alpha',
            'franchise_key': 'fr_alpha',
            'franchise_name': 'Alpha Franchise',
          },
        },
      },
    );

    expect(result.available, isTrue);
    expect(result.playerKey, 'p1');
    expect(result.playerName, 'Example Star');
    expect(result.careerRangeLabel, '2010-11 → 2011-12');
    expect(result.careerGames, 146);
    expect(result.careerPoints, 2920);
    expect(result.seasons.first.pointsPerGame, 20);
    expect(result.tenures, hasLength(1));
    expect(result.tenures.single.teamKey, 'alpha');
    expect(result.tenures.single.franchiseKey, 'fr_alpha');
    expect(result.tenures.single.seasonRangeLabel, '2010-11 → 2011-12');
    expect(result.completeTeamFranchiseCoverage, isTrue);
  });

  test('multi-team aggregate stays visible without inventing Team or Franchise', () {
    final result = const NbaPlayerCareerEngine().build(
      {
        'profile': {
          'player_key': 'p1',
          'canonical_name': 'Example Star',
        },
        'seasons': [
          {
            'season_id': '2015-16',
            'season_type': 'regular',
            'team_abbreviation': 'MULTI',
            'team_name': 'Multiple teams',
            'synthetic_aggregate': true,
            'games': 82,
            'pts': 1800,
          },
        ],
      },
      playerKey: 'p1',
    );

    expect(result.seasons.single.teamKey, isEmpty);
    expect(result.seasons.single.syntheticAggregate, isTrue);
    expect(result.seasons.single.teamLabel, 'Multiple teams');
    expect(result.tenures, isEmpty);
    expect(result.multiTeamAggregateSeasons, ['2015-16']);
    expect(result.completeTeamFranchiseCoverage, isFalse);
    expect(result.tenureCoverageLabel, contains('MULTI-TEAM AGGREGATE'));
  });

  test('missing Team dossiers remain explicit tenure coverage gaps', () {
    final result = const NbaPlayerCareerEngine().build(
      {
        'profile': {
          'player_key': 'p1',
          'canonical_name': 'Example Star',
        },
        'seasons': [
          {
            'season_id': '2018-19',
            'season_type': 'regular',
            'team_key': 'beta',
            'team_name': 'Beta',
            'games': 40,
          },
        ],
      },
      playerKey: 'p1',
    );

    expect(result.tenures.single.teamKey, 'beta');
    expect(result.tenures.single.franchiseKey, isEmpty);
    expect(result.missingTeamDossierKeys, ['beta']);
    expect(result.completeTeamFranchiseCoverage, isFalse);
  });

  test('missing totals remain null instead of becoming zero career production', () {
    final result = const NbaPlayerCareerEngine().build(
      {
        'profile': {
          'player_key': 'p1',
          'canonical_name': 'Example Star',
        },
        'seasons': [
          {
            'season_id': '2020-21',
            'season_type': 'regular',
            'team_key': 'alpha',
          },
        ],
      },
      playerKey: 'p1',
      teamDossiers: const {
        'alpha': {
          'profile': {
            'team_key': 'alpha',
            'canonical_name': 'Alpha',
          },
        },
      },
    );

    expect(result.careerGames, isNull);
    expect(result.careerPoints, isNull);
    expect(result.seasons.single.pointsPerGame, isNull);
  });

  test('malformed season rows never become synthetic career history', () {
    final result = const NbaPlayerCareerEngine().build(
      {
        'profile': {'canonical_name': 'Example Star'},
        'seasons': [const {}, {'team_key': 'alpha'}],
      },
      playerKey: 'p1',
    );

    expect(result.playerKey, 'p1');
    expect(result.seasons, isEmpty);
    expect(result.tenures, isEmpty);
  });
}
