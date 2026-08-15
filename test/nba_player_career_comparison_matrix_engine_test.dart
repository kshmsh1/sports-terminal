import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_analytics_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_matrix_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_scope_engine.dart';
import 'package:sports_terminal/services/nba_player_career_engine.dart';

void main() {
  test('matrix keeps source-backed metric cells and left-minus-right deltas', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('left', [
        _season('2020-21', points: 200, rebounds: 100, ts: .60),
        _season('2021-22', points: 240, rebounds: 90, ts: .62),
      ]),
      right: _career('right', [
        _season('2020-21', points: 180, rebounds: 110, ts: .58),
        _season('2021-22', points: 220, rebounds: 80, ts: .62),
      ]),
    );
    final scope = const NbaPlayerCareerComparisonScopeEngine().build(comparison);
    final result = const NbaPlayerCareerComparisonMatrixEngine().build(
      scope,
      metrics: [
        NbaPlayerCareerMetric.pointsPerGame,
        NbaPlayerCareerMetric.reboundsPerGame,
        NbaPlayerCareerMetric.trueShootingPct,
      ],
    );

    expect(result.rows, hasLength(2));
    expect(result.rows.first.cells[0].delta, 2);
    expect(result.rows.first.cells[1].delta, -1);
    expect(result.rows.first.cells[2].delta, 2);
    expect(result.summaries.first.leftAhead, 2);
  });

  test('missing metric evidence stays null and is excluded from summary', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('left', [_season('2020-21', points: 200, bpm: null)]),
      right: _career('right', [_season('2020-21', points: 180, bpm: 3)]),
    );
    final scope = const NbaPlayerCareerComparisonScopeEngine().build(comparison);
    final result = const NbaPlayerCareerComparisonMatrixEngine().build(
      scope,
      metrics: [NbaPlayerCareerMetric.boxPlusMinus],
    );

    expect(result.rows.single.cells.single.leftValue, isNull);
    expect(result.rows.single.cells.single.delta, isNull);
    expect(result.summaries.single.pairedRows, 0);
    expect(result.summaries.single.meanDelta, isNull);
  });

  test('requested metrics are deduplicated without changing order', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('left', [_season('2020-21')]),
      right: _career('right', [_season('2020-21')]),
    );
    final scope = const NbaPlayerCareerComparisonScopeEngine().build(comparison);
    final result = const NbaPlayerCareerComparisonMatrixEngine().build(
      scope,
      metrics: [
        NbaPlayerCareerMetric.pointsPerGame,
        NbaPlayerCareerMetric.pointsPerGame,
        NbaPlayerCareerMetric.assistsPerGame,
      ],
    );

    expect(result.metrics, [
      NbaPlayerCareerMetric.pointsPerGame,
      NbaPlayerCareerMetric.assistsPerGame,
    ]);
  });

  test('shared scope removes one-sided rows before matrix construction', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('left', [_season('2019-20'), _season('2020-21')]),
      right: _career('right', [_season('2020-21'), _season('2021-22')]),
    );
    final scope = const NbaPlayerCareerComparisonScopeEngine().build(
      comparison,
      sharedOnly: true,
    );
    final result = const NbaPlayerCareerComparisonMatrixEngine().build(scope);

    expect(result.rows.map((row) => row.axisLabel), ['2020-21']);
  });
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

NbaPlayerCareerSeason _season(
  String season, {
  double points = 200,
  double rebounds = 80,
  double assists = 50,
  double? ts = .6,
  double? bpm = 2,
}) =>
    NbaPlayerCareerSeason(
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
      points: points,
      rebounds: rebounds,
      assists: assists,
      steals: 10,
      blocks: 5,
      turnovers: 20,
      trueShootingPct: ts,
      playerEfficiencyRating: 20,
      winShares: 5,
      boxPlusMinus: bpm,
      valueOverReplacement: 1,
      syntheticAggregate: false,
      source: 'test',
    );
