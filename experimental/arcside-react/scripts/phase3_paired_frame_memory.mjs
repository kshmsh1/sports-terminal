// Same-machine, same-source, operator-matched rAF/heap telemetry, NOT GPU certification.
import {chromium} from '@playwright/test';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {createInterface} from 'node:readline/promises';
import {stdin,stdout} from 'node:process';
import {platform,arch,release,cpus,totalmem} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..'),dir=path.resolve(here,'../evidence/frame-memory');
const expected=createHash('sha256').update(await readFile(path.join(root,'web/data/nba_static/manifest.json'))).digest('hex');
const urls={Flutter:process.env.ARCSIDE_FLUTTER_URL??'http://127.0.0.1:8768',
 React:process.env.ARCSIDE_REACT_URL??'http://127.0.0.1:4173'};
const n=Number(process.env.ARCSIDE_FRAME_SAMPLES??3);
if(!Number.isInteger(n)||n<2||n>20)throw Error('Use 2–20 frame samples per app');
const hash=body=>createHash('sha256').update(body).digest('hex');
const p95=xs=>xs.length?[...xs].sort((a,b)=>a-b)[Math.ceil(xs.length*.95)-1]:null;
const rl=createInterface({input:stdin,output:stdout});
const browser=await chromium.launch({headless:false,channel:process.env.ARCSIDE_BROWSER_CHANNEL??'chrome',
 args:['--enable-precise-memory-info']});
