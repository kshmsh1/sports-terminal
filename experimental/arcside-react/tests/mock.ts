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
    players:[],player_season_totals:makeRows(count),
    team_records:[{team_id:'CHI',team_name:'Chicago',team_abbreviation:'CHI',games:4,wins:3,losses:1,points:420,opponent_points:390},
      {team_id:'BOS',team_name:'Boston',team_abbreviation:'BOS',games:4,wins:2,losses:2,points:400,opponent_points:405}],
    teams:[{team_id:'CHI',team_name:'Chicago',abbreviation:'CHI'},{team_id:'BOS',team_name:'Boston',abbreviation:'BOS'}]},
   'seasons/2025-26/playoffs.json':{season_id:'2025-26',season_type:'playoffs',
    players:[],player_season_totals:[{...makeRows(1)[0],season_type:'playoffs',games:6}]},
   'dashboard/2025-26.json':{season_id:'2025-26',leaders:{points:[{rank:1,player_id:'synthetic-0',player_name:'Synthetic Player 0',value:25}]},team_leaders:{points:[{rank:1,team_key:'team-chi',team_name:'Chicago',value:105}]},teams:[{team_key:'team-chi',team_name:'Chicago',abbreviation:'CHI'}],recent_games:[]},
   'games/index.json':[
    {game_key:'synthetic-game-001',season_id:'2025-26',season_type:'regular',
     game_date:'2025-12-01',away_team_abbreviation:'BOS',home_team_abbreviation:'CHI',
     away_score:100,home_score:110,box_score_available:true,file:'games/synthetic-game-001.json',pbp_file:'games/synthetic-game-001-pbp.json'}],
   'games/synthetic-game-001.json':{
    game_key:'synthetic-game-001',
    player_box_scores:[{player_id:'synthetic-0',player_name:'Synthetic Player 0',
     team_abbreviation:'CHI',minutes:30,pts:25,reb:6,ast:5,stl:1,blk:1,tov:2,
     fgm:9,fga:18,three_pm:3,three_pa:8,ftm:4,fta:5}],
    team_box_scores:[{team_abbreviation:'CHI',pts:110,reb:45,ast:22}]},
   'lineups/2025-26/regular/with_without.json':{source:'SYNTHETIC_PLAYWRIGHT_ONLY',
    rows:[{team:'CHI',player_id:'synthetic-0',teammate_id:'synthetic-2',
     minutes_with:100,minutes_without:80,
     with:{pts:24,ast:5},without:{pts:20,ast:4}}]},
   'teams/index.json':[{team_key:'team-chi',abbreviation:'CHI',canonical_name:'Chicago',
    franchise_key:'franchise-chi',city:'Chicago',conference:'Eastern',division:'Central',
    file:'teams/team-chi.json'},{team_key:'team-bos',abbreviation:'BOS',canonical_name:'Boston',
    franchise_key:'franchise-bos',file:'teams/team-bos.json'}],
   'teams/team-chi.json':{profile:{canonical_name:'Chicago',abbreviation:'CHI'},
    franchise:{canonical_name:'Chicago Franchise'},
    seasons:[{season_id:'2025-26',season_type:'regular',games:82,wins:45,losses:37},
      {season_id:'2025-26',season_type:'playoffs',games:6,wins:2,losses:4}],
    notable_players:[{player_key:'synthetic-0',player_name:'Synthetic Player 0'}],
    recent_games:[{game_key:'synthetic-game-001',game_date:'2025-12-01',away_team_abbreviation:'BOS',home_team_abbreviation:'CHI'}],
    injuries_2026_27:[],transactions_2026_27:[]},
   'games/synthetic-game-001-pbp.json':{rows:[{period:1,clock:'10:10',description:'Synthetic opening shot'}]},
   'players/index.json':[{canonical_name:'Synthetic Player 0',player_key:'synthetic-0',player_id:'synthetic-0',file:'players/synthetic-0.json'}],
   'players/synthetic-0.json':{profile:{canonical_name:'Synthetic Player 0',positions:'SF',
     birth_date:'2000-01-01',draft_year:2018},
    regular_seasons:[
     {season_id:'2025-26',team_abbreviation:'CHI',positions:'SF',games:65,minutes:2100,min:2100,
      pts:1300,reb:325,ast:260,fg_pct:0.5,ts_pct:0.58,bpm:2.2},
     {season_id:'2024-25',team_abbreviation:'BOS',positions:'SF',games:60,minutes:1800,
      pts:1080,reb:240,ast:180,fg_pct:0.45,ts_pct:0.55,bpm:1.7}],
    playoff_seasons:[{season_id:'2025-26',team_abbreviation:'CHI',positions:'SF',
     games:6,minutes:180,pts:120,reb:30,ast:24,fg_pct:0.52,ts_pct:0.6,bpm:3.1}],
    awards:[],all_star:[],draft:[]}
  };
  if(path in bodies)await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(bodies[path])});
  else await route.fulfill({status:404,body:'Synthetic fixture not found'});
 });
}
