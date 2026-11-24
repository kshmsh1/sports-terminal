import {describe,it,expect} from 'vitest';
import {reviewTeamTpes} from '../src/TradeMachinePilot';
import {nba2026Cap,validateTrade} from '../src/tradeEngine';
import type {TradeScenario} from '../src/tradeEngine';
import type {OriginalTradeException} from '../src/data';
const exception:OriginalTradeException={
 id:'BOS-test-2027',team:'BOS',expires:'2027-02-05',
 sourceTransaction:'Test player exception',original:6000000,available:6000000,note:null,
 unusableAboveSecondApron:false
};
const scenario=(salary:number):TradeScenario=>({
 id:'tpe-review',name:'TPE review',operatingSeason:'2026-27',
 teams:['BOS','PHI'],asOfDateIso:'2026-11-20T00:00:00Z',
 capContexts:{BOS:nba2026Cap('BOS',170000000),PHI:nba2026Cap('PHI',170000000)},
 assignments:salary?[{asset:{id:'p',label:'Test player',type:'player',originTeam:'PHI',salary},
  destinationTeam:'BOS'}]:[]
});
describe('original Flutter receiving-team TPE semantics',()=>{
 it('is NOT a transferable trade asset and preserves transaction assignments',()=>{
  const input=scenario(5000000),base=validateTrade(input);
  const output=reviewTeamTpes(base,input,{BOS:exception.id},[exception],'2026-11-20');
  expect(output.findings.some(x=>x.code==='TPE_OK'&&x.team==='BOS')).toBe(true);
  expect(output.teamSummaries).toEqual(base.teamSummaries);
  expect(input.assignments).toHaveLength(1);
  expect(input.assignments.every(x=>x.asset.type==='player')).toBe(true);
 });
 it('refuses to spend an exception held by a different team',()=>{
  const input=scenario(5000000),out=reviewTeamTpes(validateTrade(input),input,
   {PHI:exception.id},[exception],'2026-11-20');
  expect(out.findings.some(x=>x.code==='TPE_MISSING'&&x.team==='PHI')).toBe(true);
 });
 it('records expired, empty and over-capacity exceptions as errors',()=>{
  for(const [at,code,value] of [
   ['2027-03-01','TPE_EXPIRED',5000000],
   ['2026-11-20','TPE_AMOUNT',9000000]
  ] as const){
   const input=scenario(value);
   const out=reviewTeamTpes(validateTrade(input),input,{BOS:exception.id},[exception],at);
   expect(out.findings.some(x=>x.code===code&&x.severity==='error')).toBe(true);
  }
 });
 it('warns instead of pretending a TPE is useful with no receiving players',()=>{
  const input=scenario(0),out=reviewTeamTpes(validateTrade(input),input,
   {BOS:exception.id},[exception],'2026-11-20');
  expect(out.findings.some(x=>x.code==='TPE_UNUSED'&&x.severity==='warning')).toBe(true);
 });
});
