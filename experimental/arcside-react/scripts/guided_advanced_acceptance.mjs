// Targeted post-repair Phase 3 Advanced Stats comparison: exactly 30
// operator-verified matched attempts, not the invalidated old 90-trial study.
// Original Flutter canvas is NOT scripted with guessed DOM selectors.
// The operator must check actual functionality before certifying any trial.
import {chromium} from '@playwright/test';
import {installGuidedOverlay} from './guided_overlay.mjs';
import {readFile,writeFile,mkdir,copyFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {performance} from 'node:perf_hooks';
import {createInterface} from 'node:readline/promises';
import {stdin,stdout} from 'node:process';
import {platform,arch,release,cpus,totalmem} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
const repo=path.resolve(here,'../../..'),dir=path.resolve(here,'../evidence/advanced');
const manifestBytes=await readFile(path.join(repo,'web/data/nba_static/manifest.json'));
const sourceHash=createHash('sha256').update(manifestBytes).digest('hex');
const source=JSON.parse(manifestBytes.toString());
if(source.contract!=='sports-terminal-static-nba-website-v5'||source.static_schema_version!==5)
 throw Error('Canonical source missing');
const parity=JSON.parse(await readFile(path.join(dir,'advanced-source-parity.json'),'utf8'));
if(parity.status!=='PASS'||parity.manifestSha256!==sourceHash)
 throw Error('Do NOT benchmark until Advanced Stats Dart/React source semantic parity passes on this original manifest');
const react=(process.env.ARCSIDE_REACT_URL??'http://127.0.0.1:4173').replace(/\/$/,'');
const flutter=(process.env.ARCSIDE_FLUTTER_URL??'http://127.0.0.1:8768').replace(/\/$/,'');
const resume=process.env.ARCSIDE_ADVANCED_RESUME==='1',protocol='ADVANCED_STATS_V2_AFTER_CATALOG_REPAIR';
const checkpoint=path.join(dir,'guided-checkpoint-v2.json'),target=path.join(dir,'advanced-guided-timings-v2.json');
const raw=[],errors=[];
const rl=createInterface({input:stdin,output:stdout});
const browser=await chromium.launch({headless:false,...(process.env.ARCSIDE_BROWSER_CHANNEL?{channel:process.env.ARCSIDE_BROWSER_CHANNEL}:{})});
const warmContexts={},meta={kind:'ARCSIDE_ADVANCED_MATCHED_TASKS_V2',protocol,source:'ACTUAL_LOCAL_V5_CORPUS',
 manifestSha256:sourceHash,cold:5,warm:10,operatorConfirmed:false,
 hardware:{platform:platform(),arch:arch(),release:release(),cpu:cpus()[0]?.model,cores:cpus().length,ram:totalmem()},
 browser:browser.version(),task:'2025-26 Advanced Stats: Per Game -> Per 36 -> Per 100; reverse PTS/100 sort, verify rows and numbers',
 method:'same machine release servers, 5 cold and 10 warm per app, alternate order, human verification, browser stopwatch; NOT GPU render times'};
async function write(){await writeFile(checkpoint,JSON.stringify({...meta,raw,errors,inProgress:true},null,2)+'\n')}
const summary=()=>{
 const by={};for(const app of ['Flutter','React']){
  const all=raw.filter(r=>r.app===app),warm=all.filter(r=>!r.cold&&r.passed);
  const times=warm.map(r=>r.ms).sort((a,b)=>a-b);
  const percentile=q=>times.length?times[Math.ceil(times.length*q)-1]:null;
  by[app]={completed:all.length,cold:all.filter(r=>r.cold).length,
   warm:all.filter(r=>!r.cold).length,failures:all.filter(r=>!r.passed).length,
   medianMs:percentile(.5),p95Ms:percentile(.95)};
 }
 const ratio=by.Flutter.p95Ms&&by.React.p95Ms?by.React.p95Ms/by.Flutter.p95Ms:null;
 const qualified=meta.operatorConfirmed&&by.Flutter.completed===15&&by.React.completed===15&&
  by.Flutter.cold===5&&by.React.cold===5&&
  by.Flutter.warm===10&&by.React.warm===10&&
  !by.Flutter.failures&&!by.React.failures;
 return {by,p95ReactOverFlutter:ratio,qualified,within10Pct:qualified&&ratio!==null&&ratio<=1.10};
};
try{
 const req=await browser.newContext();
 for(const [app,base] of [['Flutter',flutter],['React',react]]){
  const res=await req.request.get(base+'/data/nba_static/manifest.json',{timeout:30000});
  if(!res.ok()||createHash('sha256').update(await res.body()).digest('hex')!==sourceHash)
   throw Error('Refusing stale or nonmatching '+app+' release server');
 }
 await req.close();
 await mkdir(dir,{recursive:true});
 if(resume){
  const saved=JSON.parse(await readFile(checkpoint,'utf8'));
  if(saved.protocol!==protocol||saved.manifestSha256!==sourceHash||!saved.operatorConfirmed||
      !Array.isArray(saved.raw))throw Error('Wrong protocol or source checkpoint: cannot resume');
  const seen=new Set();
  for(const r of saved.raw){
   const k=r.app+'/'+r.trial;
   if(seen.has(k)||!['Flutter','React'].includes(r.app)||r.trial<1||r.trial>15||
      r.cold!==(r.trial<=5)||!Number.isFinite(r.ms)||r.ms<0)
    throw Error('Corrupt or duplicated checkpoint '+k);
   seen.add(k);
  }
  await copyFile(checkpoint,path.join(dir,'guided-checkpoint-v2-backup.json'));
  raw.push(...saved.raw);errors.push(...(saved.errors??[]));meta.operatorConfirmed=true;
  console.log('RESUMED '+raw.length+'/30 corrected-protocol trials; original failed basis trials are NOT reused.');
 }else{
  const paired=await browser.newContext({viewport:{width:1440,height:900}});
  const fp=await paired.newPage(),rp=await paired.newPage();
  await fp.goto(flutter+'/',{waitUntil:'domcontentloaded'});
  await rp.goto(react+'/advanced?season=2025-26&segment=regular&basis=perGame',{waitUntil:'domcontentloaded'});
  await rp.getByRole('button',{name:'Sort by PPG'}).waitFor({timeout:60000});
  await fp.bringToFront();
  console.log('\nPREFLIGHT - BOTH RELEASE VERSIONS');
  console.log('Flutter: navigate to Advanced Stats, set 2025-26 Regular / Per Game / Overview.');
  console.log('React: Advanced Stats starts there. Verify both show PPG and can change to PTS/100,');
  console.log('reverse-sort the SAME PTS/100 column, and the visible player values/ordering agree.');
  console.log('Also check GP=50+, MPG=20+, group switching, team/player search and table readability.');
  console.log('Do NOT approve merely because a label exists. If anything differs, enter FAIL.');
  const answer=(await rl.question('Type MATCHED only after verifying BOTH live interfaces (otherwise FAIL): ')).trim();
  await paired.close();
  if(answer!=='MATCHED'){
   errors.push({stage:'preflight',message:'Operator did NOT attest equivalent live Advanced Stats interactions'});
   console.log('BLOCKED. No human timings collected and prior source observations preserved.');
  }else meta.operatorConfirmed=true;
  await write();
 }
 if(meta.operatorConfirmed){
  let stopped=false;
  for(let i=1;i<=15&&!stopped;i++){
   for(const app of i%2?['Flutter','React']:['React','Flutter']){
    if(raw.some(r=>r.app===app&&r.trial===i))continue;
    const cold=i<=5;
    const ctx=cold?await browser.newContext({viewport:{width:1440,height:900}}):
     (warmContexts[app]??=await browser.newContext({viewport:{width:1440,height:900}}));
    const page=await ctx.newPage();let start=null,done=null,finish;
    const complete=new Promise(resolve=>finish=resolve);
    await page.exposeFunction('arcsideAdvancedMark',({event,frame})=>{
     const t=performance.now();
     if(event==='start'&&start===null){start=t;console.log('START '+app+'/'+i)}
     else if(start!==null&&done===null&&(event==='finish'||event==='fail')){
      done={ms:t-start,passed:event==='finish',frame};finish();
     }
    });
    page.on('pageerror',e=>errors.push({app,trial:i,message:e.message}));
    page.on('framenavigated',frame=>{
     if(frame===page.mainFrame()&&start!==null&&done===null){
      done={ms:performance.now()-start,passed:false,reason:'navigation_during_active_trial'};finish();
     }
    });
    await page.addInitScript(installGuidedOverlay,{binding:'arcsideAdvancedMark',
     title:'Arcside Advanced Stats benchmark',
     instructions:'Per Game → Per 36 → Per 100; reverse PTS/100 sort. Finish only after checking the displayed values.'});
    await page.goto((app==='Flutter'?flutter+'/':react+'/advanced?season=2025-26&segment=regular&basis=perGame'),
     {waitUntil:'domcontentloaded',timeout:60000});
    console.log('\n'+app+' '+(cold?'COLD':'WARM')+' trial '+i+'/15');
    console.log('Stage 2025-26 / Regular / Per Game / Overview and PTS descending.');
    await rl.question('Press ENTER once starting state is ready in this browser: ');
    await page.bringToFront();
    console.log('Start Ctrl+Shift+8, Finish Ctrl+Shift+9, Fail Ctrl+Shift+0.');
    await complete;
    raw.push({app,trial:i,cold,ms:done.ms,passed:done.passed,operatorVerified:done.passed,
     frameProbe:done.frame??null,reason:done.reason??null});
    await write();
    await page.close();if(cold)await ctx.close();
    if(!done.passed){console.log('FAIL: matched UI task mismatch. Stopping immediately.');stopped=true;break}
   }
  }
 }
}finally{
 for(const ctx of Object.values(warmContexts))await ctx.close().catch(()=>{});
 await browser.close();rl.close();
 const result={...meta,raw,errors,...summary(),createdAt:new Date().toISOString()};
 result.status=result.within10Pct?'PASS':meta.operatorConfirmed?'INCOMPLETE_OR_FAIL':'BLOCKED';
 await mkdir(dir,{recursive:true});
 await writeFile(target,JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify({status:result.status,operatorConfirmed:result.operatorConfirmed,
  completed:raw.length,summary:result.by,ratio:result.p95ReactOverFlutter,
  within10Pct:result.within10Pct,output:target},null,2));
}
if(raw.length!==30||!meta.operatorConfirmed||!summary().within10Pct)process.exitCode=1;