const context=await browser.newContext({viewport:{width:1440,height:900}});
const pages={Flutter:await context.newPage(),React:await context.newPage()};
const raw=[],errors=[];let approved=false;
try {
 for(const name of ['Flutter','React']){
  const res=await context.request.get(urls[name]+'/data/nba_static/manifest.json');
  if(!res.ok()||hash(await res.body())!==expected)throw Error(name+' served a different NBA v5 manifest');
 }
 await pages.Flutter.goto(urls.Flutter+'/',{waitUntil:'domcontentloaded',timeout:60000});
 await pages.React.goto(urls.React+'/visualizations?season=2025-26&segment=regular&basis=perGame',
  {waitUntil:'domcontentloaded',timeout:60000});
 await pages.Flutter.locator('flutter-view,flt-glass-pane').first().waitFor({timeout:60000});
 await pages.React.getByRole('img',{name:/Scatter plot of/}).waitFor({timeout:60000});
 console.log('Configure BOTH tabs to identical 2025-26 regular scatter, per game, top 40, GP>=50, X=REB, Y=AST.');
 console.log('Each sample: perform the same wheel zoom, pointer pan, reset and axis-change sequence.');
 const preflight=(await rl.question('Type MATCHED after checking visible inputs and plotted cohort in BOTH apps: ')).trim();
 if(preflight!=='MATCHED')throw Error('Workload not confirmed equivalent');
 approved=true;
 for(let trial=1;trial<=n;trial++)for(const name of (trial%2?['Flutter','React']:['React','Flutter'])){
  const page=pages[name];await page.bringToFront();
  await rl.question(name+' sample '+trial+'/'+n+': press ENTER to begin recording: ');
  const cdp=await context.newCDPSession(page);await cdp.send('Performance.enable');
  const before=await cdp.send('Performance.getMetrics');
  await page.evaluate(()=>{
   const o={active:true,gaps:[],prev:0,events:{wheel:0,pointerdown:0,pointermove:0,keydown:0}};
   const handlers=[];
   for(const type of Object.keys(o.events)){
    const fn=()=>{if(o.active)o.events[type]++};
    window.addEventListener(type,fn,true);handlers.push([type,fn]);
   }
   o.stop=()=>{o.active=false;for(const [type,fn] of handlers)window.removeEventListener(type,fn,true)};
   const frame=t=>{if(!o.active)return;if(o.prev)o.gaps.push(t-o.prev);o.prev=t;requestAnimationFrame(frame)};
   window.__arcsideFrameRecord=o;requestAnimationFrame(frame);
  });
  await rl.question('Perform the gestures in the visible app; press ENTER to STOP: ');
  const telemetry=await page.evaluate(()=>{
   const o=window.__arcsideFrameRecord;o.stop();
   return {gaps:o.gaps,events:o.events,heap:performance.memory?.usedJSHeapSize??null,
    heapTotal:performance.memory?.totalJSHeapSize??null};
  });
  const after=await cdp.send('Performance.getMetrics');
  const counters=await cdp.send('Memory.getDOMCounters').catch(()=>null);
  await cdp.detach();
  const metrics=v=>Object.fromEntries(v.metrics.map(x=>[x.name,x.value]));
  const old=metrics(before),current=metrics(after);
  const gaps=telemetry.gaps.filter(x=>Number.isFinite(x)&&x>=0);
  const valid=gaps.length>=60&&(telemetry.events.wheel>0||telemetry.events.pointermove>=10);
  if(!valid)errors.push(name+' trial '+trial+': too few frames or gestures');
  raw.push({app:name,trial,valid,frames:gaps.length,rafGapP95Ms:p95(gaps),
   rafGapMaxMs:gaps.length?Math.max(...gaps):null,rafGapsOver50ms:gaps.filter(x=>x>50).length,
   events:telemetry.events,jsHeapUsedBytes:telemetry.heap,jsHeapTotalBytes:telemetry.heapTotal,
   cdpJsHeapUsedBytes:current.JSHeapUsedSize??null,domNodes:counters?.nodes??null,
   layoutDurationDeltaSec:(current.LayoutDuration??0)-(old.LayoutDuration??0),
   taskDurationDeltaSec:(current.TaskDuration??0)-(old.TaskDuration??0),
   visibleScreenshotSha256:hash(await page.screenshot())});
  console.log(name+' rAF p95='+p95(gaps)?.toFixed(1)+'ms, heap='+telemetry.heap+' bytes');
 }
} catch(e){errors.push(String(e.message??e));console.error('Unqualified: '+String(e.message??e))}
finally{
 await mkdir(dir,{recursive:true});
 const summaries=Object.fromEntries(['Flutter','React'].map(name=>{
  const entries=raw.filter(x=>x.app===name&&x.valid);
  return [name,{validSamples:entries.length,p95OfFrameGapP95Ms:p95(entries.map(x=>x.rafGapP95Ms)),
   p95JsHeapBytes:p95(entries.map(x=>x.jsHeapUsedBytes).filter(Number.isFinite))}];
 }));
 const status=approved&&errors.length===0&&raw.length===2*n?'MATCHED_OPERATOR_RAF_HEAP_OBSERVED':'INCOMPLETE_OR_FAIL';
 await writeFile(path.join(dir,'paired-frame-memory.json'),JSON.stringify({
  kind:'ARCSIDE_PAIRED_FRAME_MEMORY_V1',manifestSha256:expected,status,operatorWorkloadAttested:approved,
  source:'ACTUAL_LOCAL_V5_CORPUS',browser:browser.version(),
  machine:{platform:platform(),release:release(),arch:arch(),cpu:cpus()[0]?.model,
   ramBytes:totalmem()},samplesPerApp:n,raw,summaries,errors,
  gpuFrameTimeCertified:false,nativeProcessMemoryParityCertified:false,
  caveat:'Equal workload was operator attested; browser rAF measures scheduling not GPU presentation. Chrome JS heap does not capture Flutter native renderer memory. Requires native process/GPU profiling before migration.'
 },null,2)+'\n');
 console.log('Frame/memory evidence: '+path.join(dir,'paired-frame-memory.json')+'; '+status);
 await context.close();await browser.close();rl.close();
 if(status!=='MATCHED_OPERATOR_RAF_HEAP_OBSERVED')process.exitCode=1;
}
