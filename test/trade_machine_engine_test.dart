import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/trade_machine_engine.dart';

void main() {
  const engine = TradeMachineEngine();

  TeamCapContext context(String team, double salary) =>
      TeamCapContext.nba2026_27(
        team: team,
        teamSalary: salary,
        standardRosterPlayers: 14,
        minimumStandardRosterPlayers: 12,
      );

  TradeAsset player(String id, String team, double salary,
          {Map<String, dynamic> metadata = const {}}) =>
      TradeAsset(
        id: id,
        type: TradeAssetType.player,
        label: id,
        originTeam: team,
        salary: salary,
        metadata: metadata,
      );

  test('under-cap matching uses room plus allowance, not outgoing salary', () {
    final outgoing = player('a-out', 'AAA', 5000000);
    final incoming = player('b-out', 'BBB', 16000000);
    final report = engine.validate(
      TradeScenario(
        id: 'room-rule',
        name: 'Room rule',
        operatingSeason: '2026-27',
        asOfDateIso: '2026-09-09',
        teams: const ['AAA', 'BBB'],
        assignments: [
          TradeAssignment(asset: outgoing, destinationTeam: 'BBB'),
          TradeAssignment(asset: incoming, destinationTeam: 'AAA'),
        ],
        capContexts: {
          'AAA': context('AAA', 150000000),
          'BBB': context('BBB', 180000000),
        },
      ),
    );

    expect(
      report.teamSummaries['AAA']!.maximumIncomingSalary,
      closeTo(15211000, 0.01),
    );
    expect(
      report.findings.any(
        (finding) => finding.code == 'SALARY_MATCH' && finding.team == 'AAA',
      ),
      isTrue,
    );
  });

  test('two-way contracts do not contribute matching salary or standard roster', () {
    final twoWay = player(
      'two-way',
      'AAA',
      1000000,
      metadata: const {'two_way': true},
    );
    final report = engine.validate(
      TradeScenario(
        id: 'two-way',
        name: 'Two-way',
        operatingSeason: '2026-27',
        asOfDateIso: '2026-09-09',
        teams: const ['AAA', 'BBB'],
        assignments: [
          TradeAssignment(asset: twoWay, destinationTeam: 'BBB'),
        ],
        capContexts: {
          'AAA': context('AAA', 180000000),
          'BBB': context('BBB', 180000000),
        },
      ),
    );

    expect(report.teamSummaries['AAA']!.outgoingSalary, 0);
    expect(report.teamSummaries['BBB']!.incomingSalary, 0);
    expect(report.teamSummaries['AAA']!.projectedRosterPlayers, 14);
    expect(report.teamSummaries['BBB']!.projectedRosterPlayers, 14);
    expect(
      report.findings.any((finding) => finding.code == 'TWO_WAY_CONTRACT'),
      isTrue,
    );
  });

  test('trade restricted player is a hard blocker', () {
    final restricted = player(
      'restricted',
      'AAA',
      10000000,
      metadata: const {'trade_restricted': true},
    );
    final returnPlayer = player('return', 'BBB', 10000000);
    final report = engine.validate(
      TradeScenario(
        id: 'restricted',
        name: 'Restricted',
        operatingSeason: '2026-27',
        asOfDateIso: '2026-09-09',
        teams: const ['AAA', 'BBB'],
        assignments: [
          TradeAssignment(asset: restricted, destinationTeam: 'BBB'),
          TradeAssignment(asset: returnPlayer, destinationTeam: 'AAA'),
        ],
        capContexts: {
          'AAA': context('AAA', 180000000),
          'BBB': context('BBB', 180000000),
        },
      ),
    );

    expect(report.isValid, isFalse);
    expect(
      report.findings.any((finding) => finding.code == 'TRADE_RESTRICTED'),
      isTrue,
    );
  });

  test('zero trade bonus metadata does not create a false warning', () {
    final outgoing = player(
      'plain-a',
      'AAA',
      10000000,
      metadata: const {'trade_bonus': 0},
    );
    final incoming = player('plain-b', 'BBB', 10000000);
    final report = engine.validate(
      TradeScenario(
        id: 'zero-kicker',
        name: 'Zero kicker',
        operatingSeason: '2026-27',
        asOfDateIso: '2026-09-09',
        teams: const ['AAA', 'BBB'],
        assignments: [
          TradeAssignment(asset: outgoing, destinationTeam: 'BBB'),
          TradeAssignment(asset: incoming, destinationTeam: 'AAA'),
        ],
        capContexts: {
          'AAA': context('AAA', 180000000),
          'BBB': context('BBB', 180000000),
        },
      ),
    );

    expect(
      report.findings.any((finding) => finding.code == 'TRADE_BONUS'),
      isFalse,
    );
  });

  test('more than five teams is rejected', () {
    final report = engine.validate(
      TradeScenario(
        id: 'six-teams',
        name: 'Six teams',
        operatingSeason: '2026-27',
        teams: const ['A', 'B', 'C', 'D', 'E', 'F'],
        assignments: const [],
        capContexts: {
          for (final team in const ['A', 'B', 'C', 'D', 'E', 'F'])
            team: TeamCapContext.nba2026_27(
              team: team,
              teamSalary: 180000000,
              minimumStandardRosterPlayers: 12,
            ),
        },
      ),
    );

    expect(
      report.findings.any((finding) => finding.code == 'MAX_TEAMS'),
      isTrue,
    );
  });
}
