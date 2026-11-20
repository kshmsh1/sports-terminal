// Manually controlled, SAME-HARDWARE user-task evaluation of Flutter vs React.
// Does not infer Flutter widget selectors or pretend scripted React tests are matched.
// Each task is started/stopped INSIDE the evaluated browser, via the identical
// minimally intrusive stopwatch control. User marks success or failure.
// Requires both local servers, original authentic v5 JSON manifest, and headed Chromium.
import {chromium} from '@playwright/test';
import {createInterface} from 'node:readline/promises';
import {stdin as input,stdout as output} from 'node:process';
import {performance} from 'node:perf_hooks';
import {readFile,mkdir,writeFile,copyFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {platform,release,arch,cpus,totalmem} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const source=path.resolve(here,'../../../web/data/nba_static');
const dir=path.resolve(here,'../evidence/guided');
const react=(process.env.ARCSIDE_REACT_URL??'http://127.0.0.1:5173').replace(/\/$/,'');
const flutter=(process.env.ARCSIDE_FLUTTER_URL??'http://127.0.0.1:8765').replace(/\/$/,'');
const cold=Number(process.env.ARCSIDE_GUIDED_COLD_RUNS??5);
const warm=Number(process.env.ARCSIDE_GUIDED_WARM_RUNS??10);
if(!Number.isInteger(cold)||!Number.isInteger(warm)||cold<1||warm<1)
 throw Error('Invalid sample counts.');
const data=await readFile(path.join(source,'manifest.json'));
const hash=b=>createHash('sha256').update(b).digest('hex');
const manifest=JSON.parse(data.toString());
if(manifest.contract!=='sports-terminal-static-nba-website-v5'||manifest.static_schema_version!==5)
 throw Error('Refusing a noncanonical dataset');
const tasks=[
 {id:'season',label:'Switch Regular season → Playoffs → Regular season; verify counts',
   reactPath:'/stats?season=2025-26&segment=regular&basis=perGame',
   instructions:'BOTH APPS: open regular Stats for 2025-26 Regular. Switch to Playoffs and back. Verify counts and qualification. Do not change rate basis during this task.'},
 {id:'basis',label:'Advanced Stats: switch Per Game → Per 36 → Per 100 and reverse a shared metric sort',
   reactPath:'/advanced?season=2025-26&segment=regular&basis=perGame',
   instructions:'BOTH APPS: open Advanced Stats (NOT regular Stats), select 2025-26 Regular and Per Game. Switch Per Game → Per 36 → Per 100, then reverse-sort the same metric available in both tables. Verify the numbers and sort order. If a control or metric is missing in either app, mark FAIL; do not substitute a different task.'},
 {id:'chart',label:'Zoom, pan, reset and change both axes in Visualization Studio',
   reactPath:'/visualizations?season=2025-26&segment=regular&basis=perGame',
   instructions:'BOTH APPS: open the available player scatter visualization for 2025-26 Regular. Wheel zoom, drag pan, reset, then change X and Y metrics. Verify plot and tooltips. If the control sets are not equivalent, mark FAIL and report the difference; do not silently change task.'}
];
const rl=createInterface({input,output});
const browser=await chromium.launch({
 headless:false,
 ...(process.env.ARCSIDE_BROWSER_CHANNEL?{channel:process.env.ARCSIDE_BROWSER_CHANNEL}:{})
});
const results=[],errors=[];
const checkpointPath=path.join(dir,'guided-checkpoint.json');
const resume=process.env.ARCSIDE_GUIDED_RESUME==='1';
// Explicitly stop after the valid season block when the operator discovers
// React/Flutter Advanced Stats feature mismatch. This is NOT a passed task.
const parityBlock=process.env.ARCSIDE_GUIDED_PARITY_BLOCK==='1';
const warmContexts={};
const ctrlStyle='position:fixed;right:10px;bottom:12px;z-index:2147483647;max-width:240px;padding:10px;background:#151b2b;color:#fff;border:2px solid #ffdc81;border-radius:8px;font:12px system-ui;box-shadow:0 2px 16px #0008;';
function pctl(){
 if(document.getElementById('arcside-guided-controls'))return;
 const n=document.createElement('div');n.id='arcside-guided-controls';
 n.style.cssText="position:fixed;right:10px;bottom:12px;z-index:2147483647;max-width:240px;padding:10px;background:#151b2b;color:#fff;border:2px solid #ffdc81;border-radius:8px;font:12px system-ui;box-shadow:0 2px 16px #0008;";
 n.innerHTML='<strong>Arcside Phase 3 task timer</strong><p style="margin:5px 0">Begin, then finish ONLY after verifying the task.</p>'+
  '<button id="arcside-start">Start</button> <button id="arcside-finish">Finish ✓</button> <button id="arcside-fail">Fail ✕</button>';
 document.body.appendChild(n);
 // Frame gaps are sampled inside each app's browser context during the
 // human-verified task. They are NOT a GPU trace or confirmed dropped frames.
 let frames=[],last=0,raf=0;
 const tick=t=>{
  if(last&&frames.length<10000)frames.push(t-last);
  last=t;raf=requestAnimationFrame(tick);
 };
 const notify=event=>{
  let frame=null;
  if(event==='start'){frames=[];last=0;cancelAnimationFrame(raf);raf=requestAnimationFrame(tick);}
  else {
   cancelAnimationFrame(raf);
   const sorted=[...frames].sort((a,b)=>a-b);
   frame={observations:sorted.length,
    p95GapMs:sorted[Math.max(0,Math.ceil(sorted.length*.95)-1)]??null,
    maxGapMs:sorted.at(-1)??null,
    gapsOver50Ms:sorted.filter(x=>x>50).length,
    samplesCapped:frames.length>=10000};
  }
  window.arcsideGuidedMark({event,frame});
 };
 n.querySelector('#arcside-start').onclick=()=>notify('start');
 n.querySelector('#arcside-finish').onclick=()=>notify('finish');
 n.querySelector('#arcside-fail').onclick=()=>notify('fail');
 window.addEventListener('keydown',e=>{
  if(e.ctrlKey&&e.shiftKey&&(e.code==='Digit8'||e.code==='Digit9'||e.code==='Digit0')){
   e.preventDefault();e.stopImmediatePropagation();
   notify(e.code==='Digit8'?'start':e.code==='Digit9'?'finish':'fail');
  }
 },true);
}
try {
 const req=await browser.newContext();
 for(const [app,base] of [['React',react],['Flutter',flutter]]){
  const res=await req.request.get(base+'/data/nba_static/manifest.json',{timeout:30000});
  if(!res.ok()||hash(await res.body())!==hash(data))
   throw Error(app+' manifest differs from the exact local verified canonical release');
 }
 await req.close();
 await mkdir(dir,{recursive:true});
 if(resume){
  let saved;
  try{saved=JSON.parse(await readFile(checkpointPath,'utf8'));}
  catch(e){throw Error('Cannot resume: missing or unreadable guided-checkpoint.json: '+e.message);}
  if(saved.manifestSha256!==hash(data))throw Error('Cannot resume: original NBA manifest differs from checkpoint');
  if(!Array.isArray(saved.raw))throw Error('Cannot resume: checkpoint raw trials missing');
  if(saved.raw.some(r=>!tasks.some(t=>t.id===r.task)||!['Flutter','React'].includes(r.app)||
    !Number.isInteger(r.trial)||r.trial<1||r.trial>cold+warm||
    r.cold!==(r.trial<=cold)||!Number.isFinite(r.ms)||r.ms<0||
    typeof r.passed!=='boolean'||typeof r.operatorVerified!=='boolean'))
   throw Error('Cannot resume: invalid or incompatible checkpoint trial data');
  const seen=new Set();
  for(const r of saved.raw){
   const k=r.task+'/'+r.app+'/'+r.trial;
   if(seen.has(k))throw Error('Cannot resume: duplicate trial '+k);
   seen.add(k);
  }
  // A discovered UX mismatch invalidates basis/chart timings for matched-task
  // performance, but never discard or rewrite the source observations.
  const beyondSeason=saved.raw.filter(r=>r.task==='basis'||r.task==='chart');
  if(beyondSeason.length&&!parityBlock)
   throw Error('Checkpoint contains basis/chart trials from a different or non-equivalent protocol. Re-run with ARCSIDE_GUIDED_PARITY_BLOCK=1 to preserve all recorded observations and produce a feature-parity blocker report.');
  await copyFile(checkpointPath,path.join(dir,'guided-checkpoint-before-resume.json'));
  results.push(...saved.raw);
  if(Array.isArray(saved.errors))errors.push(...saved.errors);
  console.log('RESUMED '+results.length+' completed trials from checkpoint (backup preserved).');
  if(results.filter(r=>r.task==='season').length===30)console.log('Season switching complete.');
 }
 if(parityBlock){
  const blockers={kind:'ARCSIDE_PHASE3_FEATURE_PARITY_BLOCKER',createdAt:new Date().toISOString(),
   manifestSha256:hash(data),status:'BLOCKED',
   scope:'Advanced Stats rate-basis-and-sort matched operator task',
   observation:'Flutter Advanced Stats provides grouped metric tables including Overview PPG and a Points Per 100 sort target; React Phase 3 /advanced exposes a smaller fixed metric list without a corresponding displayed PTS/PPG sort column.',
   provenance:'Owner screenshots and manually observed live local release builds; React src/App.tsx and src/engine.ts inspected',
   policy:'Preserve all checkpoint observations. Existing basis measurements do not establish matched-task performance. Stop repeating non-equivalent work and do not certify performance or full feature parity.',
   seasonTrials:results.filter(r=>r.task==='season').length,
   affectedTrials:results.filter(r=>r.task!=='season').map(r=>({task:r.task,app:r.app,trial:r.trial,passed:r.passed,ms:r.ms})),
   next:'Port/agree on a genuinely common metric, and separately validate the many other Flutter Advanced Stats groups before a fresh matched measurement.'};
  await writeFile(path.join(dir,'advanced-stats-parity-blocker.json'),JSON.stringify(blockers,null,2)+'\n');
  console.log('FEATURE PARITY BLOCKED: logged Advanced Stats mismatch; operator trials preserved.');
  console.log('Blocker evidence: '+path.join(dir,'advanced-stats-parity-blocker.json'));
  console.log('No additional human trials requested; this is not a PASS.');
 } else {
 console.log('Both servers use the same original v5 manifest SHA256:',hash(data));
 console.log('Stopwatch buttons appear in BOTH apps. Keyboard: Ctrl+Shift+8 START, Ctrl+Shift+9 FINISH, Ctrl+Shift+0 FAIL.');
 console.log('All timings require operator verification and reflect human task completion, not code-only frame timing.');
 console.log('IMPORTANT: rate-basis task is on ADVANCED STATS in both apps, not regular Stats.');
 for(const task of tasks){
  console.log('\nTASK '+task.id+': '+task.label+'\n'+task.instructions);
  for(let trial=0;trial<cold+warm;trial++){
   // Alternate app order to reduce thermal and practice-order bias.
   const order=trial%2===0?['Flutter','React']:['React','Flutter'];
   for(const app of order){
    if(results.some(r=>r.task===task.id&&r.app===app&&r.trial===trial+1))continue;
    const isCold=trial<cold;
    const context=isCold?await browser.newContext({viewport:{width:1440,height:900}})
     :(warmContexts[app]??=await browser.newContext({viewport:{width:1440,height:900}}));
    const page=await context.newPage();
    const base=app==='React'?react:flutter;
    const uri=base+(app==='React'?task.reactPath:'/');
    const marks={started:null,completed:null,status:null,frame:null};
    let resolveDone;
    const completed=new Promise(resolve=>{resolveDone=resolve});
    await page.exposeFunction('arcsideGuidedMark',({event,frame})=>{
     const now=performance.now();
     if(event==='start'){marks.started=now;console.log('START '+task.id+' '+app)}
     else if(event==='finish'||event==='fail'){
      if(marks.started!==null&&!marks.completed){
       marks.completed=now;marks.status=event;marks.frame=frame;resolveDone();
      }
     }
    });
    page.on('pageerror',error=>errors.push({app,task:task.id,trial,error:error.message}));
    await page.goto(uri,{waitUntil:'domcontentloaded',timeout:60000});
    await page.evaluate(pctl);
    console.log('\n'+task.id+' / '+app+' / '+(isCold?'COLD':'WARM')+
     ' sample '+(trial+1)+' of '+(cold+warm));
    await rl.question('Stage the matching starting state in the browser, then press ENTER here to arm the task. ');
    await page.bringToFront();
    console.log('Use the on-screen Start and Finish controls (or Ctrl+Shift+8 / Ctrl+Shift+9).');
    await completed;
    const ms=marks.completed-marks.started;
    results.push({task:task.id,app,trial:trial+1,cold:isCold,ms,
     passed:marks.status==='finish',operatorVerified:marks.status==='finish',
     frameProbe:marks.frame});
    if(trial===cold&&marks.status==='finish')
     await page.screenshot({path:path.join(dir,task.id+'-'+app.toLowerCase()+'.png'),fullPage:true});
    // Preserve every completed trial even if the operator aborts a later task.
    await writeFile(checkpointPath,
     JSON.stringify({inProgress:true,manifestSha256:hash(data),raw:results,errors},null,2)+'\n');
    await page.close();
    if(isCold)await context.close();
   }
  }
 }
 }
} finally {
 for(const context of Object.values(warmContexts))await context.close().catch(()=>{});
 await browser.close();
 rl.close();
}
const pct=(arr,q)=>arr.length?arr[Math.min(arr.length-1,Math.ceil(arr.length*q)-1)]:null;
const summary=[];
for(const task of tasks){
 const by={};
 for(const app of ['Flutter','React']){
  const entries=results.filter(r=>r.task===task.id&&r.app===app&&!r.cold&&r.passed);
  const times=entries.map(x=>x.ms).sort((a,b)=>a-b);
  by[app]={passedWarmRuns:entries.length,medianMs:pct(times,.5),p95Ms:pct(times,.95),
   failures:results.filter(r=>r.task===task.id&&r.app===app&&!r.passed).length};
 }
 const ratio=by.Flutter.p95Ms&&by.React.p95Ms?by.React.p95Ms/by.Flutter.p95Ms:null;
 summary.push({task:task.id,...by,p95ReactOverFlutter:ratio,
  sampledProtocolMinimum:by.Flutter.passedWarmRuns>=10&&by.React.passedWarmRuns>=10&&cold>=5,
  preRegistered10PctGate:ratio===null?'UNMEASURED':ratio<=1.1?'WITHIN_THRESHOLD':'EXCEEDS_THRESHOLD'});
}
const report={kind:'ARCSIDE_PHASE3_OPERATOR_VERIFIED_MATCHED_TASK_TIMINGS',
 protocolBlocked:parityBlock,
 createdAt:new Date().toISOString(),manifestSha256:hash(data),fingerprint:manifest.database_fingerprint,
 hardware:{platform:platform(),release:release(),arch:arch(),cpu:cpus()[0]?.model,cores:cpus().length,ram:totalmem()},
 browser:(process.env.ARCSIDE_BROWSER_CHANNEL??'bundled Chromium')+' '+browser.version(),
 method:'same machine and exact original manifest, headed browser, manual operator-verified start/stop, alternating variant order',
 frameCaveat:'rAF gaps are approximations measured in the browser during operator tasks; they are NOT actual GPU dropped-frame counts or peak browser memory. Warm trials reuse context but open a new tab.',
 limitation:'Human start/stop and task verification; not automated frame time, not a substitute for accessibility or full functional parity',
 cold,warm,summary,raw:results,errors};
await writeFile(path.join(dir,'guided-matched-task-timings.json'),JSON.stringify(report,null,2)+'\n');
console.log('Evidence: '+path.join(dir,'guided-matched-task-timings.json'));
console.log(JSON.stringify(summary,null,2));
