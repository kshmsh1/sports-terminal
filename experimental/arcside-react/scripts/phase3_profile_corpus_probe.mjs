// Real-source player-profile smoke: selected published dossiers, not full career parity.
// Original Flutter profile still controls source semantics and complete feature scope.
import {chromium} from '@playwright/test';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {createHash} from 'node:crypto';
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..');
const dataRoot=path.join(root,'web/data/nba_static');
const manifestBytes=await readFile(path.join(dataRoot,'manifest.json'));
const sha=createHash('sha256').update(manifestBytes).digest('hex');
const index=JSON.parse(await readFile(path.join(dataRoot,'players/index.json'),'utf8'));
if(!Array.isArray(index))throw Error('Canonical players/index.json must be an array');
const chosen=[],invalidPaths=[];
for(const row of index){
 if(chosen.length>=3)break;
 if(!row||typeof row.player_key!=='string'||typeof row.file!=='string')continue;
 if(!/^[a-z0-9/_.-]+$/i.test(row.file)||row.file.includes('..')){
  invalidPaths.push({player:row.player_key,file:row.file});continue;
 }
 let dossier;try{dossier=JSON.parse(await readFile(path.join(dataRoot,row.file),'utf8'))}
 catch{continue}
 const regular=Array.isArray(dossier.regular_seasons)?dossier.regular_seasons.length:0;
 const playoffs=Array.isArray(dossier.playoff_seasons)?dossier.playoff_seasons.length:0;
 if(regular+playoffs===0)continue;
 const name=String(dossier.profile?.canonical_name??'').trim();
 if(!name)continue;
 chosen.push({playerKey:row.player_key,file:row.file,name,regular,playoffs});
}
const base=(process.env.ARCSIDE_REACT_URL??'http://127.0.0.1:4173').replace(/\/$/,'');
const browser=await chromium.launch({headless:true,...(process.env.ARCSIDE_BROWSER_CHANNEL?{channel:process.env.ARCSIDE_BROWSER_CHANNEL}:{})});
const checks=[],errors=[];
try{
 const context=await browser.newContext({viewport:{width:1440,height:900}});
 for(const player of chosen){
  const page=await context.newPage();
  try{
   const segment=player.regular?'regular':'playoffs';
   await page.goto(base+'/player/'+encodeURIComponent(player.playerKey)+'?season=2025-26&segment='+segment+'&basis=perGame',
    {waitUntil:'domcontentloaded',timeout:60000});
   await page.getByRole('heading',{name:player.name,exact:true}).waitFor({timeout:60000});
   const career=page.getByRole('region',{name:'Player career statistics table'});
   const count=await career.getByRole('row').count();
   const expected=1+player[segment];
   if(count!==expected)throw Error('Published '+segment+' dossier rows '+expected+' versus React '+count);
   const advancedHeading=await page.getByRole('heading',{name:'Advanced statistics'}).count();
   if(advancedHeading!==1)throw Error('Advanced table section absent');
   if(await page.getByRole('region',{name:'Player contract'}).count()!==1)
    throw Error('Original Flutter contract section absent from source-backed dossier');
   if(await page.getByRole('region',{name:'Player awards and context'}).count()!==1)
    throw Error('Original Flutter honors section absent from source-backed dossier');
   if(await page.locator('.profile-summary').count()!==1)
    throw Error('Original Flutter career context summary absent');
   checks.push({...player,segment,expectedRows:player[segment],observedRows:count-1,
    summary:'Published names and original dossier season row count, summary, contract/honors sections visible; NOT exact Flutter column/contract equivalence'});
  }catch(e){errors.push({playerKey:player.playerKey,error:String(e.message??e)})}
  finally{await page.close()}
 }
 await context.close();
}finally{await browser.close()}
const dir=path.resolve(here,'../evidence/profiles');await mkdir(dir,{recursive:true});
const status=chosen.length===3&&!errors.length&&!invalidPaths.length?'SOURCE_DOSSIER_SMOKE_PASS':'INCOMPLETE_OR_FAIL';
const report={kind:'ARCSIDE_REAL_PLAYER_PROFILE_CORPUS_PROBE_V1',manifestSha256:sha,
 status,selected:chosen.length,checks,errors,invalidPaths,
 fullPlayerProfileParity:false,contractsAndAwardsVerified:false,
 caveat:'Only published names and season row counts are asserted from an authentic NBA v5 corpus. Full cross-Dart profile column parity, historical contracts, awards, navigation and accessibility remain unverified.'};
await writeFile(path.join(dir,'profile-corpus-smoke.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({status,selected:chosen.length,verified:checks.length,errors,
 output:path.join(dir,'profile-corpus-smoke.json')},null,2));
if(status!=='SOURCE_DOSSIER_SMOKE_PASS')process.exitCode=1;
