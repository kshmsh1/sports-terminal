// Execute on the owner's machine using genuine canonical NBA v5 source shards.
// The Flutter and React servers MUST expose byte-identical manifest URLs.
// No mocked NBA data, untracked storage sync, or speculative Flutter UI selectors.
// This probes React's real tasks and captures the Flutter reference separately;
// it deliberately does NOT claim matched Flutter interaction performance.
import {chromium,firefox,webkit} from '@playwright/test';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {cpus,totalmem,platform,release,arch} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
const repo=path.resolve(here,'../../..');
const source=path.resolve(process.env.ARCSIDE_NBA_CORPUS??path.join(repo,'web/data/nba_static'));
const react=(process.env.ARCSIDE_REACT_URL??'http://127.0.0.1:5173').replace(/\/$/,'');
const flutter=(process.env.ARCSIDE_FLUTTER_URL??'http://127.0.0.1:8765').replace(/\/$/,'');
const browsers=(process.env.ARCSIDE_REAL_BROWSERS??'chromium').split(',').map(s=>s.trim()).filter(Boolean);
const seasons=(process.env.ARCSIDE_REAL_SEASONS??'2025-26,1986-87,1946-47').split(',').map(s=>s.trim()).filter(Boolean);
const dir=path.resolve(process.env.ARCSIDE_REAL_EVIDENCE_DIR??path.join(here,'../evidence/real'));
const sha=b=>createHash('sha256').update(b).digest('hex');
const expected=await readFile(path.join(source,'manifest.json'));
const valid=JSON.parse(expected.toString());
if(valid.contract!=='sports-terminal-static-nba-website-v5'||valid.static_schema_version!==5||
 !valid.database_fingerprint)throw Error('Actual canonical v5 source is required, not an example fixture');
const catalog=JSON.parse((await readFile(path.join(source,'seasons.json'))).toString());
for(const season of seasons)if(!catalog.some(s=>s.season_id===season))
 throw Error('Requested real-data season is absent: '+season);
