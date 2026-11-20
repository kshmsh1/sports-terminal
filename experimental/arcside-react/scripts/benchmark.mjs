// Run ONLY against the local pilot (npm run dev in another terminal).
// Synthetic deterministic datasets benchmark UI responsiveness, never basketball accuracy.
// Requires: npm install, npx playwright install chromium.
import { chromium } from '@playwright/test';
import {writeFileSync,mkdirSync} from 'node:fs';
import {cpus,totalmem,platform,release,arch} from 'node:os';
const url=process.env.ARCSIDE_POC_URL??'http://127.0.0.1:5173';
const output=process.env.ARCSIDE_BENCH_DIR??'./evidence/benchmarks';
const cold=Number(process.env.ARCSIDE_COLD_RUNS??5),warm=Number(process.env.ARCSIDE_WARM_RUNS??10);
const browser=await chromium.launch({headless:true});
const results=[],meta={method:'synthetic UI load only; no Flutter comparison. Cold=fresh browser context, not cold OS process',browser:browser.version(),
 os:platform()+' '+release()+' '+arch(),cpu:cpus()[0]?.model,cores:cpus().length,ram:totalmem(),node:process.version,
 baseUrl:url,runs:{cold,warm},createdAt:new Date().toISOString()};
function rows(count,segment='regular'){
 return Array.from({length:count},(_,i)=>({
  player_id:'load-'+i,player_label:'SYNTHETIC LOAD ROW '+i,team_ids:i%2?'BOS':'CHI',
  position:'PG',games:segment==='regular'?60:5,minutes:2200,
  points:900+i/10,assists:150+i/5,rebounds:200+i/4,
  offensive_rebounds:50,defensive_rebounds:150,steals:80,blocks:30,turnovers:100,
  field_goals_made:300,field_goal_attempts:600,three_pointers_made:100,three_point_attempts:250,
  free_throws_made:200,free_throw_attempts:230,season_type:segment
 }));
}
function pct(sorted,p){return sorted[Math.min(sorted.length-1,Math.ceil(sorted.length*p)-1)]??null}
async function sample(context,kind,n,run,coldStart){
 const page=await context.newPage();
 await page.route('**/data/nba_static/**',async route=>{
  const path=new URL(route.request().url()).pathname.replace('/data/nba_static/','');
  const m={
   'manifest.json':{contract:'sports-terminal-static-nba-website-v5',static_schema_version:5,
    database_fingerprint:{SYNTHETIC_ONLY:true},season_count:1,latest_season:'2025-26'},
   'seasons.json':[{season_id:'2025-26',label:'2025-26'}],
   'seasons/2025-26/regular.json':{season_id:'2025-26',season_type:'regular',
    players:[],player_season_totals:rows(n)}
  };
  if(path in m)await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(m[path])});
  else await route.fulfill({status:404});
 });
 const target=kind==='table'?'stats':'visualizations';
 const start=performance.now();
 await page.goto(url+'/'+target+'?season=2025-26&segment=regular&basis=perGame');
 if(kind==='table')await page.getByText(n.toLocaleString()+' of '+n.toLocaleString()+' player rows').waitFor({state:'visible'});
 else {
  // New Flutter-matched Studio defaults to top 40. Explicitly select all
  // source-backed players when stress-testing 300/5k/25k scatter points.
  await page.getByRole('heading',{name:'Player scatter explorer'}).waitFor();
  await page.getByLabel('Population size').selectOption('0');
  const expected=n+' plotted from '+n+' eligible'; // Flutter-style source counter uses plain integers
  try {
   await page.getByText(expected,{exact:false}).waitFor({state:'visible',timeout:45000});
  }catch(error){
   const observed=await page.locator('.studio-chart-title .subtle').first().textContent().catch(()=>null);
   const source=await page.locator('.studio-rail [role=status]').first().textContent().catch(()=>null);
   const count=await page.getByLabel('Population size').inputValue().catch(()=>null);
   const message=await page.locator('[role=alert]').allTextContents().catch(()=>[]);
   console.error('Synthetic chart readiness failure',JSON.stringify({
    requested:n,expected,observed,source,populationValue:count,alerts:message,
    url:page.url(),error:String(error)},null,2));
   throw error;
  }
 }
 const firstVisibleMs=performance.now()-start;
 let interactionMs=null;
 if(kind==='table'){
  const scroller=page.getByRole('region',{name:'Scrollable player stats'});
  const t=performance.now();
  await scroller.evaluate(el=>{el.scrollTop=el.scrollHeight*.7;el.dispatchEvent(new Event('scroll'))});
  await page.waitForTimeout(150);
  await page.getByRole('button',{name:'Sort by AST'}).click();
  await page.waitForTimeout(150);
  interactionMs=performance.now()-t;
 }else{
  const t=performance.now();
  await page.getByRole('button',{name:'Drag pan'}).click();
  await page.getByLabel('X metric').selectOption('reb');
  await page.waitForTimeout(150);
  interactionMs=performance.now()-t;
 }
 results.push({kind,rows:n,run,cold:coldStart,firstVisibleMs,interactionMs,source:'SYNTHETIC_UI_ONLY'});
 await page.close();
}
try{
 for(const [kind,counts] of [['table',[1000,10000,50000]],['chart',[300,5000,25000]]]){
  for(const n of counts){
   const warmContext=await browser.newContext();
   for(let i=0;i<cold+warm;i++){
    const isCold=i<cold;
    // Cookies alone do not clear HTTP cache. Cold samples use fresh browser contexts.
    const context=isCold?await browser.newContext():warmContext;
    await sample(context,kind,n,i+1,isCold);
    if(isCold)await context.close();
   }
   await warmContext.close();
  }
 }
}finally{await browser.close();}
mkdirSync(output,{recursive:true});
const groups=[];
for(const [kind,counts] of [['table',[1000,10000,50000]],['chart',[300,5000,25000]]]){
 for(const n of counts){
  const vals=results.filter(r=>r.kind===kind&&r.rows===n&&!r.cold);
  const sort=key=>vals.map(v=>v[key]).filter(v=>v!==null).sort((a,b)=>a-b);
  const a=sort('firstVisibleMs'),b=sort('interactionMs');
  groups.push({kind,rows:n,medianVisibleMs:pct(a,.5),p95VisibleMs:pct(a,.95),
   medianInteractionMs:pct(b,.5),p95InteractionMs:pct(b,.95),
   warmRuns:vals.length,flutterReference:'NOT_MEASURED'});
 }
}
writeFileSync(output+'/raw.json',JSON.stringify({metadata:meta,samples:results},null,2));
writeFileSync(output+'/summary.json',JSON.stringify({metadata:meta,summary:groups},null,2));
writeFileSync(output+'/raw.csv','kind,rows,run,cold,firstVisibleMs,interactionMs,source\n'+
 results.map(r=>[r.kind,r.rows,r.run,r.cold,r.firstVisibleMs.toFixed(2),
  r.interactionMs?.toFixed(2)??'',r.source].join(',')).join('\n')+'\n');
console.log(JSON.stringify({metadata:meta,summary:groups},null,2));
