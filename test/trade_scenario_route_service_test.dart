import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/trade_machine_engine.dart';
import 'package:sports_terminal/services/trade_scenario_route_service.dart';

void main() {
  test('trade scenario becomes a structured cross-product package', () {
    const scenario = TradeScenario(
      id: 'scenario-1',
      name: 'BOS PHI model',
      operatingSeason: '2026-27',
      teams: ['BOS', 'PHI'],
      assignments: [
        TradeAssignment(
          asset: TradeAsset(
            id: 'bos-player',
            type: TradeAssetType.player,
            label: 'Modeled BOS Player',
            originTeam: 'BOS',
            salary: 20000000,
          ),
          destinationTeam: 'PHI',
        ),
      ],
      capContexts: {
        'BOS': TeamCapContext(
          team: 'BOS',
          teamSalary: 250000000,
          salaryCap: 164961000,
          taxLine: 200428000,
          firstApron: 209015000,
          secondApron: 221686000,
        ),
        'PHI': TeamCapContext(
          team: 'PHI',
          teamSalary: 170000000,
          salaryCap: 164961000,
          taxLine: 200428000,
          firstApron: 209015000,
          secondApron: 221686000,
        ),
      },
    );
    final report = const TradeMachineEngine().validate(scenario);
    final payload = const TradeScenarioRouteService().packageScenario(
      scenario: scenario,
      report: report,
      targetRoute: 'Python Lab',
    );
    expect(payload.sourceObjectType, 'TradeScenario');
    expect(payload.targetRoute, 'Python Lab');
    expect(payload.rows.any((row) => row['record_type'] == 'team_summary'), isTrue);
    expect(payload.rows.any((row) => row['record_type'] == 'asset_assignment'), isTrue);
    expect(payload.metadata['teamCount'], 2);
    expect(payload.blockers, isNotEmpty);
  });
}
