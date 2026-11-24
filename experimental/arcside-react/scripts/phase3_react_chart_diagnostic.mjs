// Controlled React-only chart operation diagnosis. NO Flutter performance claim.
// Original corpus and source-acceptance are mandatory. Writes untracked evidence.
import {chromium} from '@playwright/test';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {performance} from 'node:perf_hooks';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
const repo=path.resolve(here,'../../..');
const folder=path.resolve(here,'../evidence/visualization');
const hash=x=>createHash('sha256').update(x).digest('hex');
const manifestHash=hash(await readFile(path.join(repo,'web/data/nba_static/manifest.json')));
const parity=JSON.parse(await readFile(path.join(folder,'visualization-source-parity.json'),'utf8'));
if(parity.source!=='ACTUAL_LOCAL_V5_CORPUS'&&parity.manifestSha256!==manifestHash)
 throw Error('Real Dart-vs-React visualization parity is missing');
if(parity.manifestSha256!==manifestHash||parity.status!=='PASS'||parity.mismatches!==0)
 throw Error('Original Flutter visualization source must pass before diagnosis');
const url=(process.env.ARCSIDE_REACT_URL??'http://127.0.0.1:4173').replace(/\/$/,'');
const trials=Number(process.env.ARCSIDE_DIAGNOSTIC_TRIALS??10);
if(!Number.isInteger(trials)||trials<2||trials>30)throw Error('Use 2–30 diagnostic trials');
const results=[],errors=[];
const browser=await chromium.launch({headless:true,...(process.env.ARCSIDE_BROWSER_CHANNEL?{channel:process.env.ARCSIDE_BROWSER_CHANNEL}:{})});
const context=await browser.newContext({viewport:{width:1440,height:900}});
const page=await context.newPage();
const trace=process.env.ARCSIDE_VIS_TRACE==='1';
const initial='0.000:100.000|0.000:100.000';
const requireViewport=async expected=>page.waitForFunction(value=>{
 const current=document.querySelector('.studio-chart')?.getAttribute('data-viewport-range');
 return current&&(value===null?current!=='0.000:100.000|0.000:100.000':current===value);
},expected,{timeout:8000});
const measure=async(label,act)=>{
 const start=performance.now();
 await act();
 return {operation:label,ms:performance.now()-start};
};
try{
 const res=await context.request.get(url+'/data/nba_static/manifest.json');
 if(!res.ok()||hash(await res.body())!==manifestHash)
  throw Error('React browser did not serve authentic matching v5 NBA manifest');
 await page.goto(url+'/visualizations?season=2025-26&segment=regular&basis=perGame',
  {waitUntil:'domcontentloaded',timeout:60000});
 await page.getByRole('heading',{name:'Player scatter explorer'}).waitFor();
 const plot=page.locator('.studio-chart');
 await plot.waitFor({state:'visible',timeout:60000});
 await page.locator('.studio .chart-accessible tbody tr').first().waitFor({timeout:60000});
 if(trace)await context.tracing.start({screenshots:true,snapshots:true,sources:true});
 for(let n=1;n<=trials;n++){
  const operations=[];
  try{
   operations.push(await measure('reset-studio-and-chart',async()=>{
    await page.getByRole('button',{name:'Reset studio'}).click();
    await requireViewport(initial);
    await page.getByLabel('X metric').selectOption('ast');
    await page.getByLabel('Y metric').selectOption('pts');
   }));
   const bounds=await plot.boundingBox();
   if(!bounds||bounds.width<100||bounds.height<100)throw Error('Chart bounding box is invalid');
   operations.push(await measure('wheel-zoom',async()=>{
    await page.mouse.move(bounds.x+bounds.width*.55,bounds.y+bounds.height*.52);
    await page.mouse.wheel(0,-600);
    await requireViewport(null);
   }));
   const zoomed=await plot.getAttribute('data-viewport-range');
   operations.push(await measure('drag-pan',async()=>{
    await page.mouse.move(bounds.x+bounds.width*.5,bounds.y+bounds.height*.52);
    await page.mouse.down();
    await page.mouse.move(bounds.x+bounds.width*.68,bounds.y+bounds.height*.65,{steps:12});
    await page.mouse.up();
    await page.waitForFunction(before=>document.querySelector('.studio-chart')?.getAttribute('data-viewport-range')!==before,zoomed,{timeout:8000});
   }));
   operations.push(await measure('reset-view',async()=>{
    await page.getByRole('button',{name:'Reset view'}).click();
    await requireViewport(initial);
   }));
   operations.push(await measure('x-axis-to-reb',async()=>{
    await page.getByLabel('X metric').selectOption('reb');
    await page.waitForFunction(()=>document.querySelector('.studio-chart')?.getAttribute('aria-label')?.includes('REB'),null,{timeout:8000});
   }));
   operations.push(await measure('y-axis-to-ast',async()=>{
    await page.getByLabel('Y metric').selectOption('ast');
    await page.waitForFunction(()=>document.querySelector('.studio-chart')?.getAttribute('aria-label')?.includes('AST'),null,{timeout:8000});
   }));
   operations.push(await measure('select-underlying-player',async()=>{
    await page.locator('.studio .chart-accessible tbody button').first().click();
    await page.locator('.studio .chart-footer [role="status"]').getByText('Selected:',{exact:false}).waitFor({timeout:8000}).catch(async()=>{
     await page.waitForFunction(()=>document.querySelector('.studio .chart-footer [role="status"]')?.textContent?.includes('Selected:'),null,{timeout:8000});
    });
   }));
   const count=await page.locator('.studio .chart-accessible tbody tr').count();
   if(count<1)throw Error('No original source-backed players plotted');
   results.push({trial:n,valid:true,operations,visibleRows:count,
    finalAriaLabel:await plot.getAttribute('aria-label'),
    viewport:await plot.getAttribute('data-viewport-range')});
  }catch(error){
   errors.push({trial:n,message:String(error?.message??error)});
   results.push({trial:n,valid:false,operations});
  }
 }
}finally{
 await mkdir(folder,{recursive:true});
 if(trace)await context.tracing.stop({path:path.join(folder,'react-operation-trace.zip')}).catch(e=>errors.push({stage:'trace',message:String(e)}));
 const summary=Object.fromEntries(['reset-studio-and-chart','wheel-zoom','drag-pan','reset-view',
  'x-axis-to-reb','y-axis-to-ast','select-underlying-player'].map(operation=>{
  const values=results.flatMap(r=>r.valid?r.operations.filter(x=>x.operation===operation).map(x=>x.ms):[]);
  const sorted=values.sort((a,b)=>a-b);
  return [operation,{samples:values.length,medianMs:sorted[Math.ceil(sorted.length*.5)-1]??null,
   p95Ms:sorted[Math.ceil(sorted.length*.95)-1]??null,maxMs:sorted.at(-1)??null}];
 }));
 const report={kind:'ARCSIDE_REACT_CHART_OPERATIONS_DIAGNOSTIC_V1',
  status:errors.length||results.length!==trials?'INCOMPLETE_OR_ERROR':'REACT_OPERATIONS_OBSERVED',
  manifestSha256:manifestHash,sourceParityStatus:parity.status,
  createdAt:new Date().toISOString(),browser:browser.version(),trials,results,summary,errors,
  traceFile:trace?'react-operation-trace.zip':null,
  caveat:'Playwright chart operation times are React-only action-to-DOM-readiness probes, not matched Flutter task completion, screenshot paint, GPU presentation, or an alternative basis for passing historical Visualization guided p95. Do not overwrite the original failed evidence.'};
 await writeFile(path.join(folder,'react-operations-diagnostic.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({status:report.status,summary,errors,report:path.join(folder,'react-operations-diagnostic.json')},null,2));
 await context.close();await browser.close();
 if(report.status!=='REACT_OPERATIONS_OBSERVED')process.exitCode=1;
}
