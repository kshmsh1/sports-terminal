import type {Page} from '@playwright/test';

// Explicitly synthetic E2E fixtures. They exist ONLY in Playwright route interception;
// the launched Arcside app never falls back to mock NBA numbers.
export function makeRows(count:number){
 return Array.from({length:count},(_,i)=>({
  player_id:'synthetic-'+i,player_label:'Synthetic Player '+i,team_ids:i%2?'BOS':'CHI',
  position:i%2?'PG':'SF',games:65,minutes:2200,
  points:900+i,assists:180+i%30,rebounds:300+i%25,offensive_rebounds:60,
  defensive_rebounds:240,steals:80,blocks:40,turnovers:90,
  field_goals_made:350,field_goal_attempts:650,three_pointers_made:110,three_point_attempts:275,
  free_throws_made:90,free_throw_attempts:100,season_type:'regular'
 }));
}
export async function mockStatic(page:Page,count=150){
 await page.route('**/data/nba_static/**',async route=>{
  const path=new URL(route.request().url()).pathname.replace('/data/nba_static/','');
  const bodies:Record<string,unknown>={
   'manifest.json':{contract:'sports-terminal-static-nba-website-v5',static_schema_version:5,
    database_fingerprint:{TEST_ONLY:true},latest_season:'2025-26',season_count:1},
   'seasons.json':[{season_id:'2025-26',label:'2025-26',start_year:2025}],
   'seasons/2025-26/regular.json':{season_id:'2025-26',season_type:'regular',
    players:[],player_season_totals:makeRows(count)},
   'seasons/2025-26/playoffs.json':{season_id:'2025-26',season_type:'playoffs',
    players:[],player_season_totals:[{...makeRows(1)[0],season_type:'playoffs',games:6}]},
   'players/index.json':[]
  };
  if(path in bodies)await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(bodies[path])});
  else await route.fulfill({status:404,body:'Synthetic fixture not found'});
 });
}
