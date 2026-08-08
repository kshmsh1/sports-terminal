import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/trade_machine_engine.dart';

void main() {
  const engine = TradeMachineEngine();
  final thresholds = NbaCbaSeasonThresholds.seasons['2025-26']!;

  TeamCapContext context(String team, double salary, {int roster = 15}) =>
      TeamCapContext(
        team: team,
        teamSalary: salary,
        salaryCap: thresholds.salaryCap,
        taxLine: thresholds.taxLine,
        firstApron: thresholds.firstApron,
        secondApron: thresholds.secondApron,
        standardRosterCount: roster,
      );

  TradeAsset player(
    String id,
    String team,
    double salary, {
    Map<String, dynamic> metadata = const {},
  }) => TradeAsset(
    id: id,
    type: TradeAssetType.player,
    label: id,
    originTeam: team,
    salary: salary,
    metadata: metadata,
  );

  test(
    'ordinary below-apron salary matching exposes incoming ceiling and headroom',
    () {
      final scenario = TradeScenario(
        id: 'salary-pass',
        name: 'Salary pass',
        operatingSeason: '2025-26',
        teams: const ['BOS', 'NYK'],
        capContexts: {
          'BOS': context('BOS', 175000000),
          'NYK': context('NYK', 175000000),
        },
        assignments: [
          TradeAssignment(
            asset: player('BOS Player', 'BOS', 20000000),
            destinationTeam: 'NYK',
          ),
          TradeAssignment(
            asset: player('NYK Player', 'NYK', 19000000),
            destinationTeam: 'BOS',
          ),
        ],
      );
      final report = engine.validate(scenario);
      expect(report.errorCount, 0);
      expect(
        report.teamSummaries['BOS']!.allowedIncomingSalary,
        greaterThanOrEqualTo(19000000),
      );
      expect(
        report.teamSummaries['BOS']!.salaryMatchingRoom,
        greaterThanOrEqualTo(0),
      );
    },
  );

  test('second-apron team cannot aggregate multiple outgoing players', () {
    final scenario = TradeScenario(
      id: 'aggregation',
      name: 'Second apron aggregation',
      operatingSeason: '2025-26',
      teams: const ['BOS', 'NYK'],
      capContexts: {
        'BOS': context('BOS', thresholds.secondApron + 1000000),
        'NYK': context('NYK', 175000000),
      },
      assignments: [
        TradeAssignment(
          asset: player('BOS A', 'BOS', 10000000),
          destinationTeam: 'NYK',
        ),
        TradeAssignment(
          asset: player('BOS B', 'BOS', 9000000),
          destinationTeam: 'NYK',
        ),
        TradeAssignment(
          asset: player('NYK A', 'NYK', 18000000),
          destinationTeam: 'BOS',
        ),
      ],
    );
    final report = engine.validate(scenario);
    expect(
      report.findings.any((item) => item.code == 'SECOND_APRON_AGGREGATION'),
      isTrue,
    );
    expect(report.isValid, isFalse);
  });

  test(
    'no-trade clause blocks without consent and clears when consent is true',
    () {
      TradeScenario build(bool consent) => TradeScenario(
        id: 'ntc-$consent',
        name: 'NTC',
        operatingSeason: '2025-26',
        teams: const ['BOS', 'NYK'],
        capContexts: {
          'BOS': context('BOS', 175000000),
          'NYK': context('NYK', 175000000),
        },
        assignments: [
          TradeAssignment(
            asset: player(
              'BOS NTC',
              'BOS',
              10000000,
              metadata: {'no_trade_clause': true, 'trade_consent': consent},
            ),
            destinationTeam: 'NYK',
          ),
          TradeAssignment(
            asset: player('NYK Return', 'NYK', 9000000),
            destinationTeam: 'BOS',
          ),
        ],
      );

      expect(
        engine
            .validate(build(false))
            .findings
            .any((item) => item.code == 'NO_TRADE_CONSENT'),
        isTrue,
      );
      expect(
        engine
            .validate(build(true))
            .findings
            .any((item) => item.code == 'NO_TRADE_CONSENT'),
        isFalse,
      );
    },
  );

  test('Stepien screen catches consecutive outgoing unprotected firsts', () {
    final scenario = TradeScenario(
      id: 'stepien',
      name: 'Stepien',
      operatingSeason: '2025-26',
      teams: const ['BOS', 'NYK'],
      capContexts: {
        'BOS': context('BOS', 175000000),
        'NYK': context('NYK', 175000000),
      },
      assignments: const [
        TradeAssignment(
          asset: TradeAsset(
            id: 'bos-2028-1',
            type: TradeAssetType.draftPick,
            label: 'BOS 2028 1st',
            originTeam: 'BOS',
            metadata: {'year': 2028, 'round': 1, 'protected': false},
          ),
          destinationTeam: 'NYK',
        ),
        TradeAssignment(
          asset: TradeAsset(
            id: 'bos-2029-1',
            type: TradeAssetType.draftPick,
            label: 'BOS 2029 1st',
            originTeam: 'BOS',
            metadata: {'year': 2029, 'round': 1, 'protected': false},
          ),
          destinationTeam: 'NYK',
        ),
      ],
    );
    final report = engine.validate(scenario);
    expect(
      report.findings.any((item) => item.code == 'STEPIEN_CONSECUTIVE_FIRSTS'),
      isTrue,
    );
  });

  test('frozen second-apron pick cannot be sent', () {
    final scenario = TradeScenario(
      id: 'frozen',
      name: 'Frozen pick',
      operatingSeason: '2025-26',
      teams: const ['BOS', 'NYK'],
      capContexts: {
        'BOS': context('BOS', 175000000),
        'NYK': context('NYK', 175000000),
      },
      assignments: const [
        TradeAssignment(
          asset: TradeAsset(
            id: 'frozen-first',
            type: TradeAssetType.draftPick,
            label: 'Frozen first',
            originTeam: 'BOS',
            metadata: {'year': 2032, 'round': 1, 'frozen': true},
          ),
          destinationTeam: 'NYK',
        ),
      ],
    );
    final report = engine.validate(scenario);
    expect(report.findings.any((item) => item.code == 'FROZEN_PICK'), isTrue);
  });
}
