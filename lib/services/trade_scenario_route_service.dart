import '../models/route_payload.dart';
import 'sports_object_router.dart';
import 'trade_machine_engine.dart';

class TradeScenarioRouteService {
  const TradeScenarioRouteService();

  RoutePayload packageScenario({
    required TradeScenario scenario,
    required TradeValidationReport report,
    required String targetRoute,
  }) {
    final rows = <Map<String, dynamic>>[];
    for (final team in scenario.teams) {
      final summary = report.teamSummaries[team];
      final context = scenario.capContexts[team];
      rows.add({
        'record_type': 'team_summary',
        'scenario_id': scenario.id,
        'scenario_name': scenario.name,
        'operating_season': scenario.operatingSeason,
        'team_id': team,
        'outgoing_salary': summary?.outgoingSalary ?? 0,
        'incoming_salary': summary?.incomingSalary ?? 0,
        'post_trade_salary': summary?.postTradeSalary ?? context?.teamSalary ?? 0,
        'outgoing_assets': summary?.outgoingAssets ?? 0,
        'incoming_assets': summary?.incomingAssets ?? 0,
        'pre_trade_salary': context?.teamSalary ?? 0,
        'salary_cap': context?.salaryCap ?? 0,
        'tax_line': context?.taxLine ?? 0,
        'first_apron': context?.firstApron ?? 0,
        'second_apron': context?.secondApron ?? 0,
        'hard_cap': context?.hardCappedAt,
        'report_valid': report.isValid,
        'requires_review': report.requiresReview,
      });
    }
    for (final assignment in scenario.assignments) {
      rows.add({
        'record_type': 'asset_assignment',
        'scenario_id': scenario.id,
        'scenario_name': scenario.name,
        'operating_season': scenario.operatingSeason,
        'asset_id': assignment.asset.id,
        'asset_type': assignment.asset.type.name,
        'asset_label': assignment.asset.label,
        'origin_team': assignment.asset.originTeam,
        'destination_team': assignment.destinationTeam,
        'salary': assignment.asset.salary,
        'metadata': assignment.asset.metadata.entries.map((entry) => '${entry.key}=${entry.value}').join('; '),
      });
    }
    for (final finding in report.findings) {
      rows.add({
        'record_type': 'validation_finding',
        'scenario_id': scenario.id,
        'scenario_name': scenario.name,
        'operating_season': scenario.operatingSeason,
        'finding_code': finding.code,
        'finding_message': finding.message,
        'finding_severity': finding.severity.name,
        'team_id': finding.team ?? '',
      });
    }
    return const SportsObjectRouter().packageRows(
      datasetId: 'trade_scenario_${scenario.id}',
      displayLabel: '${scenario.name} · Trade Scenario',
      sourceObjectType: 'TradeScenario',
      rows: rows,
      targetRoute: targetRoute,
      sourceSnapshot: 'Sports Terminal Trade Machine · ${scenario.operatingSeason}',
      readinessState: report.isValid ? (report.requiresReview ? 'Valid with review flags' : 'Structurally valid') : 'Invalid',
      rowKey: 'record_type',
      preferredColumns: const [
        'record_type',
        'team_id',
        'asset_label',
        'asset_type',
        'origin_team',
        'destination_team',
        'salary',
        'outgoing_salary',
        'incoming_salary',
        'post_trade_salary',
        'finding_code',
        'finding_message',
        'finding_severity',
      ],
      blockers: [
        for (final finding in report.findings)
          if (finding.severity == TradeValidationSeverity.error || finding.severity == TradeValidationSeverity.warning)
            '${finding.code}: ${finding.message}',
      ],
      metadata: {
        'scenarioId': scenario.id,
        'operatingSeason': scenario.operatingSeason,
        'teamCount': scenario.teams.length,
        'assignmentCount': scenario.assignments.length,
        'findingCount': report.findings.length,
        'valid': report.isValid,
        'requiresReview': report.requiresReview,
      },
    );
  }
}
