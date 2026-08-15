import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_analytics_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_distribution_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_scope_engine.dart';
import 'package:sports_terminal/services/nba_player_career_engine.dart';

void main() {
  test('computes descriptive observed distributions without normalization', () {
    final scope = _scope([10, 20, 30, 40], [5, 15, 25, 35]);
    final result = const NbaPlayerCareerComparisonDistributionEngine().build(
      scope,
      metric: NbaPlayerCareerMetric.pointsPerGame,
    );

    expect(result.left.mean, 25);
    expect(result.left.median, 25);
    expect(result.left.lowerQuartile, 15);
    expect(result.left.upperQuartile, 35);
    expect(result.left.minimum, 10);
    expect(result.left.maximum, 40);
    expect(result.meanDelta, 5);
    expect(result.medianDelta, 5);
  });

  test('missing values remain missing and do not become zero observations', () {
    final scope = _scope([10, null, 30], [5, 15, null]);
    final result = const NbaPlayerCareerComparisonDistributionEngine().build(
      scope,
      metric: NbaPlayerCareerMetric.pointsPerGame,
    );

    expect(result.left.observed, 2);
    expect(result.left.missing, 1);
    expect(result.right.observed, 2);
    expect(result.right.missing, 1);
    expect(result.left.minimum, 10);
  });

  test('empty observed distribution remains explicitly unavailable', () {
    final scope = _scope([null], [10]);
    final result = const NbaPlayerCareerComparisonDistributionEngine().build(
      scope,
      metric: NbaPlayerCareerMetric.pointsPerGame,
    );

    expect(result.left.mean, isNull);
    expect(result.left.standardDeviation, isNull);
    expect(result.meanDelta, isNull);
  });

  test('shared-only scope changes distribution sample rather than imputing gaps', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('left', [
        _season('2019-20', 50),
        _season('2020-21', 20),
      ]),
      right: _career('right', [
        _season('2020-21', 10),
        _season('2021-22', 40),
      ]),
    );
    final shared = const NbaPlayerCareerComparisonScopeEngine().build(
      comparison,
      sharedOnly: true,
    );
    final result = const NbaPlayerCareerComparisonDistributionEngine().build(shared);

    expect(result.left.observed, 1);
    expect(result.left.mean, 20);
    expect(result.right.mean, 10);
  });
}

NbaPlayerCareerComparisonScopeResult _scope(
  List<double?> left,
  List<double?> right,
) {
  final comparison = const NbaPlayerCareerComparisonEngine().build(
    left: _career('left', [
      for (var i = 0; i < left.length; i++) _season('200$i-0${i + 1}', left[i]),
    ]),
    right: _career('right', [
      for (var i = 0; i < right.length; i++) _season('200$i-0${i + 1}', right[i]),
    ]),
  );
  return const NbaPlayerCareerComparisonScopeEngine().build(comparison);
}

NbaPlayerCareerSnapshot _career(String key, List<NbaPlayerCareerSeason> seasons) =>
    NbaPlayerCareerSnapshot(
      playerKey: key,
      playerName: key.toUpperCase(),
      primaryPosition: '',
      activeFrom: '',
      activeTo: '',
      nbaId: '',
      brefId: '',
      identityConfidence: null,
      sourceCount: null,
      seasons: seasons,
      tenures: const [],
      missingTeamDossierKeys: const [],
      multiTeamAggregateSeasons: const [],
      declaredFirstSeason: seasons.isEmpty ? '' : seasons.first.seasonId,
      declaredLastSeason: seasons.isEmpty ? '' : seasons.last.seasonId,
      declaredSeasonRows: seasons.length,
      materialConflictCount: 0,
    );

NbaPlayerCareerSeason _season(String season, double? ppg) => NbaPlayerCareerSeason(
      seasonId: season,
      seasonType: 'regular',
      leagueId: 'NBA',
      teamKey: 'team',
      teamName: 'Team',
      teamAbbreviation: 'TM',
      franchiseKey: 'franchise',
      franchiseName: 'Franchise',
      games: 10,
      gamesStarted: 10,
      minutes: 300,
      points: ppg == null ? null : ppg * 10,
      rebounds: 50,
      assists: 40,
      steals: 10,
      blocks: 5,
      turnovers: 20,
      trueShootingPct: .6,
      playerEfficiencyRating: 20,
      winShares: 5,
      boxPlusMinus: 2,
      valueOverReplacement: 1,
      syntheticAggregate: false,
      source: 'test',
    );
