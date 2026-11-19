// Execute on the owner's machine using genuine canonical NBA v5 source shards.
// The Flutter and React servers MUST expose byte-identical manifest URLs.
// No mocked NBA data, untracked storage sync, or speculative Flutter UI selectors.
// This probes React's real tasks and captures the Flutter reference separately;
// it deliberately does NOT claim matched Flutter interaction performance.
import {chromium,firefox,webkit} from '@playwright/test';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
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
 const browser=await type.launch({headless:process.env.ARCSIDE_HEADFUL!=='1'});
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
    p.on('pageerror',error=>result.errors.push({app:'React',route:season+'/'+segment,message:error.message}));
    const target=react+'/stats?season='+season+'&segment='+segment+'&basis=perGame';
    const begin=performance.now();
    await p.goto(target,{waitUntil:'domcontentloaded',timeout:60000});
    const title=p.getByRole('heading',{name:'Player statistics'});
    await title.waitFor({timeout:60000});
    const summary=p.getByText(new RegExp('of '+recordCount.toLocaleString()+' player rows'));
    await summary.waitFor({timeout:60000});
    const loadMs=performance.now()-begin;
    const rowSummary=await summary.innerText();
    const task={kind:'React verified real NBA Stats route',season,segment,sourceRecords:recordCount,
      firstStatsReadoutMs:loadMs,summary:rowSummary,checks:[]};
    await p.getByLabel('Rate basis').selectOption('per36');
    await p.waitForURL(/basis=per36/);
    task.checks.push('basis selector updates URL');
    const advanced=await p.getByRole('button',{name:'Open Advanced Stats'});
    await advanced.click();await p.getByRole('heading',{name:'Advanced player statistics'}).waitFor();
    task.checks.push('advanced route from same source');
    await p.getByRole('link',{name:'Visualizations'}).click();
    await p.getByRole('heading',{name:'Player scatter explorer'}).waitFor();
    await p.getByRole('button',{name:'Drag pan'}).click();
    await p.getByLabel('X metric').selectOption('reb');
    task.checks.push('chart re-axis and pan mode with same input');
    if(segment==='regular'&&season===seasons[0]){
     await p.screenshot({path:path.join(dir,name+'-react-visualizations-'+season+'.png'),fullPage:true});
    }
    result.journeys.push(task);
    await p.close();
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
 source:'ACTUAL_LOCAL_V5_CORPUS',manifestSha256:sha(expected),sourceRoot:source,
 hardware:{platform:platform(),release:release(),arch:arch(),cpu:cpus()[0]?.model,cores:cpus().length,ram:totalmem()},
 seasons,browsers:reports,warning:'Real-source React journey checks and Flutter startup screenshot, not matched Flutter task-performance or accessibility acceptance'};
const name=path.join(dir,'real-source-journeys.json');
await writeFile(name,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({output:name,manifestSha256:report.manifestSha256,
 reactJourneys:reports.reduce((n,x)=>n+x.journeys.length,0),
 flutterMatchedTasks:'NOT MEASURED',browserErrors:reports.flatMap(x=>x.errors)},null,2));
if(reports.some(x=>x.errors.length))process.exitCode=1;
