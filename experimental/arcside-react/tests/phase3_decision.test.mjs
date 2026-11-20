import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {assess} from '../scripts/phase3_decision.mjs';

const manifestBytes=Buffer.from('{"contract":"sports-terminal-static-nba-website-v5"}');
const hash=createHash('sha256').update(manifestBytes).digest('hex');
const bases=['perGame','per36','per48','per75','per100','totals'];
const byCase=Object.fromEntries(['1946-47','1986-87','2025-26'].flatMap(season=>
 ['regular','playoffs'].flatMap(segment=>bases.map(basis=>[
  season+'/'+segment+'/'+basis,
  {comparisons:season==='1946-47'&&segment==='playoffs'?0:5000,mismatches:0,byField:{}}
 ]))));
const compared=Object.values(byCase).reduce((s,x)=>s+x.comparisons,0);
const parity={source:'ACTUAL_LOCAL_V5_CORPUS',passed:true,mismatchCount:0,
 comparisons:compared,byCase};
const real={source:'ACTUAL_LOCAL_V5_CORPUS',manifestSha256:hash,
 seasons:['1946-47','1986-87','2025-26'],
 browsers:[{browser:'chromium',version:'157',references:[
  {app:'React',manifestSha256:hash},{app:'Flutter',manifestSha256:hash}],
  errors:[],consoleErrors:[],
  sourceShards:Array.from({length:12},(_,i)=>({app:i%2?'React':'Flutter',sha256:hash})),
  journeys:Array.from({length:6},(_,i)=>({kind:'React verified real NBA Stats route',
   season:['1946-47','1986-87','2025-26'][Math.floor(i/2)],
   failures:[],checks:Array.from({length:8},(_,j)=>'check-'+j)}))}]};
const advancedSource={kind:'ARCSIDE_ADVANCED_STATS_REAL_DART_REACT_ACCEPTANCE_V1',
 source:'ACTUAL_LOCAL_V5_CORPUS',manifestSha256:hash,status:'PASS',mismatches:0,
 comparisons:100000,nonEmptyCases:30,nonEmptySeasons:['2025-26','1986-87'],
 cases:Array.from({length:36},(_,i)=>({case:i}))};
const advancedGuided={kind:'ARCSIDE_ADVANCED_MATCHED_TASKS_V2',protocol:'ADVANCED_STATS_V2_AFTER_CATALOG_REPAIR',
 source:'ACTUAL_LOCAL_V5_CORPUS',manifestSha256:hash,operatorConfirmed:true,
 qualified:true,p95ReactOverFlutter:1.0,within10Pct:true,
 raw:['Flutter','React'].flatMap(app=>Array.from({length:15},(_,i)=>({
  app,trial:i+1,cold:i<5,ms:100,passed:true,operatorVerified:true})))
};
const makeGuide=(reactWarm=100,failed=false)=>{
 const raw=[];
 for(const task of ['season','basis','chart'])for(const app of ['Flutter','React'])
  for(let i=0;i<15;i++){
   const bad=failed&&task==='season'&&app==='React'&&i===14;
   raw.push({task,app,cold:i<5,ms:app==='React'?reactWarm:100,trial:i+1,
    passed:!bad,operatorVerified:!bad});
  }
 return {manifestSha256:hash,method:'same machine, verified operator tasks',
  raw};
};
test('missing evidence never becomes a pass or a migration authorization',()=>{
 const a=assess({});
 assert.equal(a.fullMigrationApproved,false);
 assert.equal(a.pilot,'INCOMPLETE_OR_BLOCKED');
 assert.equal(a.gates[0].status,'NOT_RUN');
 assert.ok(a.blockers.includes('matched_flutter_react_operator_tasks_p95'));
});
test('old synthetic equality is not accepted as original canonical source proof',()=>{
 const a=assess({parity:{...parity,source:'SYNTHETIC_CONTRACT_ONLY'},real,guided:makeGuide(),manifestBytes});
 assert.equal(a.gates[0].status,'FAIL');
 assert.equal(a.fullMigrationApproved,false);
});
test('complete original narrow pilot can pass without signing off full migration',()=>{
 const a=assess({parity,real,guided:makeGuide(),manifestBytes,advancedSource,advancedGuided});
 assert.equal(a.pilot,'MATCHED_PILOT_GATES_PASSED_WITH_FULL_SCOPE_PENDING');
 assert.equal(a.fullMigrationApproved,false);
 assert.ok(a.blockers.includes('real_safari_voiceover_nvda_accessibility'));
});
test('p95 over 10 percent slower is a meaningful failure',()=>{
 const a=assess({parity,real,guided:makeGuide(112),manifestBytes});
 assert.equal(a.gates.find(g=>g.name==='matched_flutter_react_operator_tasks_p95').status,'FAIL');
});
test('a manually failed task cannot be dropped from the performance denominator',()=>{
 const a=assess({parity,real,guided:makeGuide(100,true),manifestBytes});
 assert.equal(a.gates.find(g=>g.name==='matched_flutter_react_operator_tasks_p95').status,'FAIL');
});
test('zero-observation seasons do not count as evidence; per-case accounting must reconcile',()=>{
 const broken={...parity,byCase:{...byCase,'2025-26/regular/perGame':{comparisons:1,mismatches:0}}};
 const a=assess({parity:broken,real,guided:makeGuide(),manifestBytes});
 assert.equal(a.gates[0].status,'FAIL');
});
test('manifest mismatch between local source and app fails the controlled comparison',()=>{
 const a=assess({parity,real:{...real,manifestSha256:'bad'},guided:makeGuide(),manifestBytes});
 assert.equal(a.gates.find(g=>g.name==='matched_original_data_source').status,'FAIL');
});

