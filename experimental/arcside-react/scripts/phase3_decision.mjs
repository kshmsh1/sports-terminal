// Phase 3 decision evidence is computed, never guessed.
// Reads only local evidence. Missing evidence is an explicit NOT_RUN, not a pass.
// Does NOT approve a framework migration, even when a narrow pilot passes.
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {createHash} from 'node:crypto';

const here=path.dirname(fileURLToPath(import.meta.url));
const home=path.resolve(here,'..');
const repo=path.resolve(here,'../../..');
const sha256=b=>createHash('sha256').update(b).digest('hex');
async function maybeJson(p){try{return JSON.parse(await readFile(p,'utf8'));}catch(e){
 if(e.code==='ENOENT')return null;
 throw Error('Invalid evidence JSON in '+p+': '+e.message);
}}
const gate=(name,passed,reasons,detail={})=>({
 name,status:passed===null?'NOT_RUN':passed?'PASS':'FAIL',reasons,detail
});
const distinctKeys=s=>new Set(s);
function grouped(guided){
 const tasks=['season','basis','chart'],apps=['React','Flutter'];
 const samples=guided?.raw??[];
 const rows=[];
 for(const task of tasks){
  const pair={task,valid:true};
  for(const app of apps){
   const a=samples.filter(x=>x.task===task&&x.app===app);
   const cold=a.filter(x=>x.cold);
   const warm=a.filter(x=>!x.cold);
   const measured=warm.filter(x=>x.passed===true&&x.operatorVerified===true&&
    Number.isFinite(x.ms)&&x.ms>0).map(x=>x.ms).sort((a,b)=>a-b);
   const p95=measured.length?measured[Math.ceil(measured.length*.95)-1]:null;
   const median=measured.length?measured[Math.ceil(measured.length*.5)-1]:null;
   const failures=a.filter(x=>x.passed!==true||x.operatorVerified!==true).length;
   pair[app]={cold:cold.length,warm:warm.length,failures,p95Ms:p95,medianMs:median,
    rawSamples:a.length};
   if(cold.length<5||warm.length<10||failures||measured.length!==warm.length)pair.valid=false;
  }
  pair.p95ReactOverFlutter=pair.Flutter.p95Ms&&pair.React.p95Ms?
   pair.React.p95Ms/pair.Flutter.p95Ms:null;
  if(pair.p95ReactOverFlutter===null||pair.p95ReactOverFlutter>1.10)pair.valid=false;
  rows.push(pair);
 }
 return rows;
}
export function assess({parity,real,guided,manifestBytes,featureBlocker=null,
 advancedSource=null,advancedGuided=null,visualizationGuided=null}){
 const g=[];
 const corpusHash=manifestBytes?sha256(manifestBytes):null;
 const realCases=parity?.byCase??{};
 const caseKeys=Object.keys(realCases);
 const perCaseSum=Object.values(realCases).reduce((s,e)=>s+(e.comparisons??0),0);
 const seenBases=distinctKeys(caseKeys.map(k=>k.split('/')[2]));
 const nonempty=caseKeys.filter(k=>realCases[k].comparisons>0);
 const historical=!!parity&&parity.source==='ACTUAL_LOCAL_V5_CORPUS'&&
  parity.passed===true&&parity.mismatchCount===0&&parity.comparisons>=100000&&
  caseKeys.length>=18&&nonempty.length>=12&&seenBases.size===6&&
  perCaseSum===parity.comparisons;
 g.push(gate('real_cross_engine_statistics',!parity?null:historical,
  historical?['Original Dart and React computed identical mapped fields for sampled actual source shards']:
  ['Need real-corpus Dart/React export and valid per-case nonempty statistics; empty cases are not evidence'],
  {source:parity?.source??null,comparisons:parity?.comparisons??0,
   mismatches:parity?.mismatchCount??null,nonemptyCases:nonempty.length,allCases:caseKeys.length}));
 const sameSource=!!real&&!!corpusHash&&real.source==='ACTUAL_LOCAL_V5_CORPUS'&&
  real.manifestSha256===corpusHash&&Array.isArray(real.browsers)&&
  real.browsers.length>=1&&real.browsers.every(b=>
   b.references?.length===2&&b.references.every(r=>r.manifestSha256===corpusHash));
 g.push(gate('matched_original_data_source',!real||!manifestBytes?null:sameSource,
  sameSource?['Both browser variants reference the byte-identical original local manifest']:
  ['Need both local servers and the original v5 manifest with matching SHA-256'],
  {manifestSha256:corpusHash,reportSha256:real?.manifestSha256??null}));
 // Identify complete source-matched React journeys AND prove that Flutter's
 // visible renderer mounted. A root element is only bootstrap evidence, never
 // a claim that Flutter rows or charts were interacted with automatically.
 const browserDiagnostics=real?.browsers?.map(b=>{
  const requested=(real?.seasons??[]).flatMap(season=>['regular','playoffs'].map(segment=>season+'/'+segment));
  const qualified=(b.journeys??[]).filter(j=>j.kind==='React verified real NBA Stats route'&&
   (j.failures??[]).length===0&&(j.checks??[]).length>=7);
  const present=new Set(qualified.map(j=>j.season+'/'+j.segment));
  const shards=(b.sourceShards??[]),shardIds=new Set(shards.map(x=>x.app+'/'+x.shard));
  const completeShards=requested.every(key=>['React','Flutter'].every(app=>
   shardIds.has(app+'/seasons/'+key.replace('/','/')+'.json')));
  return {name:b.browser,version:b.version,
   journeys:b.journeys?.length??0,verifiedQualifiedStatsJourneys:qualified.length,
   missingRoutes:requested.filter(k=>!present.has(k)),completeShards,
   flutterBootstrap:b.flutterBootstrap?.status??'NOT_RUN',
   flutterRoot:b.flutterBootstrap?.root??null,
   errors:b.errors?.length??0,errorExamples:(b.errors??[]).slice(0,3),
   consoleErrors:b.consoleErrors?.length??0,consoleErrorExamples:(b.consoleErrors??[]).slice(0,3),
   verifiedShards:shards.length};
 })??[];
 const realChecks=!!real&&sameSource&&Array.isArray(real.seasons)&&real.seasons.length>=3&&
  browserDiagnostics.length>0&&browserDiagnostics.every(b=>
   b.errors===0&&b.consoleErrors===0&&b.flutterBootstrap==='PASS'&&
   b.completeShards&&b.missingRoutes.length===0&&b.verifiedShards>=real.seasons.length*4);
 g.push(gate('real_source_react_workflow_and_flutter_bootstrap',!real?null:realChecks,
  realChecks?['Automated React journeys and Flutter startup probe recorded with no browser exceptions']:
  ['Run the real-source browser journeys on both local app servers; Flutter interactions are NOT automated'],
  {browsers:browserDiagnostics}));
 // Old observed UI failures are immutable history. A NEW protocol with genuine
 // Dart source parity, operator-confirmed live Flutter controls, and matched
 // clean trials can supersede them; merely porting columns cannot.
 const advSourceValid=!!advancedSource&&!!corpusHash&&
  advancedSource.kind==='ARCSIDE_ADVANCED_STATS_REAL_DART_REACT_ACCEPTANCE_V1'&&
  advancedSource.source==='ACTUAL_LOCAL_V5_CORPUS'&&
  advancedSource.manifestSha256===corpusHash&&advancedSource.status==='PASS'&&
  advancedSource.mismatches===0&&advancedSource.comparisons>1000&&
  advancedSource.nonEmptyCases>=12&&
  (advancedSource.nonEmptySeasons?.length??0)>=2&&
  Array.isArray(advancedSource.cases)&&advancedSource.cases.length>=36;
 g.push(gate('advanced_stats_source_semantic_parity',!advancedSource?null:advSourceValid,
  advSourceValid?['Dart resolver and React catalog/metric/filter/sort projections agree across sampled real NBA source shards']:
  ['Requires independently re-exported Dart Advanced Stats reference, exact manifest, 36 cases and zero mismatches'],
  {cases:advancedSource?.cases?.length??0,comparisons:advancedSource?.comparisons??0,
   mismatches:advancedSource?.mismatches??null,nonEmptyCases:advancedSource?.nonEmptyCases??0}));
 const observed=advancedGuided?.raw??[];
 const uniqueTrials=new Set(observed.map(x=>x.app+'/'+x.trial));
 const advGuideValid=!!advancedGuided&&!!corpusHash&&
  advancedGuided.kind==='ARCSIDE_ADVANCED_MATCHED_TASKS_V2'&&
  advancedGuided.protocol==='ADVANCED_STATS_V2_AFTER_CATALOG_REPAIR'&&
  advancedGuided.manifestSha256===corpusHash&&
  advancedGuided.source==='ACTUAL_LOCAL_V5_CORPUS'&&
  advancedGuided.operatorConfirmed===true&&
  observed.length===30&&uniqueTrials.size===30&&
  ['Flutter','React'].every(app=>{
   const a=observed.filter(x=>x.app===app);
   return a.length===15&&a.filter(x=>x.cold).length===5&&
    a.filter(x=>!x.cold).length===10&&
    a.every(x=>x.passed===true&&x.operatorVerified===true&&
     Number.isFinite(x.ms)&&x.ms>0&&Number.isInteger(x.trial)&&
     x.trial>=1&&x.trial<=15&&x.cold===(x.trial<=5));
  })&&advancedGuided.qualified===true;
 const advFeaturePass=advSourceValid&&advGuideValid;
 g.push(gate('advanced_stats_ui_feature_parity',advFeaturePass?true:
  featureBlocker?.status==='BLOCKED'||!!advancedSource||!!advancedGuided?false:null,
  advFeaturePass?['New verified Flutter/React Advanced Stats source and 30 operator-matched UI observations supersede earlier narrow-React mismatch']:
   ['Earlier observed Advanced Stats feature gap remains historical; current matched live Flutter/React controls are not yet independently attested and completed'],
  {oldBlockerPreserved:featureBlocker?.status==='BLOCKED',
   newSourceValid:advSourceValid,operatorConfirmed:advancedGuided?.operatorConfirmed??false,
   newTrials:observed.length}));
 const advRatio=advancedGuided?.p95ReactOverFlutter;
 const advTimingOk=advGuideValid&&Number.isFinite(advRatio)&&advRatio>0&&advRatio<=1.1&&
  advancedGuided.within10Pct===true;
 g.push(gate('advanced_stats_matched_task_p95',!advancedGuided?null:advTimingOk,
  advTimingOk?['5 cold + 10 warm verified post-repair Advanced Stats trials per variant; React p95 within 110% of Flutter']:
   ['Run the NEW 30-trial protocol with a live UI preflight; do not reuse the 2026-11 historical failed rate/sort attempts'],
  {ratio:advRatio??null,samples:observed.length,operatorConfirmed:advancedGuided?.operatorConfirmed??false}));
 // Legacy 90-trial guide contains the original pre-repair Advanced Stats
 // failure. Preserve it as historical evidence, but combine ONLY its verified
 // season-switching trials with NEW independent Advanced + Visualization protocols.
 const seasonEvidence=guided?.raw??[];
 const seasonSamples=seasonEvidence.filter(r=>r.task==='season');
 const seasonValid=!!guided&&guided.manifestSha256===corpusHash&&
  guided.method?.includes('same machine')&&
  seasonSamples.length===30&&new Set(seasonSamples.map(r=>r.app+'/'+r.trial)).size===30&&
  ['Flutter','React'].every(app=>{
   const entries=seasonSamples.filter(r=>r.app===app);
   return entries.length===15&&entries.filter(r=>r.cold).length===5&&
    entries.filter(r=>!r.cold).length===10&&
    entries.every(r=>r.passed===true&&r.operatorVerified===true&&
     Number.isFinite(r.ms)&&r.ms>0&&Number.isInteger(r.trial)&&
     r.trial>=1&&r.trial<=15&&r.cold===(r.trial<=5));
  });
 const seasonWarm=app=>seasonSamples.filter(r=>r.app===app&&!r.cold&&r.passed)
  .map(r=>r.ms).sort((a,b)=>a-b);
 const p95=values=>values.length===10?values[Math.ceil(values.length*.95)-1]:null;
 const seasonFlutterP95=p95(seasonWarm('Flutter')),seasonReactP95=p95(seasonWarm('React'));
 const seasonRatio=seasonFlutterP95&&seasonReactP95?seasonReactP95/seasonFlutterP95:null;
 const vizObserved=visualizationGuided?.raw??[];
 const vizValid=!!visualizationGuided&&visualizationGuided.kind==='ARCSIDE_VISUALIZATION_MATCHED_TASKS_V1'&&
  visualizationGuided.protocol==='VISUALIZATION_CHART_V1_MATCHED'&&
  visualizationGuided.source==='ACTUAL_LOCAL_V5_CORPUS'&&
  visualizationGuided.manifestSha256===corpusHash&&
  visualizationGuided.operatorConfirmed===true&&visualizationGuided.qualified===true&&
  vizObserved.length===30&&new Set(vizObserved.map(r=>r.app+'/'+r.trial)).size===30&&
  ['Flutter','React'].every(app=>{
   const rows=vizObserved.filter(r=>r.app===app);
   return rows.length===15&&rows.filter(r=>r.cold).length===5&&
    rows.filter(r=>!r.cold).length===10&&rows.every(r=>
     Number.isInteger(r.trial)&&r.trial>=1&&r.trial<=15&&
     r.cold===(r.trial<=5)&&r.operatorVerified===true&&r.passed===true&&
     Number.isFinite(r.ms)&&r.ms>0);
  });
 const vizRatio=visualizationGuided?.p95ReactOverFlutter??null;
 const seasonOk=seasonValid&&seasonRatio!==null&&seasonRatio>0&&seasonRatio<=1.10;
 const vizOk=vizValid&&Number.isFinite(vizRatio)&&vizRatio>0&&vizRatio<=1.10&&
  visualizationGuided.within10Pct===true;
 const p95ok=seasonOk&&advFeaturePass&&advTimingOk&&vizOk;
 g.push(gate('matched_flutter_react_operator_tasks_p95',!guided&&!visualizationGuided?null:p95ok,
  p95ok?['Separate verified season, corrected Advanced Stats and Visualization protocols: each 5 cold + 10 warm per app, zero failures, React p95 <=110% of Flutter']:
  ['Requires original valid season trials, corrected Advanced Stats trials and NEW live-equivalent Visualization trials; never reuse failed pre-repair basis/chart timings'],
  {season:{valid:seasonValid,p95ReactOverFlutter:seasonRatio,flutterWarmP95Ms:seasonFlutterP95,reactWarmP95Ms:seasonReactP95,
    preservedHistoricalSamples:seasonSamples.length},
   advanced:{valid:advGuideValid&&advFeaturePass,p95ReactOverFlutter:advRatio??null,samples:observed.length},
   visualization:{valid:vizValid,p95ReactOverFlutter:vizRatio,samples:vizObserved.length},
   legacyBasisAndChartExcluded:true}));
 // Presence of synthetic or Playwright evidence cannot satisfy these human/runtime gates.
 for(const name of ['functional_full_scope_feature_parity','full_cba_trade_rules_and_player_profiles',
  'real_safari_voiceover_nvda_accessibility','labs_import_export_and_native_service_security',
  'rendering_frames_memory_and_gpu_on_matched_hardware',
  'owner_visual_ux_and_migration_signoff']){
  g.push(gate(name,null,['This mandatory acceptance gate needs separately reviewed evidence and is not inferred from scripts or synthetic tests']));
 }
 const blockers=g.filter(x=>x.status!=='PASS').map(x=>x.name);
 return {kind:'ARCSIDE_PHASE3_DECISION_EVIDENCE_V1',createdAt:new Date().toISOString(),
  recommendation:'RETAIN_FLUTTER_REFERENCE_CONTINUE_CONTROLLED_REACT_PILOT',
  fullMigrationApproved:false,
  pilot:historical&&sameSource&&realChecks&&advFeaturePass&&advTimingOk&&p95ok?'MATCHED_PILOT_GATES_PASSED_WITH_FULL_SCOPE_PENDING':
   'INCOMPLETE_OR_BLOCKED',
  blockers,gates:g,
  caveat:'The three matched task groups are human task-completion times, NOT GPU or frame benchmarks. Flutter bootstrap is not verified table interaction. Full migration requires independent full-feature, access, security, performance and owner acceptance.'};
}
function markdown(result){
 return ['# Phase 3 — decision evidence','',
  '**Recommendation:** retain Flutter reference; React experiment remains isolated.',
  '**Migration approved:** NO.','**Pilot status:** '+result.pilot,'',
  '| Gate | State | Notes |','| --- | --- | --- |',
  ...result.gates.map(x=>'| '+x.name+' | '+x.status+' | '+x.reasons.join('; ').replaceAll('|','/')+' |'),
  '','Remaining blockers: '+result.blockers.join(', '),'',
  'Performance ratios, when reported, reflect matched human task completion only. Missing chart trials are not a pass.',
  'This is an engineering decision report, not a signed framework migration authorization.',''].join('\n');
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const parity=await maybeJson(path.join(home,'evidence/parity/parity-comparison.json'));
 const real=await maybeJson(path.join(home,'evidence/real/real-source-journeys.json'));
 const guided=await maybeJson(path.join(home,'evidence/guided/guided-matched-task-timings.json'));
 const featureBlocker=await maybeJson(path.join(home,'evidence/guided/advanced-stats-parity-blocker.json'));
 const advancedSource=await maybeJson(path.join(home,'evidence/advanced/advanced-source-parity.json'));
 const advancedGuided=await maybeJson(path.join(home,'evidence/advanced/advanced-guided-timings-v2.json'));
 const visualizationGuided=await maybeJson(path.join(home,'evidence/visualization/visualization-guided-timings-v1.json'));
 let manifestBytes=null;try{manifestBytes=await readFile(path.join(repo,'web/data/nba_static/manifest.json'))}catch(e){
  if(e.code!=='ENOENT')throw e;
 }
 const result=assess({parity,real,guided,manifestBytes,featureBlocker,advancedSource,advancedGuided,visualizationGuided});
 const dest=path.join(home,'evidence/decision');
 await mkdir(dest,{recursive:true});
 await writeFile(path.join(dest,'phase3-decision.json'),JSON.stringify(result,null,2)+'\n');
 await writeFile(path.join(dest,'phase3-decision.md'),markdown(result));
 console.log(JSON.stringify({decision:'NOT AUTHORIZED',pilot:result.pilot,blockers:result.blockers,
  output:path.join(dest,'phase3-decision.md')},null,2));
 if(process.env.ARCSIDE_REQUIRE_ALL_PILOT_GATES==='1'&&result.pilot!=='MATCHED_PILOT_GATES_PASSED_WITH_FULL_SCOPE_PENDING')
  process.exitCode=1;
}
