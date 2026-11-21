// Deterministic original-Dart CBA reporting reference, NOT a React port.
// The independent candidate must be produced separately before comparison.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/trade_machine_engine.dart';

Object? finite(double v) => v.isFinite ? v : (v.isInfinite ? 'INFINITY' : 'NAN');

Map<String, dynamic> reportJson(TradeValidationReport report) => {
  'isValid': report.isValid,
  'errorCount': report.errorCount,
  'warningCount': report.warningCount,
  'findings': [
    for (final f in report.findings)
      {
        'code': f.code, 'message': f.message, 'severity': f.severity.name,
        'team': f.team, 'assetId': f.assetId,
      },
  ],
  'teamSummaries': {
    for (final entry in report.teamSummaries.entries)
      entry.key: {
        'team': entry.value.team,
        'incomingSalary': finite(entry.value.incomingSalary),
        'outgoingSalary': finite(entry.value.outgoingSalary),
        'postTradeSalary': finite(entry.value.postTradeSalary),
        'incomingAssets': entry.value.incomingAssets,
        'outgoingAssets': entry.value.outgoingAssets,
        'maximumIncomingSalary': finite(entry.value.maximumIncomingSalary),
        'projectedRosterPlayers': entry.value.projectedRosterPlayers,
        'cashSent': finite(entry.value.cashSent),
        'apronStatus': entry.value.apronStatus,
      },
  },
};

void main() {
  test('export original TradeMachineEngine source-backed rule scenarios', () {
    const engine = TradeMachineEngine();
    TeamCapContext team(String id, double salary) =>
        TeamCapContext.nba2026_27(team: id, teamSalary: salary);

    TradeScenario scenario(String id, List<TradeAssignment> assignments,
      {double aaaSalary = 140000000, double bbbSalary = 140000000,
       String asOfDateIso = '2026-11-20T00:00:00Z'}) =>
      TradeScenario(
        id: id, name: id, operatingSeason: '2026-27',
        teams: const ['AAA', 'BBB'], assignments: assignments,
        capContexts: {
          'AAA': team('AAA', aaaSalary), 'BBB': team('BBB', bbbSalary),
        },
        asOfDateIso: asOfDateIso,
      );

    const playerA = TradeAsset(
      id: 'a', type: TradeAssetType.player, label: 'Player A',
      originTeam: 'AAA', salary: 8000000,
    );
    const playerB = TradeAsset(
      id: 'b', type: TradeAssetType.player, label: 'Player B',
      originTeam: 'BBB', salary: 8000000,
    );
    const byc = TradeAsset(
      id: 'byc', type: TradeAssetType.player, label: 'BYC / poison pill',
      originTeam: 'AAA', salary: 20000000,
      metadata: {
        'base_year_compensation': true,
        'outgoing_matching_salary': 10000000,
        'poison_pill': true,
        'incoming_matching_salary': 25000000,
      },
    );
    const missingByc = TradeAsset(
      id: 'missing-byc', type: TradeAssetType.player, label: 'Missing BYC',
      originTeam: 'AAA', salary: 12000000,
      metadata: {'base_year_compensation': true, 'poison_pill': true},
    );
    const sat = TradeAsset(
      id: 'sat', type: TradeAssetType.player, label: 'Sign-and-trade',
      originTeam: 'AAA', salary: 20000000,
      metadata: {'sign_and_trade': true},
    );
    const restricted = TradeAsset(
      id: 'restricted', type: TradeAssetType.player, label: 'Restricted',
      originTeam: 'AAA', salary: 8000000,
      metadata: {'recently_signed_until': '2026-12-15T00:00:00Z'},
    );

    final cases = <String, TradeScenario>{
      'equal_salaries': scenario('equal_salaries', [
        const TradeAssignment(asset: playerA, destinationTeam: 'BBB'),
        const TradeAssignment(asset: playerB, destinationTeam: 'AAA'),
      ]),
      'byc_poison_pill': scenario('byc_poison_pill', [
        const TradeAssignment(asset: byc, destinationTeam: 'BBB'),
      ], aaaSalary: 120000000, bbbSalary: 100000000),
      'missing_matching_values': scenario('missing_matching_values', [
        const TradeAssignment(asset: missingByc, destinationTeam: 'BBB'),
      ]),
      'dated_restriction': scenario('dated_restriction', [
        const TradeAssignment(asset: restricted, destinationTeam: 'BBB'),
      ], asOfDateIso: '2026-11-01T00:00:00Z'),
      'sign_trade_first_apron': scenario('sign_trade_first_apron', [
        const TradeAssignment(asset: sat, destinationTeam: 'BBB'),
      ], aaaSalary: 150000000, bbbSalary: 200000000),
    };
    final result = <String, dynamic>{
      'kind': 'ARCSIDE_ORIGINAL_DART_CBA_GOLDENS_V1',
      'referenceEngine': 'lib/services/trade_machine_engine.dart',
      'operatingSeason': '2026-27',
      'candidateEquivalentImplemented': false,
      'cases': {
        for (final entry in cases.entries)
          entry.key: reportJson(engine.validate(entry.value)),
      },
    };
    expect((result['cases'] as Map).length, 5);
    final output = File('experimental/arcside-react/evidence/trade/dart-trade-reference.json');
    output.parent.createSync(recursive: true);
    output.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(result)}\n');
    print('ARCSIDE_ORIGINAL_DART_TRADE_REFERENCE: ${output.path}');
  });
}