await mkdir(dir,{recursive:true});
const reports=[];
for(const name of browsers){
 const type={chromium,firefox,webkit}[name];
 if(!type)throw Error('Unsupported browser '+name);
 const browser=await type.launch({headless:process.env.ARCSIDE_HEADFUL!=='1',
  ...(name==='chromium'&&process.env.ARCSIDE_BROWSER_CHANNEL?{channel:process.env.ARCSIDE_BROWSER_CHANNEL}:{})});
 const result={browser:name,version:browser.version(),references:[],journeys:[],errors:[]};
 reports.push(result);
 try{
  const context=await browser.newContext({viewport:{width:1440,height:900},deviceScaleFactor:1,colorScheme:'dark'});
  const req=context.request;
  for(const [app,base] of [['React',react],['Flutter',flutter]]){
   const url=base+'/data/nba_static/manifest.json';
   const response=await req.get(url,{timeout:30000});
   if(!response.ok())throw Error(app+' server cannot serve canonical manifest at '+url+' HTTP '+response.status());
   const body=await response.body(),hash=sha(body);
   if(hash!==sha(expected))throw Error(app+' manifest is NOT identical to local original: '+hash+' != '+sha(expected));
   result.references.push({app,base,manifestSha256:hash,contract:valid.contract,
    fingerprint:valid.database_fingerprint,seasonCount:valid.season_count});
  }
  // Confirm exact input bytes, not just manifest metadata: an outdated shard
  // can otherwise make a fast frontend silently compare different basketball.
  result.sourceShards=[];
  for(const season of seasons)for(const segment of ['regular','playoffs']){
   const shard='seasons/'+season+'/'+segment+'.json';
   const bytes=await readFile(path.join(source,shard));
   const expectedHash=sha(bytes);
   for(const [app,base] of [['React',react],['Flutter',flutter]]){
    const fetched=await req.get(base+'/data/nba_static/'+shard,{timeout:60000});
    if(!fetched.ok())throw Error(app+' missing real '+shard);
    const servedHash=sha(await fetched.body());
    if(servedHash!==expectedHash)throw Error(app+' '+shard+' hash mismatches canonical local source');
    result.sourceShards.push({app,shard,sha256:servedHash,bytes:bytes.length});
   }
  }
  // Actual Flutter UI is a separate widget-tree implementation and lacks stable DOM
  // route/metric selectors. Only confirm its genuine bootstrap and capture a screenshot.
  const fp=await context.newPage();
  fp.on('pageerror',error=>result.errors.push({app:'Flutter',message:error.message}));
  const flutterStart=performance.now();
  await fp.goto(flutter+'/',{waitUntil:'domcontentloaded',timeout:60000});
  try{await fp.locator('flutter-view,flt-glass-pane').first().waitFor({timeout:45000})}
  catch{result.errors.push({app:'Flutter',message:'No confirmed Flutter root selector; inspect screenshot manually'});}
  await fp.waitForTimeout(1500);
  result.flutterBootstrapToSelectorMs=performance.now()-flutterStart;
  await fp.screenshot({path:path.join(dir,name+'-flutter-reference.png'),fullPage:true});
  result.flutterTaskComparison='NOT AUTOMATED: Flutter stats/trade UI routes and selectors differ; cannot claim task-performance ratios';
  await fp.close();
  const snapshot=JSON.parse((await readFile(path.join(source,'seasons',seasons[0],'regular.json'))).toString());
  if(!Array.isArray(snapshot.player_season_totals))throw Error('Real source has no player seasons');
  for(const season of seasons){
   for(const segment of ['regular','playoffs']){
    const real=JSON.parse((await readFile(path.join(source,'seasons',season,segment+'.json'))).toString());
    const recordCount=real.player_season_totals?.length;
    if(typeof recordCount!=='number')throw Error('Invalid real season shard');
    const p=await context.newPage();
    let task=null;
    p.on('pageerror',error=>result.errors.push({app:'React',route:season+'/'+segment,message:error.message}));
    p.on('console',msg=>{
     if(msg.type()==='error')(result.consoleErrors??=[]).push({
      app:'React',route:season+'/'+segment,message:msg.text()});
    });
    try{
    const target=react+'/stats?season='+season+'&segment='+segment+'&basis=perGame';
    const begin=performance.now();
    await p.goto(target,{waitUntil:'domcontentloaded',timeout:60000});
    const title=p.getByRole('heading',{name:'Player statistics'});
    await title.waitFor({timeout:60000});
    const summary=p.getByText(new RegExp('of '+recordCount.toLocaleString()+' player rows'));
    await summary.waitFor({timeout:60000});
    const loadMs=performance.now()-begin;
    const rowSummary=await summary.innerText();
    const qualifiedTarget=real.player_season_totals.filter(r=>{
     const gp=Number(r.games??r.gp??r.g??0);
     return Number.isFinite(gp)&&gp>=(segment==='regular'?50:4);
    }).length;
    const displayed=await p.locator('.panel-title .subtle').first().innerText();
    if(!displayed.includes(qualifiedTarget.toLocaleString()+' of '+recordCount.toLocaleString()+' player rows')){
      result.errors.push({app:'React',route:season+'/'+segment,
       message:'Qualification 50/4 source-coverage disagreement: '+displayed+' vs '+qualifiedTarget+'/'+recordCount});
    }
    task={kind:'React verified real NBA Stats route',season,segment,sourceRecords:recordCount,
      firstStatsReadoutMs:loadMs,summary:rowSummary,qualifiedExpected:qualifiedTarget,
      checks:[],failures:[],browserPerf:{}};
    // Action-to-updated-UI, not simply click dispatch: ensure the URL and
    // accessible column header agree after each rate and sorting action.
    const rstart=performance.now();
    await p.getByLabel('Rate basis').selectOption('per36');
    await p.waitForURL(/basis=per36/);
    task.checks.push('basis selector updates URL');
    task.browserPerf.basisPer36ToUrlMs=performance.now()-rstart;
    await p.getByLabel('Rate basis').selectOption('per100');
    await p.waitForURL(/basis=per100/);
    task.checks.push('basis per100 updates URL');
    await p.getByLabel('Rate basis').selectOption('totals');
    await p.waitForURL(/basis=totals/);
    task.checks.push('basis totals updates URL');
    const h=p.getByRole('columnheader',{name:/PTS/});
    const before=await h.getAttribute('aria-sort');
    await p.getByRole('button',{name:'Sort by PTS'}).click();
    const after=await h.getAttribute('aria-sort');
    if(!before||!after||before===after)result.errors.push({
     app:'React',route:season+'/'+segment,message:'Reverse PTS sort did not update accessible direction'
    });
    else task.checks.push('reverse PTS sorting and semantic direction');

    // Exercise the actual virtualized table and record observable rAF gaps.
    const frameProbe=await p.getByRole('region',{name:'Scrollable player stats'}).evaluate(async el=>{
     const intervals=[];let previous=0;
     for(let i=0;i<20;i++){
      el.scrollTop=Math.max(0,(el.scrollHeight-el.clientHeight)*i/19);
      el.dispatchEvent(new Event('scroll'));
      await new Promise(resolve=>requestAnimationFrame(t=>{
       if(previous)intervals.push(t-previous);previous=t;resolve();
      }));
     }
     const sorted=intervals.sort((a,b)=>a-b);
     return {observations:sorted.length,p95GapMs:sorted[Math.ceil(sorted.length*.95)-1]??null,
      gapsOver50Ms:sorted.filter(x=>x>50).length,
      note:'rAF gaps observed during scripted scrolling, NOT confirmed GPU dropped frames'};
    });
    task.browserPerf.scrollFrameProbe=frameProbe;
    task.checks.push('virtualized table 20-step scroll / requestAnimationFrame observation');
    const firstEligible=real.player_season_totals.find(r=>
      Number(r.games??r.gp??r.g??0)>=(segment==='regular'?50:4)&&
      typeof r.player_label==='string'&&r.player_label.trim());
    if(firstEligible){
     await p.getByLabel('Find player').fill(firstEligible.player_label);
     await p.getByRole('link',{name:firstEligible.player_label,exact:true}).first().waitFor();
     task.checks.push('source-backed player-name search');
     await p.getByLabel('Find player').fill('');
    }else task.checks.push('SKIPPED source-backed player search: no qualifying named row');
    const traded=real.player_season_totals.find(r=>
      Array.isArray(r.team_stints)&&r.team_stints.length>=2&&
      typeof r.player_label==='string'&&r.player_label.trim()&&
      Number(r.games??r.gp??r.g??0)>=(segment==='regular'?50:4));
    if(traded){
     await p.getByLabel('Find player').fill(traded.player_label);
     const expand=p.getByRole('button',{name:'Expand stints for '+traded.player_label});
     if(await expand.count()){
      await expand.click();
      const count=await p.locator('.stint-row').count();
      if(count<2)result.errors.push({app:'React',route:season+'/'+segment,
       message:'Recorded traded-player source has 2+ team stints but UI expanded '+count});
      else task.checks.push('recorded 2TM/3TM source stints expand (stints='+count+')');
     }else result.errors.push({app:'React',route:season+'/'+segment,
      message:'Recorded qualifying multi-team player not expandable: '+traded.player_label});
     await p.getByLabel('Find player').fill('');
    }else task.checks.push('SKIPPED source-backed multi-team expansion: no eligible recorded stints');
    const advanced=await p.getByRole('button',{name:'Open Advanced Stats'});
    await advanced.click();await p.getByRole('heading',{name:'Advanced player statistics'}).waitFor();
    task.checks.push('advanced route from same source');
    await p.goBack({waitUntil:'domcontentloaded'});
    await p.getByRole('heading',{name:'Player statistics'}).waitFor();
    task.checks.push('browser back restores Stats route');
    await p.getByRole('link',{name:'Visualizations'}).click();
    await p.getByRole('heading',{name:'Player scatter explorer'}).waitFor();
    const chartStart=performance.now();
    await p.getByRole('img',{name:/Scatter plot of/}).waitFor();
    await p.getByRole('button',{name:'Drag pan'}).click();
    assert.equal(await p.getByRole('button',{name:'Drag pan'}).getAttribute('aria-pressed'),'true');
    await p.getByRole('button',{name:'Wheel zoom'}).click();
    assert.equal(await p.getByRole('button',{name:'Wheel zoom'}).getAttribute('aria-pressed'),'true');
    await p.getByRole('button',{name:'Drag pan'}).click();
    await p.getByLabel('X metric').selectOption('reb');
    await p.getByLabel('Y metric').selectOption('ast');
    await p.getByRole('button',{name:'Reset view'}).click();
    await p.getByRole('checkbox',{name:'Linear reference'}).check();
    task.browserPerf.chartControlSequenceMs=performance.now()-chartStart;
    task.checks.push('chart re-axis, pan/zoom, reset, regression; response observed');
    if(segment==='regular'&&season===seasons[0]){
     await p.reload({waitUntil:'domcontentloaded'});
     await p.getByRole('heading',{name:'Player scatter explorer'}).waitFor();
     assert.equal(await p.getByLabel('X metric').inputValue(),'reb');
     assert.equal(await p.getByLabel('Y metric').inputValue(),'ast');
     assert.equal(await p.getByRole('button',{name:'Drag pan'}).getAttribute('aria-pressed'),'true');
     task.checks.push('visualization axis and pan settings persist after reload');
     await p.screenshot({path:path.join(dir,name+'-react-visualizations-'+season+'.png'),fullPage:true});
     await p.getByRole('link',{name:'Stats',exact:true}).click();
     await p.getByRole('heading',{name:'Player statistics'}).waitFor();
     await p.getByRole('link',{name:'Skip to content'}).focus();
     assert.equal(await p.getByRole('link',{name:'Skip to content'}).evaluate(n=>document.activeElement===n),true);
     task.checks.push('keyboard focusable skip-to-main and route navigation');
     await p.screenshot({path:path.join(dir,name+'-react-stats-wide-'+season+'.png'),fullPage:true});
     await p.getByRole('button',{name:'Switch to light theme'}).click();
     await p.screenshot({path:path.join(dir,name+'-react-stats-light-'+season+'.png'),fullPage:true});
     await p.setViewportSize({width:390,height:844});
     await p.screenshot({path:path.join(dir,name+'-react-stats-narrow-'+season+'.png'),fullPage:true});
     task.checks.push('dark/light and narrow/wide screenshots captured (manual visual audit required)');
    }
    task.browserPerf.resourceEntries=await p.evaluate(()=>({
     count:performance.getEntriesByType('resource').length,
     measuredTransferBytes:performance.getEntriesByType('resource').reduce((s,r)=>s+(r.transferSize??0),0),
     caveat:'Browser resourceTiming transferSize may omit cached/cross-origin or service-worker bytes'
    }));
    result.journeys.push(task);
    }catch(error){
     const message=error instanceof Error?error.message:String(error);
     result.errors.push({app:'React',route:season+'/'+segment,message});
     if(task){
      task.failures.push(message);
      result.journeys.push(task);
     }
    }finally{await p.close();}

   }
  }
  // Existing Labs: inspect only the typed handshake; no code, tokens, workbooks transmitted.
  for(const lab of ['python','sheets']){
   const p=await context.newPage();
   p.on('pageerror',e=>result.errors.push({app:'React',lab,message:e.message}));
   await p.goto(react+'/workspaces/'+lab+'?season='+seasons[0]+'&segment=regular&basis=perGame');
   await p.getByText('Context handshake: acknowledged',{exact:false}).waitFor({timeout:40000});
   result.journeys.push({kind:'Original Lab handshake',lab,status:'acknowledged'});
   await p.close();
  }
  await context.close();
 }finally{await browser.close()}
}
const report={kind:'ARCSIDE_PHASE3_REAL_SOURCE_BROWSER_JOURNEY',createdAt:new Date().toISOString(),
 evaluationScope:'Source-exact React Stats/Advanced/chart tasks plus Flutter bootstrap screenshot; NOT matched Flutter widget interaction timings',
 source:'ACTUAL_LOCAL_V5_CORPUS',manifestSha256:sha(expected),sourceRoot:source,
 hardware:{platform:platform(),release:release(),arch:arch(),cpu:cpus()[0]?.model,cores:cpus().length,ram:totalmem()},
 seasons,browsers:reports,warning:'Real-source React journey checks and Flutter startup screenshot, not matched Flutter task-performance or accessibility acceptance'};
const name=path.join(dir,'real-source-journeys.json');
await writeFile(name,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({output:name,manifestSha256:report.manifestSha256,
 reactJourneys:reports.reduce((n,x)=>n+x.journeys.length,0),
 verifiedShards:reports.reduce((n,x)=>n+(x.sourceShards?.length??0),0),
 flutterMatchedTasks:'NOT MEASURED',browserErrors:reports.flatMap(x=>x.errors)},null,2));
if(reports.some(x=>x.errors.length))process.exitCode=1;
