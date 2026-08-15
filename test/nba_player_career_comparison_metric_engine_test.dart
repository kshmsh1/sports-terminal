import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_analytics_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_metric_engine.dart';
import 'package:sports_terminal/services/nba_player_career_engine.dart';

NbaPlayerCareerSeason _season(String id, {double? games = 10, double? points, double? ts}) =>
    NbaPlayerCareerSeason(
      seasonId: id,
      seasonType: 'regular',
      leagueId: 'NBA',
      teamKey: '',
      teamName: '',
      teamAbbreviation: 'TOT',
      franchiseKey: '',
      franchiseName: '',
      games: games,
      gamesStarted: null,
      minutes: null,
      points: points,
      rebounds: null,
      assists: null,
      steals: null,
      blocks: null,
      turnovers: null,
      trueShootingPct: ts,
      playerEfficiencyRating: null,
      winShares: null,
      boxPlusMinus: null,
      valueOverReplacement: null,
      syntheticAggregate: true,
      source: 'test',
    );

NbaPlayerCareerSnapshot _career(String key, List<NbaPlayerCareerSeason> rows) =>
    NbaPlayerCareerSnapshot(
      playerKey: key,
      playerName: key,
      primaryPosition: '',
      activeFrom: '',
      activeTo: '',
      nbaId: '',
      brefId: '',
      identityConfidence: null,
      sourceCount: null,
      seasons: rows,
      tenures: const [],
      missingTeamDossierKeys: const [],
      multiTeamAggregateSeasons: const [],
      declaredFirstSeason: '',
      declaredLastSeason: '',
      declaredSeasonRows: rows.length,
      materialConflictCount: 0,
    );

void main() {
  test('compares only paired observed metric values', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('a', [_season('2020-21', points: 200), _season('2021-22', points: null)]),
      right: _career('b', [_season('2020-21', points: 180), _season('2021-22', points: 210)]),
    );
    final result = const NbaPlayerCareerComparisonMetricEngine().build(comparison);
    expect(result.paired, 1);
    expect(result.leftObserved, 1);
    expect(result.rightObserved, 2);
    expect(result.leftAhead, 1);
    expect(result.points[1].delta, isNull);
  });

  test('true shooting stays in percentage-point units', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('a', [_season('2020-21', ts: .61)]),
      right: _career('b', [_season('2020-21', ts: .58)]),
    );
    final result = const NbaPlayerCareerComparisonMetricEngine().build(
      comparison,
      metric: NbaPlayerCareerMetric.trueShootingPct,
    );
    expect(result.points.single.leftValue, closeTo(61, .001));
    expect(result.points.single.delta, closeTo(3, .001));
  });

  test('no paired evidence produces no mean delta', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('a', [_season('1980-81', points: 100)]),
      right: _career('b', [_season('2020-21', points: 100)]),
    );
    final result = const NbaPlayerCareerComparisonMetricEngine().build(comparison);
    expect(result.comparable, isFalse);
    expect(result.meanDelta, isNull);
  });

  test('ties are explicit rather than arbitrarily assigned', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('a', [_season('2020-21', points: 200)]),
      right: _career('b', [_season('2020-21', points: 200)]),
    );
    final result = const NbaPlayerCareerComparisonMetricEngine().build(comparison);
    expect(result.tied, 1);
    expect(result.leftAhead, 0);
    expect(result.rightAhead, 0);
  });
}
