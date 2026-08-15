import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_analytics_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_distribution_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_export_service.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_matrix_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_scope_engine.dart';
import 'package:sports_terminal/services/nba_player_career_engine.dart';
import 'package:sports_terminal/services/nba_player_career_peak_window_engine.dart';

void main() {
  test('export preserves aligned rows, metric nulls and metadata boundary', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('left', [20, null]),
      right: _career('right', [18, 19]),
    );
    final scope = const NbaPlayerCareerComparisonScopeEngine().build(comparison);
    final matrix = const NbaPlayerCareerComparisonMatrixEngine().build(
      scope,
      metrics: [NbaPlayerCareerMetric.pointsPerGame],
    );
    final distribution =
        const NbaPlayerCareerComparisonDistributionEngine().build(scope);
    final peak = const NbaPlayerCareerPeakWindowEngine().build(
      left: comparison.left,
      right: comparison.right,
      window: 1,
    );
    final bundle = const NbaPlayerCareerComparisonExportService().build(
      matrix: matrix,
      distribution: distribution,
      peak: peak,
    );

    expect(bundle.rows, hasLength(2));
    expect(bundle.rows[1]['left_pointsPerGame'], isNull);
    expect(bundle.rows[1]['delta_pointsPerGame'], isNull);
    expect(bundle.metadata['normalization'], 'none');
    expect(bundle.metadata['alignment'], 'calendarSeason');
  });

  test('TSV and CSV include stable metric columns', () {
    final bundle = _bundle();
    expect(bundle.tsv.split('\n').first, contains('left_pointsPerGame'));
    expect(bundle.csv.split('\n').first, contains('delta_pointsPerGame'));
    expect(bundle.tsv, contains('LEFT'));
    expect(bundle.csv, contains('RIGHT'));
  });

  test('JSON export is structured and machine readable', () {
    final decoded = jsonDecode(_bundle().json) as Map<String, dynamic>;
    expect(decoded['metadata']['objectType'], 'NBA Player Career Comparison');
    expect(decoded['rows'], isA<List<dynamic>>());
    expect((decoded['rows'] as List).length, 2);
  });

  test('shared-only export contains only already-scoped rows', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _careerWithSeasons('left', {'2019-20': 30, '2020-21': 20}),
      right: _careerWithSeasons('right', {'2020-21': 18, '2021-22': 40}),
    );
    final scope = const NbaPlayerCareerComparisonScopeEngine().build(
      comparison,
      sharedOnly: true,
    );
    final matrix = const NbaPlayerCareerComparisonMatrixEngine().build(
      scope,
      metrics: [NbaPlayerCareerMetric.pointsPerGame],
    );
    final distribution =
        const NbaPlayerCareerComparisonDistributionEngine().build(scope);
    final peak = const NbaPlayerCareerPeakWindowEngine().build(
      left: comparison.left,
      right: comparison.right,
      window: 1,
    );
    final bundle = const NbaPlayerCareerComparisonExportService().build(
      matrix: matrix,
      distribution: distribution,
      peak: peak,
    );

    expect(bundle.rows, hasLength(1));
    expect(bundle.rows.single['axis'], '2020-21');
    expect(bundle.metadata['sharedOnly'], isTrue);
  });
}

NbaPlayerCareerComparisonExportBundle _bundle() {
  final comparison = const NbaPlayerCareerComparisonEngine().build(
    left: _career('left', [20, 22]),
    right: _career('right', [18, 19]),
  );
  final scope = const NbaPlayerCareerComparisonScopeEngine().build(comparison);
  final matrix = const NbaPlayerCareerComparisonMatrixEngine().build(
    scope,
    metrics: [NbaPlayerCareerMetric.pointsPerGame],
  );
  final distribution =
      const NbaPlayerCareerComparisonDistributionEngine().build(scope);
  final peak = const NbaPlayerCareerPeakWindowEngine().build(
    left: comparison.left,
    right: comparison.right,
    window: 1,
  );
  return const NbaPlayerCareerComparisonExportService().build(
    matrix: matrix,
    distribution: distribution,
    peak: peak,
  );
}

NbaPlayerCareerSnapshot _career(String key, List<double?> values) =>
    _careerWithSeasons(
      key,
      {
        for (var i = 0; i < values.length; i++) '200$i-0${i + 1}': values[i],
      },
    );

NbaPlayerCareerSnapshot _careerWithSeasons(
  String key,
  Map<String, double?> values,
) {
  final seasons = [
    for (final entry in values.entries) _season(entry.key, entry.value),
  ];
  return NbaPlayerCareerSnapshot(
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
    declaredFirstSeason: seasons.first.seasonId,
    declaredLastSeason: seasons.last.seasonId,
    declaredSeasonRows: seasons.length,
    materialConflictCount: 0,
  );
}

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
