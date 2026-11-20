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
export function assess({parity,real,guided,manifestBytes}){
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
 const realChecks=!!real&&sameSource&&Array.isArray(real.seasons)&&
  real.seasons.length>=3&&real.browsers.every(b=>
  (b.errors??[]).length===0&&(b.consoleErrors??[]).length===0&&
  (b.sourceShards?.length??0)>=real.seasons.length*4&&
  b.journeys?.filter(j=>j.kind==='React verified real NBA Stats route'&&
    (j.failures??[]).length===0&&j.checks?.length>=7).length>=real.seasons.length*2&&
  b.references?.some(r=>r.app==='Flutter'));
 g.push(gate('real_source_react_workflow_and_flutter_bootstrap',!real?null:realChecks,
  realChecks?['Automated React journeys and Flutter startup probe recorded with no browser exceptions']:
  ['Run the real-source browser journeys on both local app servers; Flutter interactions are NOT automated'],
  {browsers:real?.browsers?.map(b=>({name:b.browser,version:b.version,
   journeys:b.journeys?.length??0,errors:b.errors?.length??0,
   consoleErrors:b.consoleErrors?.length??0,verifiedShards:b.sourceShards?.length??0}))??[]}));
 const timed=guided?grouped(guided):[];
 const provenance=guided&&corpusHash&&guided.manifestSha256===corpusHash&&
  guided.method?.includes('same machine')&&guided.raw?.length>=90;
 const p95ok=!!provenance&&timed.every(t=>t.valid);
 g.push(gate('matched_flutter_react_operator_tasks_p95',!guided?null:p95ok,
  p95ok?['5 cold and 10 warm verified trials per app/task; p95 regressions <= 10%']:
  ['Need genuinely verified matched task trials for both apps: >=5 cold and >=10 warm each, no failures, React p95 <=110% of Flutter'],
  {sameManifest:!!provenance,measurements:timed}));
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
  pilot:historical&&sameSource&&realChecks&&p95ok?'MATCHED_PILOT_GATES_PASSED_WITH_FULL_SCOPE_PENDING':
   'INCOMPLETE_OR_BLOCKED',
  blockers,gates:g,
  caveat:'No direct React-vs-Flutter speedup is inferred without manual same-hardware trials; browser-route bootstrap is not an equivalent table-interaction measurement. Full migration always requires owner signoff and unimplemented full-feature gates.'};
}
function markdown(result){
 return ['# Phase 3 — decision evidence','',
  '**Recommendation:** retain Flutter reference; React experiment remains isolated.',
  '**Migration approved:** NO.','**Pilot status:** '+result.pilot,'',
  '| Gate | State | Notes |','| --- | --- | --- |',
  ...result.gates.map(x=>'| '+x.name+' | '+x.status+' | '+x.reasons.join('; ').replaceAll('|','/')+' |'),
  '','Remaining blockers: '+result.blockers.join(', '),'',
  'No improvement percentage may be asserted before operator-verified matched hardware data is recorded.',
  'This is an engineering decision report, not a signed framework migration authorization.',''].join('\n');
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const parity=await maybeJson(path.join(home,'evidence/parity/parity-comparison.json'));
 const real=await maybeJson(path.join(home,'evidence/real/real-source-journeys.json'));
 const guided=await maybeJson(path.join(home,'evidence/guided/guided-matched-task-timings.json'));
 let manifestBytes=null;try{manifestBytes=await readFile(path.join(repo,'web/data/nba_static/manifest.json'))}catch(e){
  if(e.code!=='ENOENT')throw e;
 }
 const result=assess({parity,real,guided,manifestBytes});
 const dest=path.join(home,'evidence/decision');
 await mkdir(dest,{recursive:true});
 await writeFile(path.join(dest,'phase3-decision.json'),JSON.stringify(result,null,2)+'\n');
 await writeFile(path.join(dest,'phase3-decision.md'),markdown(result));
 console.log(JSON.stringify({decision:'NOT AUTHORIZED',pilot:result.pilot,blockers:result.blockers,
  output:path.join(dest,'phase3-decision.md')},null,2));
 if(process.env.ARCSIDE_REQUIRE_ALL_PILOT_GATES==='1'&&result.pilot!=='MATCHED_PILOT_GATES_PASSED_WITH_FULL_SCOPE_PENDING')
  process.exitCode=1;
}
