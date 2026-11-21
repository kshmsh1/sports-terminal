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
  errors:[],consoleErrors:[],flutterBootstrap:{status:'PASS',root:{tagName:'FLUTTER-VIEW',width:1440,height:900,visible:true},screenshotSha256:hash},
  sourceShards:['1946-47','1986-87','2025-26'].flatMap(season=>
   ['regular','playoffs'].flatMap(segment=>['React','Flutter'].map(app=>({
    app,shard:'seasons/'+season+'/'+segment+'.json',sha256:hash})))),
  journeys:Array.from({length:6},(_,i)=>({kind:'React verified real NBA Stats route',
   season:['1946-47','1986-87','2025-26'][Math.floor(i/2)],
   segment:i%2?'playoffs':'regular',
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
const visualizationSource={kind:'ARCSIDE_VISUALIZATION_REAL_DART_REACT_ACCEPTANCE_V1',
 source:'ACTUAL_LOCAL_V5_CORPUS',manifestSha256:hash,status:'PASS',
 mismatches:0,comparisons:20000,nonemptyCases:24,
 cases:Array.from({length:72},(_,i)=>({case:i}))};
const visualizationGuided={kind:'ARCSIDE_VISUALIZATION_MATCHED_TASKS_V2',
 protocol:'VISUALIZATION_CHART_V2_MATCHED_2_COLD_10_WARM',source:'ACTUAL_LOCAL_V5_CORPUS',
 manifestSha256:hash,operatorConfirmed:true,qualified:true,
 p95ReactOverFlutter:1,within10Pct:true,
 raw:['Flutter','React'].flatMap(app=>Array.from({length:12},(_,i)=>({
  app,trial:i+1,cold:i<2,ms:100,passed:true,operatorVerified:true})))
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
 const a=assess({parity,real,guided:makeGuide(),manifestBytes,advancedSource,advancedGuided,visualizationSource,visualizationGuided});
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

test('Flutter root probe is REQUIRED; screenshots alone do not certify visible startup',()=>{
 const broken={...real,browsers:real.browsers.map(b=>({...b,flutterBootstrap:null}))};
 const a=assess({parity,real:broken,guided:makeGuide(),manifestBytes,
  advancedSource,advancedGuided,visualizationSource,visualizationGuided});
 const g=a.gates.find(x=>x.name==='real_source_react_workflow_and_flutter_bootstrap');
 assert.equal(g.status,'FAIL');
 assert.equal(g.detail.browsers[0].flutterBootstrap,'NOT_RUN');
});
test('authentic source browser journeys require every exact selected season and segment',()=>{
 const broken={...real,browsers:real.browsers.map(b=>({...b,
  journeys:b.journeys.filter(x=>!(x.season==='1946-47'&&x.segment==='playoffs'))}))};
 const a=assess({parity,real:broken,guided:makeGuide(),manifestBytes,
  advancedSource,advancedGuided,visualizationSource,visualizationGuided});
 assert.equal(a.gates.find(x=>x.name==='real_source_react_workflow_and_flutter_bootstrap').status,'FAIL');
});
test('corrected performance gate excludes original failed basis and chart trials',()=>{
 const old=makeGuide();
 // Only pre-repair basis/chart trials are invalidated, not season observations.
 const obsolete=old.raw.find(r=>r.task==='basis'&&r.app==='React');
 obsolete.passed=false;obsolete.operatorVerified=false;
 const a=assess({parity,real,guided:old,manifestBytes,
  advancedSource,advancedGuided,visualizationSource,visualizationGuided});
 const g=a.gates.find(x=>x.name==='matched_flutter_react_operator_tasks_p95');
 assert.equal(g.status,'PASS');
 assert.equal(g.detail.legacyBasisAndChartExcluded,true);
 assert.equal(g.detail.season.preservedHistoricalSamples,30);
});
test('no Visualization protocol means combined performance gate remains blocked',()=>{
 const a=assess({parity,real,guided:makeGuide(),manifestBytes,advancedSource,advancedGuided});
 assert.equal(a.gates.find(x=>x.name==='matched_flutter_react_operator_tasks_p95').status,'FAIL');
});
test('unattested or duplicate visualization trials cannot certify matched performance',()=>{
 const tampered={...visualizationGuided,
  raw:[...visualizationGuided.raw.slice(1),visualizationGuided.raw[1]]};
 const a=assess({parity,real,guided:makeGuide(),manifestBytes,
  advancedSource,advancedGuided,visualizationSource,visualizationGuided:tampered});
 assert.equal(a.gates.find(x=>x.name==='matched_flutter_react_operator_tasks_p95').status,'FAIL');
 const b=assess({parity,real,guided:makeGuide(),manifestBytes,
  advancedSource,advancedGuided,visualizationSource,visualizationGuided:{...visualizationGuided,operatorConfirmed:false}});
 assert.equal(b.gates.find(x=>x.name==='matched_flutter_react_operator_tasks_p95').status,'FAIL');
});
test('react chart p95 over 10 percent slower fails composite gate',()=>{
 const slow={...visualizationGuided,p95ReactOverFlutter:1.11,within10Pct:false};
 const a=assess({parity,real,guided:makeGuide(),manifestBytes,
  advancedSource,advancedGuided,visualizationSource,visualizationGuided:slow});
 assert.equal(a.gates.find(x=>x.name==='matched_flutter_react_operator_tasks_p95').status,'FAIL');
});

test('visualization original-Dart source parity gate cannot pass with missing or mismatched data',()=>{
 const missing=assess({parity,real,guided:makeGuide(),manifestBytes,
  advancedSource,advancedGuided,visualizationGuided});
 assert.equal(missing.gates.find(g=>g.name==='visualization_source_semantic_parity').status,'NOT_RUN');
 assert.equal(missing.gates.find(g=>g.name==='matched_flutter_react_operator_tasks_p95').status,'FAIL');
 const mismatched=assess({parity,real,guided:makeGuide(),manifestBytes,
  advancedSource,advancedGuided,visualizationSource:{...visualizationSource,mismatches:1},visualizationGuided});
 assert.equal(mismatched.gates.find(g=>g.name==='visualization_source_semantic_parity').status,'FAIL');
 assert.equal(mismatched.gates.find(g=>g.name==='matched_flutter_react_operator_tasks_p95').status,'FAIL');
});

test('full-scope audit exposes absent modules and blocks a full migration',()=>{
 const readiness={kind:'ARCSIDE_PHASE3_FULL_SCOPE_AUDIT_V1',status:'GAPS_CONFIRMED',
  fullScopeFeatureParity:false,fullTradeAndProfileParity:false,
  modules:[{module:'Trade Machine',status:'CANDIDATE_ROUTE_MISSING'}],
  directFailures:[{check:'Full CBA trade rules'}]};
 const result=assess({readiness});
 assert.equal(result.gates.find(x=>x.name==='functional_full_scope_feature_parity').status,'FAIL');
 assert.equal(result.gates.find(x=>x.name==='full_cba_trade_rules_and_player_profiles').status,'FAIL');
 assert.equal(result.fullMigrationApproved,false);
});

test('observational browser, Labs and a11y smoke never certifies GPU, security or assistive technology',()=>{
 const objective={kind:'ARCSIDE_OBJECTIVE_BROWSER_PERFORMANCE_V1',manifestSha256:hash,
  status:'OBSERVATIONAL_PASS'};
 const accessibility={kind:'ARCSIDE_PHASE3_ACCESSIBILITY_SMOKE_V1',manifestSha256:hash,
  status:'AUTOMATED_SMOKE_PASS'};
 const labs={kind:'ARCSIDE_PHASE3_LABS_LOCAL_INTEGRITY_V1',manifestSha256:hash,
  status:'BROWSER_ROUNDTRIPS_PASS'};
 const result=assess({manifestBytes,objective,accessibility,labs});
 for(const key of ['rendering_frames_memory_and_gpu_on_matched_hardware',
  'real_safari_voiceover_nvda_accessibility','labs_import_export_and_native_service_security'])
  assert.equal(result.gates.find(x=>x.name===key).status,'NOT_RUN');
 assert.equal(result.fullMigrationApproved,false);
});

test('actual profile route smoke and original Dart CBA exports are evidence, not full profile or CBA parity',()=>{
 const readiness={kind:'ARCSIDE_PHASE3_FULL_SCOPE_AUDIT_V1',fullScopeFeatureParity:false,
  fullTradeAndProfileParity:false,modules:[],directFailures:[]};
 const profiles={kind:'ARCSIDE_REAL_PLAYER_PROFILE_CORPUS_PROBE_V1',
  manifestSha256:hash,status:'SOURCE_DOSSIER_SMOKE_PASS'};
 const tradeReference={kind:'ARCSIDE_ORIGINAL_DART_CBA_GOLDENS_V1',
  candidateEquivalentImplemented:false,cases:{a:{},b:{},c:{},d:{},e:{}}};
 const result=assess({manifestBytes,readiness,profiles,tradeReference});
 const scope=result.gates.find(x=>x.name==='functional_full_scope_feature_parity');
 const cba=result.gates.find(x=>x.name==='full_cba_trade_rules_and_player_profiles');
 assert.equal(scope.status,'FAIL');
 assert.equal(scope.detail.playerDossierSourceProbe,'SOURCE_DOSSIER_SMOKE_PASS');
 assert.equal(cba.detail.originalDartRuleCases,5);
 assert.equal(cba.detail.independentReactCbaEngineVerified,false);
 assert.equal(cba.status,'FAIL');
 assert.equal(result.fullMigrationApproved,false);
});

test('limited independent CBA golden parity records matched cases but never approves migration',()=>{
 const base={isValid:true,errorCount:0,warningCount:0,findings:[],teamSummaries:{
  AAA:{team:'AAA',incomingSalary:8000000,outgoingSalary:8000000}
 }};
 const reference={kind:'ARCSIDE_ORIGINAL_DART_CBA_GOLDENS_V1',
  candidateEquivalentImplemented:false,cases:{equal_salaries:base}};
 const candidate={kind:'ARCSIDE_INDEPENDENT_REACT_CBA_CANDIDATE_V1',
  candidateEquivalentImplemented:true,
  implementationSource:'experimental/arcside-react/src/tradeEngine.ts',
  cases:{equal_salaries:{...base}}};
 const readiness={kind:'ARCSIDE_PHASE3_FULL_SCOPE_AUDIT_V1',status:'GAPS_CONFIRMED',
  fullScopeFeatureParity:false,fullTradeAndProfileParity:false,modules:[],directFailures:[]};
 const verified=assess({tradeReference:reference,tradeCandidate:candidate,readiness});
 const gate=verified.gates.find(x=>x.name==='full_cba_trade_rules_and_player_profiles');
 assert.equal(gate.detail.limitedCbaGoldenParity,true);
 assert.equal(gate.detail.matchedIndependentCbaCases,1);
 assert.equal(gate.status,'FAIL');
 assert.equal(verified.fullMigrationApproved,false);
 const mismatched=assess({tradeReference:reference,
  tradeCandidate:{...candidate,cases:{equal_salaries:{...base,errorCount:1}}},readiness});
 assert.equal(mismatched.gates.find(x=>x.name==='full_cba_trade_rules_and_player_profiles').detail.limitedCbaGoldenParity,false);
});

test('five source-backed module route probes stay observational and cannot certify full parity',()=>{
 const readiness={kind:'ARCSIDE_PHASE3_FULL_SCOPE_AUDIT_V1',status:'GAPS_CONFIRMED',
  fullScopeFeatureParity:false,fullTradeAndProfileParity:false,modules:[],directFailures:[]};
 const modules={kind:'ARCSIDE_PHASE3_NEW_MODULES_REAL_CORPUS_PROBE_V1',
  manifestSha256:hash,status:'SOURCE_ROUTE_SMOKE_PASS',
  rows:['/player-compare','/team-compare','/box-scores','/financials','/with-without'].map(path=>({path,status:'SOURCE_ROUTE_SMOKE_PASS'}))};
 const result=assess({manifestBytes,readiness,modules});
 const gate=result.gates.find(g=>g.name==='functional_full_scope_feature_parity');
 assert.equal(gate.status,'FAIL');
 assert.equal(gate.detail.newModuleSourceProbe,'SOURCE_ROUTE_SMOKE_PASS');
 assert.equal(gate.detail.newModuleSourceRoutes,5);
 assert.equal(result.fullMigrationApproved,false);
});
