import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_stats_query_engine.dart';
import 'package:sports_terminal/services/trade_machine_engine.dart';

void main() {
  group('NbaStatsQueryEngine', () {
    const engine = NbaStatsQueryEngine();

    test('parses multi-constraint natural language queries', () {
      final plan = engine.parse('List players over age 29 with ppg > 15 and rpg < 4 and fg% > 50 in the playoffs');
      expect(plan.seasonType, 'Playoffs');
      expect(plan.constraints.any((item) => item.field == 'age' && item.value == 29), isTrue);
      expect(plan.constraints.any((item) => item.field == 'ppg' && item.value == 15), isTrue);
      expect(plan.constraints.any((item) => item.field == 'rpg' && item.value == 4), isTrue);
      expect(plan.constraints.any((item) => item.field == 'fg_pct' && item.value == .50), isTrue);
    });

    test('applies filters, ordering and limits', () {
      final plan = engine.parse('top 2 ppg > 10 sort by points');
      final result = plan.apply([
        {'name': 'A', 'ppg': 12.0},
        {'name': 'B', 'ppg': 25.0},
        {'name': 'C', 'ppg': 18.0},
        {'name': 'D', 'ppg': 8.0},
      ]);
      expect(result.map((row) => row['name']).toList(), ['B', 'C']);
    });

    test('detects per-36 and per-100 bases', () {
      expect(engine.parse('players per 36 minutes').basis, 'Per 36 Minutes');
      expect(engine.parse('players per 100 possessions').basis, 'Per 100 Possessions');
    });
  });

  group('TradeMachineEngine', () {
    const engine = TradeMachineEngine();

    TeamCapContext cap(String team, {double salary = 150}) => TeamCapContext(
          team: team,
          teamSalary: salary,
          salaryCap: 140,
          taxLine: 170,
          firstApron: 180,
          secondApron: 190,
        );

    test('summarizes valid two-team player exchange', () {
      final scenario = TradeScenario(
        id: 'scenario-1',
        name: 'Guard swap',
        operatingSeason: '2026-27',
        teams: const ['BOS', 'PHI'],
        capContexts: {'BOS': cap('BOS'), 'PHI': cap('PHI')},
        assignments: const [
          TradeAssignment(asset: TradeAsset(id: 'p1', type: TradeAssetType.player, label: 'Player One', originTeam: 'BOS', salary: 20), destinationTeam: 'PHI'),
          TradeAssignment(asset: TradeAsset(id: 'p2', type: TradeAssetType.player, label: 'Player Two', originTeam: 'PHI', salary: 18), destinationTeam: 'BOS'),
        ],
      );
      final report = engine.validate(scenario);
      expect(report.isValid, isTrue);
      expect(report.teamSummaries['BOS']!.postTradeSalary, 148);
      expect(report.teamSummaries['PHI']!.postTradeSalary, 152);
    });

    test('rejects duplicate assets and same-team routing', () {
      final asset = const TradeAsset(id: 'p1', type: TradeAssetType.player, label: 'Player One', originTeam: 'BOS', salary: 20);
      final scenario = TradeScenario(
        id: 'scenario-2',
        name: 'Invalid',
        operatingSeason: '2026-27',
        teams: const ['BOS', 'PHI'],
        capContexts: {'BOS': cap('BOS'), 'PHI': cap('PHI')},
        assignments: [
          TradeAssignment(asset: asset, destinationTeam: 'BOS'),
          TradeAssignment(asset: asset, destinationTeam: 'PHI'),
        ],
      );
      final report = engine.validate(scenario);
      expect(report.isValid, isFalse);
      expect(report.findings.any((item) => item.code == 'DUPLICATE_ASSET'), isTrue);
      expect(report.findings.any((item) => item.code == 'SAME_TEAM'), isTrue);
    });

    test('flags hard-cap and exception review', () {
      final scenario = TradeScenario(
        id: 'scenario-3',
        name: 'Exception test',
        operatingSeason: '2026-27',
        teams: const ['BOS', 'PHI'],
        capContexts: {
          'BOS': TeamCapContext(team: 'BOS', teamSalary: 178, salaryCap: 140, taxLine: 170, firstApron: 180, secondApron: 190, hardCappedAt: 181),
          'PHI': cap('PHI'),
        },
        assignments: const [
          TradeAssignment(asset: TradeAsset(id: 'p2', type: TradeAssetType.player, label: 'Player Two', originTeam: 'PHI', salary: 10), destinationTeam: 'BOS'),
          TradeAssignment(asset: TradeAsset(id: 'tpe1', type: TradeAssetType.tradeException, label: 'TPE', originTeam: 'BOS'), destinationTeam: 'PHI'),
        ],
      );
      final report = engine.validate(scenario);
      expect(report.findings.any((item) => item.code == 'HARD_CAP'), isTrue);
      expect(report.findings.any((item) => item.code == 'EXCEPTION_REVIEW'), isTrue);
    });
  });
}
