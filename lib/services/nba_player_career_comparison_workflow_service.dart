import '../models/route_payload.dart';
import 'nba_player_career_comparison_context_engine.dart';
import 'nba_player_career_comparison_engine.dart';
import 'nba_player_career_comparison_metric_engine.dart';
import 'sports_object_router.dart';

class NbaPlayerCareerComparisonWorkflowService {
  const NbaPlayerCareerComparisonWorkflowService();

  RoutePayload package({
    required NbaPlayerCareerComparisonSnapshot comparison,
    required NbaPlayerCareerComparisonMetricResult metric,
    required NbaPlayerCareerComparisonContextResult context,
    String targetRoute = 'Open',
    String league = 'NBA',
    String seasonType = 'regular',
  }) {
    final rows = <Map<String, dynamic>>[
      for (final point in metric.points)
        {
          'row_type': 'aligned_metric',
          'axis': point.axisLabel,
          'metric': metric.metric.label,
          'left_player_key': comparison.left.playerKey,
          'left_player': comparison.left.playerName,
          'left_season_id': point.leftSeasonId,
          'left_value': point.leftValue,
          'right_player_key': comparison.right.playerKey,
          'right_player': comparison.right.playerName,
          'right_season_id': point.rightSeasonId,
          'right_value': point.rightValue,
          'delta_left_minus_right': point.delta,
          'alignment': comparison.alignment.name,
        },
      {
        'row_type': 'comparison_context',
        'left_player_key': comparison.left.playerKey,
        'left_player': comparison.left.playerName,
        'right_player_key': comparison.right.playerKey,
        'right_player': comparison.right.playerName,
        'left_award_evidence_rows': context.leftAwardRows,
        'right_award_evidence_rows': context.rightAwardRows,
        'left_all_star_evidence_rows': context.leftAllStarRows,
        'right_all_star_evidence_rows': context.rightAllStarRows,
        'shared_award_labels': context.sharedAwardLabels.join(' | '),
        'shared_all_star_seasons': context.sharedAllStarSeasons.join(' | '),
      },
    ];
    final readiness = comparison.samePlayer
        ? 'Blocked'
        : (!comparison.available || rows.isEmpty ? 'Partial' : 'Ready');
    return const SportsObjectRouter().packageRows(
      datasetId:
          'nba_player_career_comparison_${comparison.left.playerKey}_${comparison.right.playerKey}',
      packageId: '${comparison.left.playerKey}__${comparison.right.playerKey}',
      displayLabel:
          '${comparison.left.playerName} vs ${comparison.right.playerName} · Career',
      sourceObjectType: 'NBA Player Career Comparison',
      rows: rows,
      targetRoute: targetRoute,
      sourceSnapshot: 'historical-player-dossiers',
      readinessState: readiness,
      filterSummary:
          'left=${comparison.left.playerKey}; right=${comparison.right.playerKey}; league=${league.toUpperCase()}; season_type=$seasonType; alignment=${comparison.alignment.name}; metric=${metric.metric.label}',
      rowKey: 'row_type',
      preferredColumns: const [
        'row_type',
        'axis',
        'metric',
        'left_player_key',
        'left_player',
        'left_season_id',
        'left_value',
        'right_player_key',
        'right_player',
        'right_season_id',
        'right_value',
        'delta_left_minus_right',
        'alignment',
      ],
      metadata: {
        'leftPlayerKey': comparison.left.playerKey,
        'leftPlayerName': comparison.left.playerName,
        'rightPlayerKey': comparison.right.playerKey,
        'rightPlayerName': comparison.right.playerName,
        'alignment': comparison.alignment.name,
        'coverage': comparison.coverageLabel,
        'sharedCalendarSeasons': comparison.sharedCalendarSeasons.join(','),
        'leftOnlyCalendarSeasons': comparison.leftOnlyCalendarSeasons.join(','),
        'rightOnlyCalendarSeasons': comparison.rightOnlyCalendarSeasons.join(','),
        'metric': metric.metric.label,
        'pairedMetricRows': metric.paired,
        'meanDeltaLeftMinusRight': metric.meanDelta,
        'leftAheadRows': metric.leftAhead,
        'rightAheadRows': metric.rightAhead,
        'tiedRows': metric.tied,
        'contextBoundary': context.boundaryLabel,
        'leftTenureCoverage': comparison.left.tenureCoverageLabel,
        'rightTenureCoverage': comparison.right.tenureCoverageLabel,
        'normalization': 'none',
      },
    );
  }
}
