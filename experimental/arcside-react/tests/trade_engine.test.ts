import {describe,it,expect} from 'vitest';
import {validateTrade,nba2026Cap,jsonTradeReport} from '../src/tradeEngine';
import {originalCbaFixtureScenarios,originalCbaFixtureCandidate} from '../scripts/trade_fixtures';
import type {TradeAsset,TradeScenario} from '../src/tradeEngine';
const a=(id:string,team:string,salary:number,metadata:Record<string,unknown>={},
 type:TradeAsset['type']='player'):TradeAsset=>
 ({id,label:id,originTeam:team,type,salary,metadata});
const s=(assets:{asset:TradeAsset;destinationTeam:string}[],aa=140000000,bb=140000000,
 extra:Partial<TradeScenario>={}):TradeScenario=>({id:'unit',name:'unit',operatingSeason:'2026-27',
 teams:['AAA','BBB'],capContexts:{AAA:nba2026Cap('AAA',aa),BBB:nba2026Cap('BBB',bb)},
 assignments:assets,asOfDateIso:'2026-11-20T00:00:00Z',...extra});
const codes=(x:TradeScenario)=>validateTrade(x).findings.map(f=>f.code);
describe('independent original Dart CBA contract port',()=>{
 it('generates distinct, named reports for all original Dart fixtures',()=>{
  const cases=originalCbaFixtureCandidate();
  expect(cases.kind).toBe('ARCSIDE_INDEPENDENT_REACT_CBA_CANDIDATE_V1');
  expect(cases.implementationSource).toMatch(/tradeEngine.ts$/);
  expect(Object.keys(cases.cases)).toEqual(Object.keys(originalCbaFixtureScenarios()));
  expect(cases.cases.equal_salaries).toBeDefined();
 });
 it('blocks unknown teams and duplicate asset use',()=>{
  const item=a('a','AAA',1000000);
  expect(codes(s([{asset:item,destinationTeam:'CCC'},{asset:item,destinationTeam:'AAA'}])))
   .toEqual(expect.arrayContaining(['TEAM_SCOPE','DUPLICATE_ASSET','SAME_TEAM']));
 });
 it('applies separate BYC outgoing, poison pill incoming, and team salary charges',()=>{
  const scenario=originalCbaFixtureScenarios().byc_poison_pill;
  const report=validateTrade(scenario);
  expect(report.teamSummaries.AAA.outgoingSalary).toBe(10000000);
  expect(report.teamSummaries.BBB.incomingSalary).toBe(25000000);
  expect(report.teamSummaries.AAA.postTradeSalary).toBe(100000000);
  expect(report.teamSummaries.BBB.postTradeSalary).toBe(120000000);
  expect(codes(scenario)).toEqual(expect.arrayContaining(['BYC_APPLIED','POISON_PILL_APPLIED']));
 });
 it('requires explicit matching values for marked special contracts',()=>{
  expect(codes(originalCbaFixtureScenarios().missing_matching_values))
   .toEqual(expect.arrayContaining(['BYC_VALUE_REQUIRED','POISON_PILL_VALUE_REQUIRED']));
 });
 it('applies dated trade restrictions and updates as of date',()=>{
  const scenario=originalCbaFixtureScenarios().dated_restriction;
  expect(codes(scenario)).toContain('DATED_TRADE_RESTRICTION');
  expect(codes({...scenario,asOfDateIso:'2027-01-01T00:00:00Z'})).not.toContain('DATED_TRADE_RESTRICTION');
 });
 it('enforces first-apron sign-and-trade hard-cap consequence',()=>{
  expect(codes(originalCbaFixtureScenarios().sign_trade_first_apron))
   .toContain('SIGN_AND_TRADE_FIRST_APRON');
 });
 it('enforces second apron cash and player aggregation',()=>{
  const scenario=s([
   {asset:a('cash','AAA',500000,{},'cash'),destinationTeam:'BBB'},
   {asset:a('p1','AAA',8000000),destinationTeam:'BBB'},
   {asset:a('p2','AAA',7000000),destinationTeam:'BBB'},
   {asset:a('p3','BBB',14000000),destinationTeam:'AAA'}],240000000,180000000);
  expect(codes(scenario)).toEqual(expect.arrayContaining(['SECOND_APRON_CASH','SECOND_APRON_AGGREGATION']));
 });
 it('warns about adjacent first-round picks without explicit Stepien-safe data',()=>{
  const scenario=s([
   {asset:a('2028','AAA',0,{round:1,draft_year:2028},'draftPick'),destinationTeam:'BBB'},
   {asset:a('2029','AAA',0,{round:1,draft_year:2029},'draftPick'),destinationTeam:'BBB'}]);
  expect(codes(scenario)).toContain('STEPIEN_REVIEW');
 });
 it('serializes Dart non-finite salary limits faithfully',()=>{
  const result=jsonTradeReport(validateTrade(s([],140000000,140000000,
   {capContexts:{AAA:nba2026Cap('AAA',140000000)}})));
  expect(result.teamSummaries.BBB.maximumIncomingSalary).toBe('INFINITY');
 });
});