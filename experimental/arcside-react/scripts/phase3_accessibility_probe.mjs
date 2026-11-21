// Automated accessibility smoke only. NOT WCAG certification, native Safari/VoiceOver or NVDA.
// Record actual-browser DOM and focus observations without claiming a screen reader was used.
import {chromium,firefox,webkit} from '@playwright/test';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const here=path.dirname(fileURLToPath(import.meta.url)),repo=path.resolve(here,'../../..');
const data=await readFile(path.join(repo,'web/data/nba_static/manifest.json'));
const manifestSha256=createHash('sha256').update(data).digest('hex');
const engine=process.env.ARCSIDE_A11Y_BROWSER??'chromium';
const driver={chromium,firefox,webkit}[engine];
if(!driver)throw Error('Invalid ARCSIDE_A11Y_BROWSER');
const base=(process.env.ARCSIDE_REACT_URL??'http://127.0.0.1:4173').replace(/\/$/,'');
const browser=await driver.launch({headless:true,...(engine==='chromium'&&process.env.ARCSIDE_BROWSER_CHANNEL?{channel:process.env.ARCSIDE_BROWSER_CHANNEL}:{})});
const pages=[
 {name:'Stats',route:'/stats?season=2025-26&segment=regular&basis=perGame',heading:'Player statistics'},
 {name:'Advanced Stats',route:'/advanced?season=2025-26&segment=regular&basis=perGame',heading:'Advanced player statistics'},
 {name:'Visualization Studio',route:'/visualizations?season=2025-26&segment=regular&basis=perGame',heading:'Player scatter explorer'},
 {name:'Python Lab',route:'/workspaces/python?season=2025-26&segment=regular&basis=perGame',heading:'Python Lab'},
 {name:'Excel Workspace',route:'/workspaces/sheets?season=2025-26&segment=regular&basis=perGame',heading:'Excel Workspace'}
];
const raw=[],errors=[];
try{
 const context=await browser.newContext({viewport:{width:1440,height:900}}),page=await context.newPage();
 for(const item of pages){
  const checks={};
  try{
   const res=await page.goto(base+item.route,{waitUntil:'domcontentloaded',timeout:60000});
   await page.getByRole('heading',{name:item.heading}).first().waitFor({timeout:60000});
   checks.httpStatus=res?.status()??null;
   checks.skipLink=await page.getByRole('link',{name:'Skip to content'}).count()===1;
   checks.main=await page.locator('main#main').count()===1;
   checks.focusableTheme=await page.getByRole('button',{name:/Switch to (dark|light) theme/}).count()===1;
   checks.invalidIdReferences=await page.evaluate(()=>{
    const missing=[];
    for(const node of document.querySelectorAll('[aria-labelledby],[aria-describedby]')){
     for(const att of ['aria-labelledby','aria-describedby']){
      for(const id of (node.getAttribute(att)??'').split(/\s+/).filter(Boolean))
       if(!document.getElementById(id))missing.push({element:node.tagName,att,id});
     }
    }
    return missing.slice(0,30);
   });
   checks.imageLabeling=await page.evaluate(()=>[...document.querySelectorAll('[role="img"]')].every(node=>Boolean(node.getAttribute('aria-label')||node.getAttribute('aria-labelledby'))));
   const skip=page.getByRole('link',{name:'Skip to content'});
   await skip.focus();checks.skipLinkKeyboardFocus=await skip.evaluate(x=>document.activeElement===x);
   if(item.name==='Visualization Studio'){
    checks.chartTextAlternative=await page.locator('.studio .chart-accessible table').count()===1;
    checks.resetButton=await page.getByRole('button',{name:'Reset view'}).count()===1;
   }
   if(item.name.endsWith('Lab')){
    checks.iframeTitle=await page.locator('iframe.lab-frame[title]').count()===1;
    checks.bridgeAcknowledged=await page.getByText('Context handshake: acknowledged',{exact:false}).count()===1;
   }
   raw.push({page:item.name,checks,status:Object.values(checks).every(x=>typeof x==='boolean'?x:true)&&
    checks.invalidIdReferences.length===0?'AUTOMATED_SMOKE_PASS':'CHECKS_FAILED'});
  }catch(e){errors.push({page:item.name,error:String(e.message??e)});raw.push({page:item.name,status:'ERROR'});}
 }
 await context.close();
}finally{await browser.close()}
const out=path.resolve(here,'../evidence/accessibility');
await mkdir(out,{recursive:true});
const report={kind:'ARCSIDE_PHASE3_ACCESSIBILITY_SMOKE_V1',manifestSha256,browser:engine,
 browserSource:'Playwright bundled engine or explicit Chrome channel; NOT native Safari/VoiceOver or NVDA',
 raw,errors,status:errors.length||raw.some(x=>x.status!=='AUTOMATED_SMOKE_PASS')?'INCOMPLETE_OR_FAIL':'AUTOMATED_SMOKE_PASS',
 nativeAssistiveTechnologyTested:false,wcag22AaCertified:false,
 requiredManual:['macOS Safari + VoiceOver','Windows Chrome + NVDA','keyboard-only full routes',
 'chart hover-independent point access','spreadsheet semantic grid and virtual rows','focus restoration and contrast']};
await writeFile(path.join(out,'accessibility-smoke.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({status:report.status,browser:engine,rows:raw.length,errors,
 output:path.join(out,'accessibility-smoke.json'),wcag22AaCertified:false},null,2));
if(report.status!=='AUTOMATED_SMOKE_PASS')process.exitCode=1;
