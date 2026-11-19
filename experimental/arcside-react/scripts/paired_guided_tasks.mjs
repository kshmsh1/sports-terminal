// Manually controlled, SAME-HARDWARE user-task evaluation of Flutter vs React.
// Does not infer Flutter widget selectors or pretend scripted React tests are matched.
// Each task is started/stopped INSIDE the evaluated browser, via the identical
// minimally intrusive stopwatch control. User marks success or failure.
// Requires both local servers, original authentic v5 JSON manifest, and headed Chromium.
import {chromium} from '@playwright/test';
import {createInterface} from 'node:readline/promises';
import {stdin as input,stdout as output} from 'node:process';
import {performance} from 'node:perf_hooks';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
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
   instructions:'Start on Stats for 2025-26 Regular. Switch to Playoffs and back. Verify both table counts and qualification.'},
 {id:'basis',label:'Change Per Game → Per 36 → Per 100, then reverse PTS sort',
   reactPath:'/stats?season=2025-26&segment=regular&basis=perGame',
   instructions:'Start on Stats / 2025-26 / Per Game. Switch to Per 36, then Per 100, and sort PTS ascending. Verify values.'},
 {id:'chart',label:'Zoom, pan, reset and change both axes in Visualization Studio',
   reactPath:'/visualizations?season=2025-26&segment=regular&basis=perGame',
   instructions:'Start on Visualization Studio / 2025-26 / Regular. Wheel zoom, drag pan, reset, then change X and Y metrics. Verify plot and tooltips.'}
];
const rl=createInterface({input,output});
const browser=await chromium.launch({
 headless:false,
 ...(process.env.ARCSIDE_BROWSER_CHANNEL?{channel:process.env.ARCSIDE_BROWSER_CHANNEL}:{})
});
const results=[],errors=[];
const warmContexts={};
const ctrlStyle='position:fixed;right:10px;bottom:12px;z-index:2147483647;max-width:240px;padding:10px;background:#151b2b;color:#fff;border:2px solid #ffdc81;border-radius:8px;font:12px system-ui;box-shadow:0 2px 16px #0008;';
function pctl(){
 if(document.getElementById('arcside-guided-controls'))return;
 const n=document.createElement('div');n.id='arcside-guided-controls';
 n.style.cssText="position:fixed;right:10px;bottom:12px;z-index:2147483647;max-width:240px;padding:10px;background:#151b2b;color:#fff;border:2px solid #ffdc81;border-radius:8px;font:12px system-ui;box-shadow:0 2px 16px #0008;";
 n.innerHTML='<strong>Arcside Phase 3 task timer</strong><p style="margin:5px 0">Begin, then finish ONLY after verifying the task.</p>'+
  '<button id="arcside-start">Start</button> <button id="arcside-finish">Finish ✓</button> <button id="arcside-fail">Fail ✕</button>';
 document.body.appendChild(n);
 const notify=(event)=>window.arcsideGuidedMark({event});
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
 console.log('Both servers use the same original v5 manifest SHA256:',hash(data));
 console.log('Stopwatch buttons appear in BOTH apps. Keyboard: Ctrl+Shift+8 START, Ctrl+Shift+9 FINISH, Ctrl+Shift+0 FAIL.');
 console.log('All timings require operator verification and reflect human task completion, not code-only frame timing.');
 for(const task of tasks){
  console.log('\nTASK '+task.id+': '+task.label+'\n'+task.instructions);
  for(let trial=0;trial<cold+warm;trial++){
   // Alternate app order to reduce thermal and practice-order bias.
   const order=trial%2===0?['Flutter','React']:['React','Flutter'];
   for(const app of order){
    const isCold=trial<cold;
    const context=isCold?await browser.newContext({viewport:{width:1440,height:900}})
     :(warmContexts[app]??=await browser.newContext({viewport:{width:1440,height:900}}));
    const page=await context.newPage();
    const base=app==='React'?react:flutter;
    const uri=base+(app==='React'?task.reactPath:'/');
    const marks={started:null,completed:null,status:null};
    let resolveDone;
    const completed=new Promise(resolve=>{resolveDone=resolve});
    await page.exposeFunction('arcsideGuidedMark',({event})=>{
     const now=performance.now();
     if(event==='start'){marks.started=now;console.log('START '+task.id+' '+app)}
     else if(event==='finish'||event==='fail'){
      if(marks.started!==null&&!marks.completed){
       marks.completed=now;marks.status=event;resolveDone();
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
     passed:marks.status==='finish',operatorVerified:marks.status==='finish'});
    if(trial===cold&&marks.status==='finish')
     await page.screenshot({path:path.join(dir,task.id+'-'+app.toLowerCase()+'.png'),fullPage:true});
    await page.close();
    if(isCold)await context.close();
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
 createdAt:new Date().toISOString(),manifestSha256:hash(data),fingerprint:manifest.database_fingerprint,
 hardware:{platform:platform(),release:release(),arch:arch(),cpu:cpus()[0]?.model,cores:cpus().length,ram:totalmem()},
 browser:'Chromium '+browser.version(),method:'same machine and exact original manifest, headed browser, manual operator-verified start/stop, alternating variant order',
 limitation:'Human start/stop and task verification; not automated frame time, not a substitute for accessibility or full functional parity',
 cold,warm,summary,raw:results,errors};
await writeFile(path.join(dir,'guided-matched-task-timings.json'),JSON.stringify(report,null,2)+'\n');
console.log('Evidence: '+path.join(dir,'guided-matched-task-timings.json'));
console.log(JSON.stringify(summary,null,2));
