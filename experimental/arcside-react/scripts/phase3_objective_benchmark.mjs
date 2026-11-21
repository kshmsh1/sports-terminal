// Observational, reproducible Phase 3 browser metrics. Never authorizes migration.
// Measures browser-visible events and rAF gaps, not GPU presentation or native accessibility.
// Same immutable NBA v5 manifest, fresh/retained contexts, alternating releases.
import {chromium,firefox,webkit} from '@playwright/test';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {cpus,totalmem,platform,release,arch} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {performance} from 'node:perf_hooks';

const here=path.dirname(fileURLToPath(import.meta.url));
const repo=path.resolve(here,'../../..');
const out=path.resolve(here,'../evidence/objective');
const bytes=await readFile(path.join(repo,'web/data/nba_static/manifest.json'));
const manifestSha256=createHash('sha256').update(bytes).digest('hex');
const manifest=JSON.parse(bytes);
if(manifest.contract!=='sports-terminal-static-nba-website-v5'||manifest.static_schema_version!==5)
 throw Error('Objective comparison requires the genuine original NBA v5 manifest.');
const urls={Flutter:process.env.ARCSIDE_FLUTTER_URL??'http://127.0.0.1:8768',
 React:process.env.ARCSIDE_REACT_URL??'http://127.0.0.1:4173'};
const engine=process.env.ARCSIDE_OBJECTIVE_BROWSER??'chromium';
const launcher={chromium,firefox,webkit}[engine];
if(!launcher)throw Error('Invalid ARCSIDE_OBJECTIVE_BROWSER: '+engine);
const cold=Number(process.env.ARCSIDE_OBJECTIVE_COLD??5);
const warm=Number(process.env.ARCSIDE_OBJECTIVE_WARM??10);
if(!Number.isInteger(cold)||cold<1||cold>20||!Number.isInteger(warm)||warm<2||warm>30)
 throw Error('Require 1-20 cold and 2-30 warm samples per app');
const rounds=cold+warm;
const browser=await launcher.launch({headless:true,...(engine==='chromium'&&process.env.ARCSIDE_BROWSER_CHANNEL?
 {channel:process.env.ARCSIDE_BROWSER_CHANNEL}:{})});
const meta={kind:'ARCSIDE_OBJECTIVE_BROWSER_PERFORMANCE_V1',source:'ACTUAL_LOCAL_V5_CORPUS',
 manifestSha256,manifestSeasonCount:manifest.season_count,method:'Identical v5 manifest; 1440x900; alternating app order; fresh context per cold sample, reused context per warm sample; Chromium/Firefox/WebKit headless browser probes. Browser navigation/DOM readiness and request/animation frame telemetry are NOT matched GPU render-completion metrics. Flutter feature-specific UI actions are not automated.',
 hardware:{platform:platform(),release:release(),arch:arch(),cpu:cpus()[0]?.model,
 cores:cpus().length,ram:totalmem()},browserEngine:engine,browserVersion:browser.version(),
 cold,warm,createdAt:new Date().toISOString()};
const raw=[],errors=[],contexts={};
const sha=body=>createHash('sha256').update(body).digest('hex');
const percentile=(xs,p)=>xs.length?[...xs].sort((a,b)=>a-b)[Math.ceil(xs.length*p)-1]:null;
const stats=xs=>({count:xs.length,medianMs:percentile(xs,.5),p95Ms:percentile(xs,.95),
 minMs:xs.length?Math.min(...xs):null,maxMs:xs.length?Math.max(...xs):null});
