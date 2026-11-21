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

    const cash = TradeAsset(
      id:'cash',type:TradeAssetType.cash,label:'Cash',originTeam:'AAA',
      salary:400000,metadata:{'amount':400000},
    );
    const first2028 = TradeAsset(
      id:'first28',type:TradeAssetType.draftPick,label:'2028 first',
      originTeam:'AAA',metadata:{'round':'1','draft_year':2028,'protection':'top-5'},
    );
    const first2029 = TradeAsset(
      id:'first29',type:TradeAssetType.draftPick,label:'2029 first',
      originTeam:'AAA',metadata:{'round':'1','draft_year':2029},
    );
    const twoWay = TradeAsset(
      id:'two-way',type:TradeAssetType.player,label:'Two-way contract',
      originTeam:'AAA',salary:1200000,metadata:{'two_way':true},
    );
    const exception = TradeAsset(
      id:'exception',type:TradeAssetType.tradeException,label:'Expired TPE',
      originTeam:'AAA',metadata:{'amount':5000000,'expires_at':'2026-10-01T00:00:00Z'},
    );
    const restrictedBonus = TradeAsset(
      id:'restricted-bonus',type:TradeAssetType.player,label:'Restricted bonus',
      originTeam:'AAA',salary:8000000,
      metadata:{'no_trade':true,'trade_restricted':true,'cannot_aggregate':true,'trade_bonus':500000},
    );
    const secondPlayer = TradeAsset(
      id:'second-player',type:TradeAssetType.player,label:'Second outgoing player',
      originTeam:'AAA',salary:7000000,
    );
    const playerC = TradeAsset(id:'c',type:TradeAssetType.player,label:'Player C',
      originTeam:'CCC',salary:8000000);
    const playerD = TradeAsset(id:'d',type:TradeAssetType.player,label:'Player D',
      originTeam:'DDD',salary:8000000);
    const playerE = TradeAsset(id:'e',type:TradeAssetType.player,label:'Player E',
      originTeam:'EEE',salary:8000000);
    const frozenPick = TradeAsset(id:'frozen',type:TradeAssetType.draftPick,
      label:'Frozen first',originTeam:'AAA',metadata:{'frozen':true});
    const distantPick = TradeAsset(id:'distant',type:TradeAssetType.draftPick,
      label:'2034 first',originTeam:'AAA',metadata:{'years_out':8});
    const swapPick = TradeAsset(id:'swap',type:TradeAssetType.draftPick,
      label:'Swap first',originTeam:'AAA',metadata:{'swap_right':true});
    const zeroCash = TradeAsset(id:'zero-cash',type:TradeAssetType.cash,
      label:'Cash not supplied',originTeam:'AAA',metadata:{'amount':0});
    final missingContext = scenario('missing_context', [
      const TradeAssignment(asset: playerA,destinationTeam:'BBB'),
    ]);
    final secondApron = scenario('second_apron_cash_aggregation', [
      const TradeAssignment(asset: cash,destinationTeam:'BBB'),
      const TradeAssignment(asset: playerA,destinationTeam:'BBB'),
      const TradeAssignment(asset: secondPlayer,destinationTeam:'BBB'),
      const TradeAssignment(asset: playerB,destinationTeam:'AAA'),
    ],aaaSalary:240000000,bbbSalary:140000000);
    final cashLimit = scenario('cash_limit', [
      const TradeAssignment(asset: cash,destinationTeam:'BBB'),
    ]);
    final hardCap = scenario('hard_cap', [
      const TradeAssignment(asset: playerB,destinationTeam:'AAA'),
    ]);
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
      'empty_scenario': scenario('empty_scenario', []),
      'duplicate_assignment': scenario('duplicate_assignment', [
        const TradeAssignment(asset: playerA,destinationTeam:'BBB'),
        const TradeAssignment(asset: playerA,destinationTeam:'BBB'),
      ]),
      'two_way_salary_exclusion': scenario('two_way_salary_exclusion', [
        const TradeAssignment(asset: twoWay,destinationTeam:'BBB'),
      ]),
      'pick_protection_stepien': scenario('pick_protection_stepien', [
        const TradeAssignment(asset: first2028,destinationTeam:'BBB'),
        const TradeAssignment(asset: first2029,destinationTeam:'BBB'),
      ]),
      'exception_expired': scenario('exception_expired', [
        const TradeAssignment(asset: exception,destinationTeam:'BBB'),
      ]),
      'restricted_bonus': scenario('restricted_bonus', [
        const TradeAssignment(asset: restrictedBonus,destinationTeam:'BBB'),
        const TradeAssignment(asset: secondPlayer,destinationTeam:'BBB'),
      ]),
      'second_apron_cash_aggregation': secondApron,
      'missing_cap_context': TradeScenario(
        id:'missing_cap_context',name:'missing_cap_context',operatingSeason:'2026-27',
        teams:const ['AAA','BBB'],assignments:missingContext.assignments,
        capContexts:{'AAA':team('AAA',140000000)},asOfDateIso:'2026-11-20T00:00:00Z',
      ),
      'cash_limit': TradeScenario(
        id:'cash_limit',name:'cash_limit',operatingSeason:'2026-27',
        teams:const ['AAA','BBB'],assignments:cashLimit.assignments,
        capContexts:{
          'AAA':TeamCapContext.nba2026_27(
             team:'AAA',teamSalary:140000000,cashSentThisSeason:100000,cashLimitThisSeason:300000,
          ),
          'BBB':team('BBB',140000000),
        },asOfDateIso:'2026-11-20T00:00:00Z',
      ),
      'hard_cap': TradeScenario(
        id:'hard_cap',name:'hard_cap',operatingSeason:'2026-27',
        teams:const ['AAA','BBB'],assignments:hardCap.assignments,
        capContexts:{
          'AAA':TeamCapContext.nba2026_27(
            team:'AAA',teamSalary:210000000,hardCappedAt:209015000),
          'BBB':team('BBB',140000000),
        },asOfDateIso:'2026-11-20T00:00:00Z',
      ),
      'three_team_rotation': TradeScenario(
        id:'three_team_rotation',name:'three_team_rotation',operatingSeason:'2026-27',
        teams:const ['AAA','BBB','CCC'],
        assignments: const [
          TradeAssignment(asset:playerA,destinationTeam:'BBB'),
          TradeAssignment(asset:playerB,destinationTeam:'CCC'),
          TradeAssignment(asset:playerC,destinationTeam:'AAA'),
        ],
        capContexts:{'AAA':team('AAA',140000000),'BBB':team('BBB',140000000),
          'CCC':team('CCC',140000000)},
        asOfDateIso:'2026-11-20T00:00:00Z',
      ),
      'five_team_rotation': TradeScenario(
        id:'five_team_rotation',name:'five_team_rotation',operatingSeason:'2026-27',
        teams:const ['AAA','BBB','CCC','DDD','EEE'],
        assignments:const [
          TradeAssignment(asset:playerA,destinationTeam:'BBB'),
          TradeAssignment(asset:playerB,destinationTeam:'CCC'),
          TradeAssignment(asset:playerC,destinationTeam:'DDD'),
          TradeAssignment(asset:playerD,destinationTeam:'EEE'),
          TradeAssignment(asset:playerE,destinationTeam:'AAA'),
        ],
        capContexts:{for (final id in const ['AAA','BBB','CCC','DDD','EEE'])
          id:team(id,140000000)},
        asOfDateIso:'2026-11-20T00:00:00Z',
      ),
      'six_team_rejection': TradeScenario(
        id:'six_team_rejection',name:'six_team_rejection',operatingSeason:'2026-27',
        teams:const ['AAA','BBB','CCC','DDD','EEE','FFF'],assignments:const [],
        capContexts:{for(final id in const ['AAA','BBB','CCC','DDD','EEE','FFF'])
          id:team(id,140000000)},
        asOfDateIso:'2026-11-20T00:00:00Z',
      ),
      'same_team_destination':scenario('same_team_destination',[
        const TradeAssignment(asset:playerA,destinationTeam:'AAA'),
      ]),
      'unknown_destination':scenario('unknown_destination',[
        const TradeAssignment(asset:playerA,destinationTeam:'ZZZ'),
      ]),
      'frozen_draft_pick':scenario('frozen_draft_pick',[
        const TradeAssignment(asset:frozenPick,destinationTeam:'BBB'),
      ]),
      'distant_draft_pick':scenario('distant_draft_pick',[
        const TradeAssignment(asset:distantPick,destinationTeam:'BBB'),
      ]),
      'swap_draft_pick':scenario('swap_draft_pick',[
        const TradeAssignment(asset:swapPick,destinationTeam:'BBB'),
      ]),
      'missing_asof_restriction':scenario('missing_asof_restriction',[
        const TradeAssignment(asset:restricted,destinationTeam:'BBB'),
      ],asOfDateIso:''),
      'missing_cash_amount':scenario('missing_cash_amount',[
        const TradeAssignment(asset:zeroCash,destinationTeam:'BBB'),
      ]),
      'sign_trade_below_apron':scenario('sign_trade_below_apron',[
        const TradeAssignment(asset:sat,destinationTeam:'BBB'),
      ]),
      'future_trade_exception':scenario('future_trade_exception',[
        const TradeAssignment(asset:TradeAsset(id:'exception',
          type:TradeAssetType.tradeException,label:'Expired TPE',originTeam:'AAA',
          metadata:{'amount':5000000,'expires_at':'2027-10-01T00:00:00Z'}),
          destinationTeam:'BBB'),
      ]),
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
    expect((result['cases'] as Map).length, 27);
    final output = File('experimental/arcside-react/evidence/trade/dart-trade-reference.json');
    output.parent.createSync(recursive: true);
    output.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(result)}\n');
    print('ARCSIDE_ORIGINAL_DART_TRADE_REFERENCE: ${output.path}');
  });
}
