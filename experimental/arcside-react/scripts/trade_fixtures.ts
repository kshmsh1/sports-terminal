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
   150000000,200000000)
 };
}
export function originalCbaFixtureCandidate(){
 return {kind:'ARCSIDE_INDEPENDENT_REACT_CBA_CANDIDATE_V1',
  candidateEquivalentImplemented:true,
  implementationSource:'experimental/arcside-react/src/tradeEngine.ts',
  cases:Object.fromEntries(Object.entries(originalCbaFixtureScenarios()).map(([k,s])=>
   [k,jsonTradeReport(validateTrade(s))]))};
}