async function manifestCheck(base){
 const response=await fetch(base+'/data/nba_static/manifest.json');
 if(!response.ok||sha(Buffer.from(await response.arrayBuffer()))!==manifestSha256)
  throw Error('Stale or mismatched authentic manifest: '+base);
}
try{
 for(const base of Object.values(urls))await manifestCheck(base.replace(/\/$/,''));
 for(let trial=1;trial<=rounds;trial++){
  for(const app of trial%2?['Flutter','React']:['React','Flutter']){
   const isCold=trial<=cold,base=urls[app].replace(/\/$/,'');
   const context=isCold?await browser.newContext({viewport:{width:1440,height:900}}):
    (contexts[app]??=await browser.newContext({viewport:{width:1440,height:900}}));
   const page=await context.newPage(),exceptions=[];
   page.on('pageerror',e=>exceptions.push('pageerror: '+e.message));
   page.on('console',m=>{if(m.type()==='error')exceptions.push('console: '+m.text().slice(0,300))});
   const responses=[];
   page.on('response',r=>responses.push({url:r.url(),status:r.status()}));
   const start=performance.now();
   try{
    const route=app==='React'?'/visualizations?season=2025-26&segment=regular&basis=perGame':'/';
    const response=await page.goto(base+route,{waitUntil:'domcontentloaded',timeout:60000});
    const domContentLoadedMs=performance.now()-start;
    const firstPaint=await page.evaluate(async()=>{
     await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
     const nav=performance.getEntriesByType('navigation')[0];
     const paints=performance.getEntriesByType('paint');
     const memory=globalThis.performance?.memory;
     return {navDomContentLoadedMs:nav?.domContentLoadedEventEnd??null,
      browserFirstPaintMs:paints.find(x=>x.name==='first-paint')?.startTime??null,
      browserFirstContentfulPaintMs:paints.find(x=>x.name==='first-contentful-paint')?.startTime??null,
      jsHeapUsedBytes:memory?.usedJSHeapSize??null,
      jsHeapTotalBytes:memory?.totalJSHeapSize??null,devicePixelRatio:devicePixelRatio};
    });
    let readyMs=null,readyType='NONE',readyVerified=false;
    if(app==='React'){
     await page.getByRole('heading',{name:'Player scatter explorer'}).waitFor({timeout:60000});
     await page.getByRole('img',{name:/Scatter plot of/}).waitFor({timeout:60000});
     readyMs=performance.now()-start;readyType='React player scatter role visible';
     // Canvas must contain nontransparent pixels. Do not assert cross-engine visual parity.
     readyVerified=await page.locator('.studio-chart canvas').first().evaluate(c=>{
      const ctx=c.getContext('2d');
      if(!ctx)return false;
      const {width,height}=c;if(!width||!height)return false;
      const image=ctx.getImageData(0,0,width,height).data;
      for(let i=3;i<image.length;i+=Math.max(4,Math.floor(image.length/1200/4)*4))if(image[i]>0)return true;
      return false;
     }).catch(()=>false);
    }else{
     await page.locator('flutter-view,flt-glass-pane').first().waitFor({timeout:60000});
     readyMs=performance.now()-start;readyType='Flutter root mounted ONLY; no chart readiness assertion';
     readyVerified=false;
    }
    const settled=await page.evaluate(async()=>{
     const gaps=[];let previous=0;
     await new Promise(resolve=>{
      let frames=0;
      const sample=now=>{
       if(previous)gaps.push(now-previous);previous=now;
       if(++frames<120)requestAnimationFrame(sample);else resolve();
      };requestAnimationFrame(sample);
     });
     const sorted=[...gaps].sort((a,b)=>a-b);
     return {frameSamples:gaps.length,rafP95GapMs:sorted[Math.ceil(sorted.length*.95)-1]??null,
      rafMaxGapMs:sorted.at(-1)??null,rafGapsOver50Ms:gaps.filter(x=>x>50).length};
    });
    const requests=responses.filter(x=>x.url.startsWith(base));
    raw.push({app,trial,cold:isCold,route,domContentLoadedMs,readyMs,readyType,readyVerified,
     ...firstPaint,...settled,responseStatus:response?.status()??null,
     sameOriginRequests:requests.length,badResponses:requests.filter(x=>x.status>=400),
     exceptions,qualifiedForMatchedChartP95:false});
   }catch(e){
    errors.push({app,trial,error:String(e.message??e)});
    raw.push({app,trial,cold:isCold,failed:true,error:String(e.message??e),qualifiedForMatchedChartP95:false});
   }finally{
    await page.close().catch(()=>{});
    if(isCold)await context.close().catch(()=>{});
   }
  }
 }
}finally{
 for(const ctx of Object.values(contexts))await ctx.close().catch(()=>{});
 await browser.close();
 await mkdir(out,{recursive:true});
 const summary={};
 for(const app of ['Flutter','React']){
  const samples=raw.filter(x=>x.app===app);
  summary[app]={cold:samples.filter(x=>x.cold).length,warm:samples.filter(x=>!x.cold).length,
   failures:samples.filter(x=>x.failed||x.exceptions?.length||x.badResponses?.length).length,
   domContentLoaded:stats(samples.filter(x=>!x.cold&&Number.isFinite(x.domContentLoadedMs)).map(x=>x.domContentLoadedMs)),
   visibleProbe:stats(samples.filter(x=>!x.cold&&Number.isFinite(x.readyMs)).map(x=>x.readyMs)),
   rafP95Gaps:stats(samples.filter(x=>!x.cold&&Number.isFinite(x.rafP95GapMs)).map(x=>x.rafP95GapMs))};
 }
 const report={...meta,raw,errors,summary,
  status:errors.length||raw.some(x=>x.exceptions?.length||x.badResponses?.length)?'INCOMPLETE_OR_FAIL':'OBSERVATIONAL_PASS',
  comparableChartReady:false,matchedGpuPerformance:false,
  caveat:'React chart readiness and Flutter root bootstrap are different milestones. Do not compare their readyMs ratios or call the relative p95 a chart performance result. rAF gaps are browser scheduling proxies, not actual compositor/GPU frame timings.'};
 await writeFile(path.join(out,'objective-browser-performance.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({status:report.status,report:path.join(out,'objective-browser-performance.json'),
  summary:report.summary,matchedGpuPerformance:false},null,2));
}
if(errors.length||raw.some(x=>x.exceptions?.length||x.badResponses?.length))process.exitCode=1;