test('historical Advanced Stats UI blocker cannot be cleared by React code alone',()=>{
 const old={status:'BLOCKED'};
 const result=assess({parity,real,guided:makeGuide(),manifestBytes,featureBlocker:old});
 assert.equal(result.gates.find(x=>x.name==='advanced_stats_ui_feature_parity').status,'FAIL');
 assert.equal(result.pilot,'INCOMPLETE_OR_BLOCKED');
});
test('new source parity alone does not certify live Flutter interface equivalence',()=>{
 const result=assess({parity,real,guided:makeGuide(),manifestBytes,
  featureBlocker:{status:'BLOCKED'},advancedSource});
 assert.equal(result.gates.find(x=>x.name==='advanced_stats_source_semantic_parity').status,'PASS');
 assert.equal(result.gates.find(x=>x.name==='advanced_stats_ui_feature_parity').status,'FAIL');
 assert.equal(result.gates.find(x=>x.name==='advanced_stats_matched_task_p95').status,'NOT_RUN');
});
test('new fully verified Advanced Stats evidence supersedes old blocker without deleting it',()=>{
 const result=assess({parity,real,guided:makeGuide(),manifestBytes,
  featureBlocker:{status:'BLOCKED'},advancedSource,advancedGuided});
 assert.equal(result.gates.find(x=>x.name==='advanced_stats_ui_feature_parity').status,'PASS');
 assert.equal(result.gates.find(x=>x.name==='advanced_stats_matched_task_p95').status,'PASS');
 assert.equal(result.fullMigrationApproved,false);
});
test('failed or missing real Advanced Stats observations cannot be papered over',()=>{
 const corrupted={...advancedGuided,raw:[...advancedGuided.raw.slice(1),advancedGuided.raw[1]]};
 const result=assess({parity,real,guided:makeGuide(),manifestBytes,advancedSource,advancedGuided:corrupted});
 assert.equal(result.gates.find(x=>x.name==='advanced_stats_ui_feature_parity').status,'FAIL');
 const badSource={...advancedSource,mismatches:1};
 const result2=assess({parity,real,guided:makeGuide(),manifestBytes,advancedSource:badSource,advancedGuided});
 assert.equal(result2.gates.find(x=>x.name==='advanced_stats_source_semantic_parity').status,'FAIL');
});
test('Advanced Stats p95 ratio is an independent decision criterion',()=>{
 const slower={...advancedGuided,p95ReactOverFlutter:1.20,within10Pct:false};
 const result=assess({parity,real,guided:makeGuide(),manifestBytes,
  advancedSource,advancedGuided:slower});
 assert.equal(result.gates.find(x=>x.name==='advanced_stats_ui_feature_parity').status,'PASS');
 assert.equal(result.gates.find(x=>x.name==='advanced_stats_matched_task_p95').status,'FAIL');
});
