import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_franchise_intelligence_engine.dart';

void main() {
  test('projects canonical franchise identity, lineage and season history', () {
    final result = const NbaFranchiseIntelligenceEngine().build(
      {
        'profile': {
          'franchise_key': 'fr_alpha',
          'canonical_name': 'Alpha Franchise',
          'current_abbreviation': 'ALP',
          'source_count': 3,
        },
        'team_identities': [
          {
            'team_key': 'alpha_old',
            'canonical_name': 'Old Alpha',
            'abbreviation': 'OLD',
            'league_id': 'NBA',
            'active_from': '1990-91',
            'active_to': '1999-00',
            'source_count': 2,
          },
          {
            'team_key': 'alpha_new',
            'canonical_name': 'Alpha',
            'abbreviation': 'ALP',
            'league_id': 'NBA',
            'active_from': '2000-01',
            'active_to': '2025-26',
            'nba_team_id': '100',
          },
        ],
        'seasons': [
          {
            'season_id': '2000-01',
            'season_type': 'regular',
            'team_key': 'alpha_new',
            'canonical_team_name': 'Alpha',
            'abbreviation': 'ALP',
            'league_id': 'NBA',
            'wins': 50,
            'losses': 32,
            'win_pct': 0.609756,
          },
          {
            'season_id': '2000-01',
            'season_type': 'playoffs',
            'team_key': 'alpha_new',
            'canonical_team_name': 'Alpha',
            'wins': 8,
            'losses': 5,
          },
        ],
        'summary': {
          'team_identities': 2,
          'seasons': 20,
          'first_season': '1990-91',
          'last_season': '2025-26',
        },
      },
      franchiseKey: 'ignored',
    );

    expect(result.available, isTrue);
    expect(result.franchiseKey, 'fr_alpha');
    expect(result.franchiseName, 'Alpha Franchise');
    expect(result.currentAbbreviation, 'ALP');
    expect(result.teamIdentities.map((row) => row.teamKey), [
      'alpha_old',
      'alpha_new',
    ]);
    expect(result.teamIdentities.first.eraLabel, '1990-91 → 1999-00');
    expect(result.seasons.length, 2);
    final regular = result.seasons.singleWhere(
      (row) => row.seasonType == 'regular',
    );
    expect(regular.winPct, closeTo(0.609756, 0.000001));
    expect(result.declaredIdentityCount, 2);
    expect(result.declaredSeasonCount, 20);
    expect(result.seasonRangeLabel, '1990-91 → 2025-26');
  });

  test('computes win percentage only from explicit wins and losses when needed', () {
    final result = const NbaFranchiseIntelligenceEngine().build(
      {
        'profile': {
          'franchise_key': 'fr_alpha',
          'canonical_name': 'Alpha Franchise',
        },
        'seasons': [
          {
            'season_id': '2025-26',
            'season_type': 'regular',
            'team_key': 'alpha',
            'wins': 41,
            'losses': 41,
          },
          {
            'season_id': '2024-25',
            'season_type': 'regular',
            'team_key': 'alpha',
          },
        ],
      },
      franchiseKey: 'fr_alpha',
    );

    expect(result.seasons.first.winPct, isNull);
    expect(result.seasons.last.winPct, 0.5);
  });

  test('malformed identity and season rows never become fake franchise history', () {
    final result = const NbaFranchiseIntelligenceEngine().build(
      {
        'profile': {'canonical_name': 'Alpha Franchise'},
        'team_identities': [const {}, {'team_key': '', 'canonical_name': ''}],
        'seasons': [const {}, {'season_id': '2025-26'}, {'team_key': 'alpha'}],
      },
      franchiseKey: 'fr_alpha',
    );

    expect(result.franchiseKey, 'fr_alpha');
    expect(result.teamIdentities, isEmpty);
    expect(result.seasons, isEmpty);
  });

  test('missing lineage and season summaries stay explicitly unavailable', () {
    final result = const NbaFranchiseIntelligenceEngine().build(
      {
        'profile': {
          'franchise_key': 'fr_alpha',
          'canonical_name': 'Alpha Franchise',
        },
      },
      franchiseKey: 'fr_alpha',
    );

    expect(result.hasLineage, isFalse);
    expect(result.hasSeasonHistory, isFalse);
    expect(result.seasonRangeLabel, 'SEASON RANGE NOT EXPOSED');
    expect(result.declaredIdentityCount, isNull);
    expect(result.declaredSeasonCount, isNull);
  });
}
