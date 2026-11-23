// Operator-led final visual/functional comparison, not an automatic GO.
import {chromium} from '@playwright/test';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {createInterface} from 'node:readline/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {finalModules,assessFinalVisual} from './phase3_final_review_manifest.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),repo=path.resolve(here,'../../..');
const root=path.resolve(here,'../evidence/final-review');
const sourceHash=createHash('sha256').update(await readFile(path.join(repo,'web/data/nba_static/manifest.json'))).digest('hex');
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const host={
 Flutter:(process.env.ARCSIDE_FLUTTER_URL??'http://127.0.0.1:8768').replace(/\/$/,''),
 React:(process.env.ARCSIDE_REACT_URL??'http://127.0.0.1:4173').replace(/\/$/,'')
};
const browser=await chromium.launch({headless:false,channel:process.env.ARCSIDE_BROWSER_CHANNEL??'chrome'});
const context=await browser.newContext({viewport:{width:1440,height:900}});
const pages={Flutter:await context.newPage(),React:await context.newPage()};
const rl=createInterface({input:process.stdin,output:process.stdout});
const checks=[],issues=[],runtimeErrors=[];
let sourceVerified=false;
try{
 for(const [app,url] of Object.entries(host)){
  const res=await context.request.get(url+'/data/nba_static/manifest.json',{timeout:30000});
  if(!res.ok()||sha(await res.body())!==sourceHash)throw Error(app+' is not serving the identical original v5 manifest');
 }
 sourceVerified=true;
 await pages.Flutter.goto(host.Flutter+'/',{waitUntil:'domcontentloaded',timeout:60000});
 await pages.React.goto(host.React+'/stats?season=2025-26&segment=regular&basis=perGame',
  {waitUntil:'domcontentloaded',timeout:60000});
 await pages.Flutter.locator('flutter-view,flt-glass-pane').first().waitFor({timeout:60000});
 console.log('Original NBA corpus verified. Both browsers are visible.');
 console.log('IMPORTANT: Flutter cannot be navigated by assumed DOM selectors. Navigate it manually in the left tab.');
 console.log('Review actual layout AND full task/functionality in BOTH tabs. Missing features are FAIL or BLOCKED, never silently waived.');
 await mkdir(path.join(root,'screenshots'),{recursive:true});
 for(const module of finalModules){
  const file=path.join(root,'final-visual-checkpoint.json');
  console.log('\n=== '+module.title+' ===\n'+module.task);
  if(module.route){
   await pages.React.goto(host.React+module.route+'?season=2025-26&segment=regular&basis=perGame',
    {waitUntil:'domcontentloaded',timeout:60000});
  }else{
   console.log('PLAYER PROFILE: follow real player profile links manually in BOTH browser tabs. Do not use a guessed player key.');
  }
  const flutter=pages.Flutter,react=pages.React;
  await flutter.bringToFront();
  console.log('Flutter tab foreground. Navigate and stage the requested source-backed task manually.');
  await rl.question('After staging Flutter and React to the same screen and inspecting both, press ENTER: ');
  const result=(await rl.question('Real side-by-side visual AND functional result [PASS / FAIL / BLOCKED]: ')).trim().toUpperCase();
  if(!['PASS','FAIL','BLOCKED'].includes(result))throw Error('Invalid review response for '+module.id);
  const details=(await rl.question('Concrete checked controls, rows, differences, or defect ID (at least 15 characters): ')).trim();
  if(details.length<15)throw Error('Specific evidence required. Review stopped at '+module.id);
  const screenshots={};for(const [app,page] of Object.entries(pages)){
   const bytes=await page.screenshot({animations:'disabled'});
   const name=module.id+'-'+app.toLowerCase()+'.png';
   await writeFile(path.join(root,'screenshots',name),bytes);
   screenshots[app]={path:'screenshots/'+name,sha256:sha(bytes),url:page.url()};
  }
  const entry={id:module.id,title:module.title,status:result,details,
   flutterUrl:screenshots.Flutter.url,reactUrl:screenshots.React.url,
   flutterScreenshotSha256:screenshots.Flutter.sha256,
   reactScreenshotSha256:screenshots.React.sha256,
   screenshots:{Flutter:screenshots.Flutter.path,React:screenshots.React.path}};
  checks.push(entry);
  if(result!=='PASS')issues.push({id:module.id,status:result,details});
  await writeFile(file,JSON.stringify({kind:'ARCSIDE_PHASE3_FINAL_REVIEW_CHECKPOINT_V1',
   sourceManifestSha256:sourceHash,checks,issues,reviewComplete:false},null,2)+'\n');
  console.log(module.title+': '+result+' · screenshots recorded; '+checks.length+'/'+finalModules.length+' reviewed');
 }
}catch(error){
 runtimeErrors.push(String(error?.message??error));
 console.error('Review interrupted without signoff:',String(error?.message??error));
}finally{
 await mkdir(root,{recursive:true});
 const assessment=assessFinalVisual({checks,
  manifestSha256:sourceHash,realManifestSha256:sourceVerified?sourceHash:null});
 const result={kind:'ARCSIDE_PHASE3_ORIGINAL_CORPUS_FINAL_VISUAL_REVIEW_V1',
  createdAt:new Date().toISOString(),source:'ACTUAL_LOCAL_V5_CORPUS',
  manifestSha256:sourceHash,physicalHumanReview:true,
  browser:browser.version(),checks,issues,runtimeErrors,
  ...assessment,
  status:runtimeErrors.length?'INCOMPLETE_OR_ERROR':assessment.status};
 await writeFile(path.join(root,'final-visual-review.json'),JSON.stringify(result,null,2)+'\n');
 const lines=['# Arcside — Phase 3 final visual/functional review','',
  'Result: **'+result.status+'**','Original NBA v5 manifest SHA-256: '+sourceHash,'',
  '| Flutter module | Result | Operator observations |',
  '| --- | --- | --- |',...checks.map(c=>'| '+c.title+' | '+c.status+' | '+c.details.replaceAll('|','/')+' |'),
  '','**Missing or failed:** '+issues.map(x=>x.id+' ('+x.status+')').join(', '),
  '','**Full migration approved:** NO. Native assistive-technology, complete CBA / profiles, security and GPU/process evidence must be assessed independently.',
  '','Screenshots in evidence/final-review/screenshots. All report files remain on the operator machine.'];
 await writeFile(path.join(root,'final-visual-review.md'),lines.join('\n')+'\n');
 console.log(JSON.stringify({status:result.status,modules:checks.length,issues,
  runtimeErrors,report:path.join(root,'final-visual-review.md')},null,2));
 rl.close();await context.close();await browser.close();
 if(result.status!=='OPERATOR_VISUAL_SAMPLE_PASS_ONLY')process.exitCode=1;
}
