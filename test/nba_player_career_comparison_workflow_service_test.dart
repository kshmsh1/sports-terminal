import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_career_analytics_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_context_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_metric_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_workflow_service.dart';
import 'package:sports_terminal/services/nba_player_career_context_engine.dart';
import 'package:sports_terminal/services/nba_player_career_engine.dart';

NbaPlayerCareerSnapshot _career(String key, double points) => NbaPlayerCareerSnapshot(
      playerKey: key,
      playerName: key == 'a' ? 'Alpha' : 'Beta',
      primaryPosition: 'G',
      activeFrom: '',
      activeTo: '',
      nbaId: '',
      brefId: '',
      identityConfidence: null,
      sourceCount: null,
      seasons: [
        NbaPlayerCareerSeason(
          seasonId: '2020-21',
          seasonType: 'regular',
          leagueId: 'NBA',
          teamKey: '',
          teamName: '',
          teamAbbreviation: 'TOT',
          franchiseKey: '',
          franchiseName: '',
          games: 10,
          gamesStarted: null,
          minutes: null,
          points: points,
          rebounds: null,
          assists: null,
          steals: null,
          blocks: null,
          turnovers: null,
          trueShootingPct: null,
          playerEfficiencyRating: null,
          winShares: null,
          boxPlusMinus: null,
          valueOverReplacement: null,
          syntheticAggregate: true,
          source: 'test',
        ),
      ],
      tenures: const [],
      missingTeamDossierKeys: const [],
      multiTeamAggregateSeasons: const [],
      declaredFirstSeason: '2020-21',
      declaredLastSeason: '2020-21',
      declaredSeasonRows: 1,
      materialConflictCount: 0,
    );

const _emptyContext = NbaPlayerCareerContext(
  awards: [],
  allStarSelections: [],
  draftRecords: [],
  recentGames: [],
  identityRows: 1,
  conflictRows: 0,
  fieldProvenanceRows: 1,
);

void main() {
  test('packages aligned comparison rows into shared RoutePayload state', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('a', 200),
      right: _career('b', 180),
    );
    final metric = const NbaPlayerCareerComparisonMetricEngine().build(
      comparison,
      metric: NbaPlayerCareerMetric.pointsPerGame,
    );
    final context = const NbaPlayerCareerComparisonContextEngine().build(
      left: _emptyContext,
      right: _emptyContext,
    );
    final payload = const NbaPlayerCareerComparisonWorkflowService().package(
      comparison: comparison,
      metric: metric,
      context: context,
      targetRoute: 'Python Lab',
    );

    expect(payload.sourceObjectType, 'NBA Player Career Comparison');
    expect(payload.targetRoute, 'Python Lab');
    expect(payload.readinessState, 'Ready');
    expect(payload.rows.first['left_value'], 20);
    expect(payload.rows.first['right_value'], 18);
    expect(payload.metadata['normalization'], 'none');
  });

  test('same canonical Player comparison is explicitly blocked', () {
    final same = _career('a', 200);
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: same,
      right: same,
    );
    final metric = const NbaPlayerCareerComparisonMetricEngine().build(comparison);
    final context = const NbaPlayerCareerComparisonContextEngine().build(
      left: _emptyContext,
      right: _emptyContext,
    );
    final payload = const NbaPlayerCareerComparisonWorkflowService().package(
      comparison: comparison,
      metric: metric,
      context: context,
    );
    expect(payload.readinessState, 'Blocked');
  });

  test('career-year alignment remains explicit in route metadata', () {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: _career('a', 200),
      right: _career('b', 180),
      alignment: NbaPlayerCareerComparisonAlignment.careerYear,
    );
    final metric = const NbaPlayerCareerComparisonMetricEngine().build(comparison);
    final context = const NbaPlayerCareerComparisonContextEngine().build(
      left: _emptyContext,
      right: _emptyContext,
    );
    final payload = const NbaPlayerCareerComparisonWorkflowService().package(
      comparison: comparison,
      metric: metric,
      context: context,
    );
    expect(payload.metadata['alignment'], 'careerYear');
    expect(payload.filterSummary, contains('alignment=careerYear'));
  });
}
