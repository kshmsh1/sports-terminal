import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_franchise_intelligence_engine.dart';
import 'package:sports_terminal/services/nba_franchise_performance_engine.dart';

void main() {
  test('aggregates regular-season performance across canonical franchise identities', () {
    final franchise = const NbaFranchiseIntelligenceEngine().build(
      {
        'profile': {
          'franchise_key': 'fr_alpha',
          'canonical_name': 'Alpha Franchise',
        },
        'seasons': [
          {
            'season_id': '1999-00',
            'season_type': 'regular',
            'team_key': 'alpha_old',
            'canonical_team_name': 'Old Alpha',
            'wins': 40,
            'losses': 42,
          },
          {
            'season_id': '2000-01',
            'season_type': 'regular',
            'team_key': 'alpha_new',
            'canonical_team_name': 'Alpha',
            'wins': 50,
            'losses': 32,
          },
          {
            'season_id': '2000-01',
            'season_type': 'playoffs',
            'team_key': 'alpha_new',
            'wins': 8,
            'losses': 5,
          },
        ],
      },
      franchiseKey: 'fr_alpha',
    );

    final result = const NbaFranchisePerformanceEngine().build(franchise);

    expect(result.observedSeasons, 2);
    expect(result.regularSeasonRows, 2);
    expect(result.playoffRowsExcluded, 1);
    expect(result.totalWins, 90);
    expect(result.totalLosses, 74);
    expect(result.weightedWinPct, closeTo(90 / 164, 0.000001));
    expect(result.bestSeason?.seasonId, '2000-01');
    expect(result.worstSeason?.seasonId, '1999-00');
  });

  test('same-season identity rows are combined without inventing extra seasons', () {
    final franchise = const NbaFranchiseIntelligenceEngine().build(
      {
        'profile': {
          'franchise_key': 'fr_alpha',
          'canonical_name': 'Alpha Franchise',
        },
        'seasons': [
          {
            'season_id': '2001-02',
            'season_type': 'regular',
            'team_key': 'alpha_a',
            'canonical_team_name': 'Alpha A',
            'wins': 20,
            'losses': 20,
          },
          {
            'season_id': '2001-02',
            'season_type': 'regular',
            'team_key': 'alpha_b',
            'canonical_team_name': 'Alpha B',
            'wins': 25,
            'losses': 17,
          },
        ],
      },
      franchiseKey: 'fr_alpha',
    );

    final result = const NbaFranchisePerformanceEngine().build(franchise);

    expect(result.observedSeasons, 1);
    expect(result.seasons.single.wins, 45);
    expect(result.seasons.single.losses, 37);
    expect(result.seasons.single.teamKeys, ['alpha_a', 'alpha_b']);
    expect(result.seasons.single.winPct, closeTo(45 / 82, 0.000001));
  });

  test('rows without decisions remain visible but do not create fake win percentage', () {
    final franchise = const NbaFranchiseIntelligenceEngine().build(
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
          },
        ],
      },
      franchiseKey: 'fr_alpha',
    );

    final result = const NbaFranchisePerformanceEngine().build(franchise);

    expect(result.available, isTrue);
    expect(result.seasons.single.recordLabel, '—');
    expect(result.seasons.single.winPct, isNull);
    expect(result.weightedWinPct, isNull);
    expect(result.bestSeason, isNull);
    expect(result.worstSeason, isNull);
  });
}
