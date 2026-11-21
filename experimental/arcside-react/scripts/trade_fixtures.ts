// Exact fixtures constructed independently in TypeScript, matching the original
// Dart phase3_trade_reference_export_test.dart scenario inputs.
import {nba2026Cap,validateTrade,jsonTradeReport} from '../src/tradeEngine.ts';
import type {TradeAsset,TradeAssignment,TradeScenario} from '../src/tradeEngine.ts';
export function originalCbaFixtureScenarios():Record<string,TradeScenario>{
 const player=(id:string,label:string,originTeam:string,salary:number,metadata:Record<string,unknown>={}):TradeAsset=>
  ({id,type:'player',label,originTeam,salary,metadata});
 const a=player('a','Player A','AAA',8000000),b=player('b','Player B','BBB',8000000);
 const byc=player('byc','BYC / poison pill','AAA',20000000,{
  base_year_compensation:true,outgoing_matching_salary:10000000,
  poison_pill:true,incoming_matching_salary:25000000});
 const missingByc=player('missing-byc','Missing BYC','AAA',12000000,{
  base_year_compensation:true,poison_pill:true});
 const sat=player('sat','Sign-and-trade','AAA',20000000,{sign_and_trade:true});
 const restricted=player('restricted','Restricted','AAA',8000000,{
  recently_signed_until:'2026-12-15T00:00:00Z'});
 const cash:TradeAsset={id:'cash',type:'cash',label:'Cash',originTeam:'AAA',salary:400000,metadata:{amount:400000}};
 const pick28:TradeAsset={id:'first28',type:'draftPick',label:'2028 first',originTeam:'AAA',
  salary:0,metadata:{round:'1',draft_year:2028,protection:'top-5'}};
 const pick29:TradeAsset={id:'first29',type:'draftPick',label:'2029 first',originTeam:'AAA',
  salary:0,metadata:{round:'1',draft_year:2029}};
 const twoWay=player('two-way','Two-way contract','AAA',1200000,{two_way:true});
 const exception:TradeAsset={id:'exception',type:'tradeException',label:'Expired TPE',
  originTeam:'AAA',salary:0,metadata:{amount:5000000,expires_at:'2026-10-01T00:00:00Z'}};
 const restrictedBonus=player('restricted-bonus','Restricted bonus','AAA',8000000,{
  no_trade:true,trade_restricted:true,cannot_aggregate:true,trade_bonus:500000});
 const secondPlayer=player('second-player','Second outgoing player','AAA',7000000);
 const assign=(asset:TradeAsset,destinationTeam:string):TradeAssignment=>({asset,destinationTeam});
 const scenario=(id:string,assignments:TradeAssignment[],aaaSalary=140000000,
  bbbSalary=140000000,asOfDateIso='2026-11-20T00:00:00Z'):TradeScenario=>
  ({id,name:id,operatingSeason:'2026-27',teams:['AAA','BBB'],assignments,
   capContexts:{AAA:nba2026Cap('AAA',aaaSalary),BBB:nba2026Cap('BBB',bbbSalary)},asOfDateIso});
 return {
  equal_salaries:scenario('equal_salaries',[assign(a,'BBB'),assign(b,'AAA')]),
  byc_poison_pill:scenario('byc_poison_pill',[assign(byc,'BBB')],120000000,100000000),
  missing_matching_values:scenario('missing_matching_values',[assign(missingByc,'BBB')]),
  dated_restriction:scenario('dated_restriction',[assign(restricted,'BBB')],
   140000000,140000000,'2026-11-01T00:00:00Z'),
  sign_trade_first_apron:scenario('sign_trade_first_apron',[assign(sat,'BBB')],
   150000000,200000000),
  empty_scenario:scenario('empty_scenario',[]),
  duplicate_assignment:scenario('duplicate_assignment',[assign(a,'BBB'),assign(a,'BBB')]),
  two_way_salary_exclusion:scenario('two_way_salary_exclusion',[assign(twoWay,'BBB')]),
  pick_protection_stepien:scenario('pick_protection_stepien',
   [assign(pick28,'BBB'),assign(pick29,'BBB')]),
  exception_expired:scenario('exception_expired',[assign(exception,'BBB')]),
  restricted_bonus:scenario('restricted_bonus',
   [assign(restrictedBonus,'BBB'),assign(secondPlayer,'BBB')]),
  second_apron_cash_aggregation:scenario('second_apron_cash_aggregation',
   [assign(cash,'BBB'),assign(a,'BBB'),assign(secondPlayer,'BBB'),assign(b,'AAA')],
   240000000,140000000),
  missing_cap_context:{
   ...scenario('missing_cap_context',[assign(a,'BBB')]),
   capContexts:{AAA:nba2026Cap('AAA',140000000)}
  },
  cash_limit:{
   ...scenario('cash_limit',[assign(cash,'BBB')]),
   capContexts:{AAA:nba2026Cap('AAA',140000000,{
    cashSentThisSeason:100000,cashLimitThisSeason:300000}),
    BBB:nba2026Cap('BBB',140000000)}
  },
  hard_cap:{
   ...scenario('hard_cap',[assign(b,'AAA')]),
   capContexts:{AAA:nba2026Cap('AAA',210000000,{hardCappedAt:209015000}),
    BBB:nba2026Cap('BBB',140000000)}
  }
 };
}
export function originalCbaFixtureCandidate(){
 return {kind:'ARCSIDE_INDEPENDENT_REACT_CBA_CANDIDATE_V1',
  candidateEquivalentImplemented:true,
  implementationSource:'experimental/arcside-react/src/tradeEngine.ts',
  cases:Object.fromEntries(Object.entries(originalCbaFixtureScenarios()).map(([k,s])=>
   [k,jsonTradeReport(validateTrade(s))]))};
}
