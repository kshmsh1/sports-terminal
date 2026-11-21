// Actual NBA v5 corpus smoke for newly introduced React routes.
// This checks render presence and source provenance, NOT full Flutter visual parity.
import {chromium} from '@playwright/test';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {createHash} from 'node:crypto';
const here=path.dirname(fileURLToPath(import.meta.url));
const repo=path.resolve(here,'../../..');
const root=path.join(repo,'web/data/nba_static');
const bytes=await readFile(path.join(root,'manifest.json'));
const manifestSha256=createHash('sha256').update(bytes).digest('hex');
const url=(process.env.ARCSIDE_REACT_URL??'http://127.0.0.1:4173').replace(/\/$/,'');
const seasons=JSON.parse(await readFile(path.join(root,'seasons.json'),'utf8'));
const index=Array.isArray(seasons)?seasons:[];
const gameIndex=JSON.parse(await readFile(path.join(root,'games/index.json'),'utf8').catch(error=>{if(error.code==='ENOENT')return '[]';throw error}));
const boxes=Array.isArray(gameIndex)?gameIndex:[];
const sampleSeasons=index.slice(0,12).map(s=>s.season_id).filter(Boolean);
if(!sampleSeasons.length)throw Error('No original NBA seasons in source index');
const errors=[],rows=[];
const routes=[
  {path:'/player-compare',heading:'Player Comparison',check:'Player comparison'},
  {path:'/team-compare',heading:'Team Comparison',check:'Team comparison'},
  {path:'/box-scores',heading:'Box Scores',check:'Historical box scores'},
  {path:'/financials',heading:'Financials',check:'Dated original Flutter 2026–27 financials'},
  {path:'/with-without',heading:'With / Without',check:'Published split or explicit no-source state'},
  {path:'/teams',heading:'Teams',check:'Original team index directory'},
  {path:'/games',heading:'Games',check:'Original historical game index'},
  {path:'/franchise-history',heading:'Franchise History',check:'Original Flutter historical identity plan'}
];
const browser=await chromium.launch({headless:true,...(process.env.ARCSIDE_BROWSER_CHANNEL?{channel:process.env.ARCSIDE_BROWSER_CHANNEL}:{})});
try{
 const ctx=await browser.newContext({viewport:{width:1440,height:900}});

 for(const route of routes){
  const page=await ctx.newPage();
  const failures=[];
  page.on('pageerror',e=>failures.push(String(e)));
  try{
   await page.goto(url+route.path+'?season='+sampleSeasons[0]+'&segment=regular&basis=perGame',
    {waitUntil:'domcontentloaded',timeout:60000});
   await page.getByRole('heading',{name:route.heading,exact:true}).waitFor({timeout:30000});
   if(route.path==='/box-scores'&&boxes.length){
    await page.getByRole('region',{name:'Historical games'}).waitFor({timeout:20000});
    await page.getByText(/published games/).first().waitFor({timeout:20000});
   }
   if(route.path==='/financials'){
    const response=await page.request.get(url+'/data/phase3/2026-27-team-financials.json');
    const payload=await response.json();
    if(payload.kind!=='ARCSIDE_ORIGINAL_FLUTTER_TEAM_FINANCIALS_2026_27_V1'||payload.teams?.length!==30)
     throw Error('Original financial source snapshot did not validate');
    await page.getByRole('button',{name:'ATL',exact:true}).waitFor({timeout:20000});
   }
   if(route.path==='/teams'){
    await page.getByRole('region',{name:'NBA teams directory'}).waitFor({timeout:20000});
    const teams=await page.request.get(url+'/data/nba_static/teams/index.json');
    const teamIndex=await teams.json();
    const first=teamIndex.find(item=>typeof item.team_key==='string'&&typeof item.file==='string');
    if(!first)throw Error('Original team index has no usable source-backed dossier');
    const detailPage=await ctx.newPage();
    try{
     await detailPage.goto(url+'/team/'+encodeURIComponent(first.team_key)+'?season='+sampleSeasons[0]+'&segment=regular&basis=perGame');
     await detailPage.getByRole('region',{name:'Team detail'}).waitFor({timeout:20000});
     await detailPage.getByRole('heading',{level:2}).first().waitFor({timeout:20000});
     const history=detailPage.getByRole('region',{name:'Team season history'});
     await history.waitFor({timeout:20000});
     // Historical identities may have no regular-season rows. Require either
     // actual source rows or the UI's explicit missing-source state.
     const rowCount=await history.locator('tbody tr').count();
     const noHistory=await history.getByText('No published regular history rows for this team.').count();
     if(!rowCount&&!noHistory)throw Error('Team dossier has neither published history nor an explicit unavailable state');
     if(await detailPage.getByRole('alert').count())throw Error('Source-backed team profile reported an error');
    }finally{await detailPage.close()}
   }
   if(route.path==='/games'&&boxes.length){
    await page.getByRole('region',{name:'Published games'}).waitFor({timeout:20000});
   }
   if(route.path==='/franchise-history'){
    await page.getByRole('region',{name:'Franchise history build plan'}).waitFor({timeout:20000});
   }
   if(route.path==='/with-without')
    await page.getByRole('heading',{name:'With / Without'}).waitFor({timeout:20000});
   if(failures.length)throw Error('Runtime exceptions: '+failures.join('; '));
   rows.push({...route,status:'SOURCE_ROUTE_SMOKE_PASS'});
  }catch(e){
   const detail=String(e.message??e);errors.push({route:route.path,error:detail});
   rows.push({...route,status:'FAIL',error:detail});
  }finally{await page.close()}
 }
 await ctx.close();
}finally{await browser.close()}
const status=!errors.length&&rows.length===routes.length?'SOURCE_ROUTE_SMOKE_PASS':'INCOMPLETE_OR_FAIL';
const report={kind:'ARCSIDE_PHASE3_NEW_MODULES_REAL_CORPUS_PROBE_V1',manifestSha256,
 status,rows,errors,sourceSeasons:sampleSeasons.length,originalGameIndexRows:boxes.length,
 sourceDataValuesMatchedToFlutter:false,fullSourceVisualParity:false,
 caveat:'Read-only route smoke only; synthetic browser fixture and actual Flutter semantic parity are separately assessed.'};
const dir=path.join(here,'../evidence/modules');
await mkdir(dir,{recursive:true});
await writeFile(path.join(dir,'module-corpus-smoke.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({status,routes:rows.length,errors,output:path.join(dir,'module-corpus-smoke.json')},null,2));
if(status!=='SOURCE_ROUTE_SMOKE_PASS')process.exitCode=1;
