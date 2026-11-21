// Isolated-context, read-only-to-real-user-data Labs import/export and bridge checks.
// Browser contexts are fresh and disposable. Do NOT connect local native services.
import {chromium} from '@playwright/test';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const here=path.dirname(fileURLToPath(import.meta.url)),repo=path.resolve(here,'../../..');
const manifestBytes=await readFile(path.join(repo,'web/data/nba_static/manifest.json'));
const manifestSha256=createHash('sha256').update(manifestBytes).digest('hex');
const base=(process.env.ARCSIDE_REACT_URL??'http://127.0.0.1:4173').replace(/\/$/,'');
const browser=await chromium.launch({headless:true,...(process.env.ARCSIDE_BROWSER_CHANNEL?{channel:process.env.ARCSIDE_BROWSER_CHANNEL}:{})});
const evidence=[],errors=[];
const track=async(name,fn)=>{
 try{const detail=await fn();evidence.push({name,status:'PASS',detail})}
 catch(e){errors.push({name,error:String(e.message??e)});evidence.push({name,status:'FAIL',error:String(e.message??e)})}
};
const context=await browser.newContext({acceptDownloads:true,viewport:{width:1440,height:900}});
const page=await context.newPage();
try{
 await track('Python isolated project import-export byte-for-byte',async()=>{
  await page.goto(base+'/workspaces/python?season=2025-26&segment=regular&basis=perGame');
  await page.getByText('Context handshake: acknowledged',{exact:false}).waitFor({timeout:60000});
  const frame=page.frameLocator('iframe[title="Python Lab"]');
  await frame.locator('#importFile').waitFor();
  const content='print("ARCSIDE_PHASE3_IMPORT_EXPORT_INTEGRITY")\n';
  await frame.locator('#picker').setInputFiles({name:'phase3_integrity.py',mimeType:'text/x-python',buffer:Buffer.from(content)});
  await frame.locator('#activePath').filter({hasText:'phase3_integrity.py'}).waitFor({timeout:20000});
  const [download]=await Promise.all([page.waitForEvent('download'),frame.locator('#exportFile').click()]);
  const pathToFile=await download.path();
  if(!pathToFile)throw Error('Export did not produce a local browser download.');
  const actual=await readFile(pathToFile,'utf8');
  if(actual!==content)throw Error('Python exported content differs from imported byte-for-byte fixture.');
  const [project]=await Promise.all([page.waitForEvent('download'),frame.locator('#exportProject').click()]);
  const projectBytes=await readFile(await project.path(),'utf8');
  const json=JSON.parse(projectBytes);
  if(json.version!==1||json.project?.files?.['phase3_integrity.py']!==content)
   throw Error('Python project JSON export lost the imported file.');
  return {download:download.suggestedFilename(),sourceSha256:createHash('sha256').update(content).digest('hex'),
   projectFilePresent:true,isolatedBrowserContext:true};
 });
 await track('Sheets isolated workbook JSON import-export roundtrip',async()=>{
  await page.goto(base+'/workspaces/sheets?season=2025-26&segment=regular&basis=perGame');
  await page.getByText('Context handshake: acknowledged',{exact:false}).waitFor({timeout:60000});
  const frame=page.frameLocator('iframe[title="Excel Workspace"]');
  await frame.locator('#workbookName').waitFor();
  const [first]=await Promise.all([
   page.waitForEvent('download'),frame.locator('[data-action="exportWorkbook"]').click()]);
  const snapshot=await readFile(await first.path(),'utf8');
  const parsed=JSON.parse(snapshot);
  if(!parsed.workbook||!parsed.name)throw Error('Initial original workbook JSON is missing expected data.');
  // Import the exact output into the same throwaway context; never use owner's browser profile.
  await frame.locator('#filePicker').setInputFiles({name:'phase3-roundtrip.json',
   mimeType:'application/json',buffer:Buffer.from(snapshot)});
  await frame.locator('#saveStatus').waitFor({timeout:20000});
  await page.waitForTimeout(250); // allow import promise to settle before requesting the roundtrip export
  const [second]=await Promise.all([
   page.waitForEvent('download'),frame.locator('[data-action="exportWorkbook"]').click()]);
  const actual=JSON.parse(await readFile(await second.path(),'utf8'));
  if(JSON.stringify(actual.workbook)!==JSON.stringify(parsed.workbook))
   throw Error('Original Sheets JSON workbook changed across export-import-export.');
  return {workbookSha256:createHash('sha256').update(JSON.stringify(parsed.workbook)).digest('hex'),
   isolatedBrowserContext:true};
 });
 await track('Lab same-origin messaging excludes secrets',async()=>{
  await page.goto(base+'/workspaces/python?season=2025-26&segment=regular&basis=perGame');
  await page.getByText('Context handshake: acknowledged',{exact:false}).waitFor({timeout:60000});
  const captured=await page.evaluate(async()=>{
   const iframe=document.querySelector('iframe[title="Python Lab"]');
   const win=iframe?.contentWindow;
   if(!win)throw Error('Lab iframe unavailable');
   let ack=0;
   const onMessage=e=>{if(e.source===win&&e.data?.type==='arcside:context:ack')ack++};
   window.addEventListener('message',onMessage);
   win.postMessage({type:'arcside:context',version:1,season:'2025-26',segment:'regular',token:'FAKE_SENTINEL_DO_NOT_RELAY'},location.origin);
   await new Promise(resolve=>setTimeout(resolve,120));
   window.removeEventListener('message',onMessage);
   return {ack};
  });
  // Original Lab bridge rejects extra fields, including token-like payloads.
  // This is a schema smoke, not an adversarial-origin authentication audit.
  if(captured.ack!==0)throw Error('Lab incorrectly acknowledged a context payload carrying a forbidden token field.');
  return {...captured,strictExtraFieldsRejected:true,
   scope:'same-origin schema smoke; NOT adversarial-origin, authentication or privilege audit'};
 });
}finally{
 await context.close().catch(()=>{});await browser.close();
}
const dir=path.resolve(here,'../evidence/labs');await mkdir(dir,{recursive:true});
const result={kind:'ARCSIDE_PHASE3_LABS_LOCAL_INTEGRITY_V1',manifestSha256,
 evidence,errors,status:errors.length?'INCOMPLETE_OR_FAIL':'BROWSER_ROUNDTRIPS_PASS',
 originalLabsUnmodified:true,localServiceSecurityCertified:false,authenticatedCollaborationCertified:false,
 note:'Runs in a disposable browser context; does not connect Python native companion or Sheets collaboration. Does not use the owner\'s workbook or project. Native privilege, cross-origin service CSRF and token leakage require separate controlled live checks.'};
await writeFile(path.join(dir,'lab-integrity.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({status:result.status,evidence:evidence.map(x=>({name:x.name,status:x.status})),
 output:path.join(dir,'lab-integrity.json'),localServiceSecurityCertified:false},null,2));
if(errors.length)process.exitCode=1;
