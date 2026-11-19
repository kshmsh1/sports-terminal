import type { JsonRow, RateBasis, SeasonSnapshot } from './data';

export type MetricKey = 'gp'|'min'|'age'|'pts'|'ast'|'reb'|'oreb'|'dreb'|'stl'|'blk'|'tov'|'pf'|
 'fgm'|'fga'|'fg_pct'|'two_pm'|'two_pa'|'two_pct'|'three_pm'|'three_pa'|'three_pct'|'ftm'|'fta'|
 'ft_pct'|'ts_pct'|'efg_pct'|'points_per_shot'|'ast_tov'|'three_rate'|'ft_rate'|'plus_minus'|'bpm'|
 'game_score_proxy'|'stocks'|'defense_events'|'possessions_proxy'|'scoring_load';
export interface Row { id: string; player: string; team: string; position: string; raw: JsonRow; estimated: boolean;
  values: Record<MetricKey, number | null>; percentiles: Partial<Record<MetricKey, number>>; }
export interface Metric { key: MetricKey; label: string; format?: 'int'|'percent'|'signed'; higher?: boolean }
export const metrics: Metric[] = [
  ['gp','GP','int'],['min','MIN'],['age','AGE'],['pts','PTS'],['ast','AST'],['reb','REB'],
  ['oreb','OREB'],['dreb','DREB'],['stl','STL'],['blk','BLK'],['tov','TOV'],['pf','PF'],
  ['fgm','FGM'],['fga','FGA'],['fg_pct','FG%','percent'],['two_pm','2PM'],['two_pa','2PA'],
  ['two_pct','2P%','percent'],['three_pm','3PM'],['three_pa','3PA'],['three_pct','3P%','percent'],
  ['ftm','FTM'],['fta','FTA'],['ft_pct','FT%','percent'],['ts_pct','TS%','percent'],
  ['efg_pct','eFG%','percent'],['points_per_shot','PTS/SA'],['ast_tov','AST/TOV'],
  ['three_rate','3P Rate','percent'],['ft_rate','FT Rate','percent'],['plus_minus','+/-','signed'],
  ['bpm','BPM','signed'],['game_score_proxy','PROD'],['stocks','STOCKS'],
  ['defense_events','DEF EVT'],['possessions_proxy','POSS*'],['scoring_load','LOAD*','percent']
].map(([key,label,format]) => ({key: key as MetricKey, label: label!, format: format as Metric['format'],
  higher: !['tov','pf'].includes(key!)}));
export const overviewKeys: MetricKey[]=['gp','min','age','pts','ast','reb','tov','ts_pct','plus_minus','bpm'];
export const advancedKeys: MetricKey[]=['gp','min','possessions_proxy','scoring_load','ts_pct','efg_pct','ast_tov','bpm','game_score_proxy'];
export const scatterKeys: MetricKey[]=['pts','ast','reb','stl','blk','ts_pct','efg_pct','bpm','plus_minus','game_score_proxy','stocks'];
export const bases: {value:RateBasis;label:string}[] = [
 {value:'perGame',label:'Per Game'},{value:'per36',label:'Per 36'},{value:'per48',label:'Per 48'},
 {value:'per75',label:'Per 75 Poss'},{value:'per100',label:'Per 100 Poss'},{value:'totals',label:'Totals'}
];

function value(obj: JsonRow, keys: string[]): unknown {
  for(const key of keys) { const x = obj[key]; if (x !== null && x !== undefined && String(x).trim() !== '') return x; }
  return null;
}
function number(x: unknown): number | null {
  if(typeof x === 'boolean' || x === null || x === undefined || x === '') return null;
  const n = typeof x === 'number' ? x : Number(String(x).replaceAll(',','').replaceAll('%',''));
  return Number.isFinite(n) ? n : null;
}
function firstNumber(obj: JsonRow, ...keys: string[]): number|null {return number(value(obj,keys));}
function total(raw:JsonRow, gp:number|null, totals:string[], perGame:string[]):number|null {
 const direct=firstNumber(raw,...totals);
 if(direct!==null)return direct;
 const per=firstNumber(raw,...perGame);
 return per!==null && gp!==null ? per*gp : null;
}
function ratio(a:number|null,b:number|null):number|null {
 return a===null||b===null||b<=0?null:a/b;
}
function ratioOrSource(raw:JsonRow,a:number|null,b:number|null,keys:string[]):number|null {
 const provided=firstNumber(raw,...keys);
 if(provided!==null)return provided>1?provided/100:provided;
 return ratio(a,b);
}
function scaleValue(x:number|null,factor:number|null):number|null {
 return x===null||factor===null ? null : x*factor;
}
function position(raw:JsonRow,profile:JsonRow):string {
 const original=String(value(raw,['positions','position','pos','primary_position']) ??
     value(profile,['primary_position','positions','position','pos','position_abbrev']) ?? '').trim();
 const normalized=original.toUpperCase().replaceAll(' ','');
 for(const p of ['PG','SG','SF','PF','C']) if(normalized===p||normalized.startsWith(p+'-')||normalized.endsWith('-'+p))return p;
 if(normalized.includes('GUARD'))return 'G';
 if(normalized.includes('FORWARD'))return 'F';
 if(normalized.includes('CENTER'))return 'C';
 return original || '—';
}
export function normalize(raw:JsonRow, profile:JsonRow, basis:RateBasis):Row {
 const gp=firstNumber(raw,'games','gp','g'), min=total(raw,gp,['minutes','mp'],['minutes_per_game','mpg']);
 const pts=total(raw,gp,['points','pts'],['points_per_game','ppg']);
 const ast=total(raw,gp,['assists','ast'],['assists_per_game','apg']);
 const reb=total(raw,gp,['rebounds','trb','reb'],['rebounds_per_game','rpg']);
 const oreb=total(raw,gp,['offensive_rebounds','orb','oreb'],['offensive_rebounds_per_game','oreb_per_game']);
 const dreb=total(raw,gp,['defensive_rebounds','drb','dreb'],['defensive_rebounds_per_game','dreb_per_game']);
 const stl=total(raw,gp,['steals','stl'],['steals_per_game','spg']);
 const blk=total(raw,gp,['blocks','blk'],['blocks_per_game','bpg']);
 const tov=total(raw,gp,['turnovers','tov'],['turnovers_per_game','tov_per_game']);
 const pf=total(raw,gp,['personal_fouls','pf'],['personal_fouls_per_game','pf_per_game']);
 const pm=total(raw,gp,['plus_minus'],['plus_minus_per_game']);
 const fgm=total(raw,gp,['field_goals_made','fg','fgm'],['field_goals_made_per_game','fgm_per_game']);
 const fga=total(raw,gp,['field_goal_attempts','fga'],['field_goal_attempts_per_game','fga_per_game']);
 const threePm=total(raw,gp,['three_pointers_made','fg3','three_pm'],['three_pointers_made_per_game','three_pm_per_game']);
 const threePa=total(raw,gp,['three_point_attempts','fg3a','three_pa'],['three_point_attempts_per_game','three_pa_per_game']);
 const ftm=total(raw,gp,['free_throws_made','ft','ftm'],['free_throws_made_per_game','ftm_per_game']);
 const fta=total(raw,gp,['free_throw_attempts','fta'],['free_throw_attempts_per_game','fta_per_game']);
 const directPoss=firstNumber(raw,'possessions','poss','estimated_possessions');
 let estimated=directPoss===null;
 let possessions=directPoss;
 if(possessions===null && fga!==null&&fta!==null&&oreb!==null&&tov!==null)
   possessions=Math.max(0,fga+.44*fta-oreb+tov);
 if((possessions===null||possessions<=0)&&min!==null&&min>0){possessions=min*2.05;estimated=true;}
 const factor=basis==='totals'?1:basis==='perGame'?(gp!==null&&gp>0?1/gp:null):
   basis==='per36'?(min!==null&&min>0?36/min:null):
   basis==='per48'?(min!==null&&min>0?48/min:null):
   basis==='per75'?(possessions!==null&&possessions>0?75/possessions:null):
   possessions!==null&&possessions>0?100/possessions:null;
 const scaled=(n:number|null)=>scaleValue(n,factor);
 const twoPm=fgm===null||threePm===null?null:Math.max(0,fgm-threePm);
 const twoPa=fga===null||threePa===null?null:Math.max(0,fga-threePa);
 const shooting=fga!==null&&fta!==null?fga+.44*fta:null;
 const fgPct=ratioOrSource(raw,fgm,fga,['fg_pct','field_goal_percentage','field_goal_pct','avg_fg_pct']);
 const threePct=ratioOrSource(raw,threePm,threePa,['three_point_percentage','three_point_pct','fg3_pct','avg_fg3_pct']);
 const ftPct=ratioOrSource(raw,ftm,fta,['free_throw_percentage','free_throw_pct','ft_pct','avg_ft_pct']);
 const tsPct=ratioOrSource(raw,pts,shooting!==null?shooting*2:null,['true_shooting_percentage','ts_pct','avg_ts_pct']);
 const efgPct=ratioOrSource(raw,fgm!==null&&threePm!==null?fgm+.5*threePm:null,fga,
   ['effective_field_goal_percentage','efg_pct']);
 const id=String(value(raw,['player_id','id','slug'])??'');
 const values:Row['values']={
  gp, min:scaled(min),age:firstNumber(raw,'age')??firstNumber(profile,'age'),
  pts:scaled(pts),ast:scaled(ast),reb:scaled(reb),oreb:scaled(oreb),dreb:scaled(dreb),
  stl:scaled(stl),blk:scaled(blk),tov:scaled(tov),pf:scaled(pf),fgm:scaled(fgm),fga:scaled(fga),
  fg_pct:fgPct,two_pm:scaled(twoPm),two_pa:scaled(twoPa),two_pct:ratio(twoPm,twoPa),
  three_pm:scaled(threePm),three_pa:scaled(threePa),three_pct:threePct,ftm:scaled(ftm),
  fta:scaled(fta),ft_pct:ftPct,ts_pct:tsPct,efg_pct:efgPct,points_per_shot:ratio(pts,shooting),
  ast_tov:tov!==null && tov>0 && ast!==null ? ast/tov : (ast!==null&&ast>0&&tov===0?ast:null),
  three_rate:ratio(threePa,fga),ft_rate:ratio(fta,fga),plus_minus:scaled(pm),
  bpm:firstNumber(raw,'avg_bpm','bpm','box_plus_minus'),
  game_score_proxy:[pts,reb,ast,stl,blk,tov].every(x=>x!==null)?
    scaled(pts!+.7*reb!+.7*ast!+stl!+blk!-.7*tov!):null,
  stocks:stl!==null&&blk!==null?scaled(stl+blk):null,
  defense_events:stl!==null&&blk!==null&&dreb!==null?scaled(stl+blk+.35*dreb):null,
  possessions_proxy:scaled(possessions),scoring_load:ratio(shooting,possessions)
 };
 return {id, player:String(value(raw,['player_label','player_name','player','name'])??'—'),
  team:String(value(raw,['team_ids','team_id','team'])??'—'),position:position(raw,profile),
  values, raw, percentiles:{},estimated};
}
export function buildRows(snapshot:SeasonSnapshot,basis:RateBasis):Row[] {
 const profiles=new Map(snapshot.players.map(p=>[String(value(p,['player_id','id'])??''),p]));
 const rows=snapshot.player_season_totals.filter(raw=>{
  const segment=String(value(raw,['season_type','seasonType','segment'])??snapshot.season_type).toLowerCase();
  return snapshot.season_type==='playoffs'?segment.includes('playoff')||segment.includes('postseason'):
    !segment.includes('playoff')&&!segment.includes('postseason');
 }).map(raw=>normalize(raw,profiles.get(String(value(raw,['player_id','id'])??''))??{},basis));
 return attachPercentiles(rows);
}
export function stintRows(parent:Row,basis:RateBasis):Row[] {
 const raw=parent.raw.team_stints;
 if(!Array.isArray(raw))return [];
 const seen=new Set<string>(), result:Row[]=[];
 for(const item of raw){
  if(!item||typeof item!=='object'||Array.isArray(item))continue;
  const record=item as JsonRow, id=String(value(record,['player_id','id'])??'');
  const team=String(value(record,['team_ids','team_abbreviation'])??'');
  if(id!==parent.id||!(/^[A-Za-z]{2,4}$/.test(team))||seen.has(team.toUpperCase()))continue;
  seen.add(team.toUpperCase());
  const row=normalize(record,parent.raw,basis);
  if(row.team===team)result.push(row);
 }
 return result.length>=2?result:[];
}
export function attachPercentiles(rows:Row[]):Row[]{
 const ranks=new Map(rows.map(r=>[r.id,{} as Partial<Record<MetricKey,number>>]));
 for(const metric of metrics){
  const candidates=rows.filter(r=>r.values[metric.key]!==null)
   .sort((a,b)=>(a.values[metric.key]??0)-(b.values[metric.key]??0));
  candidates.forEach((r,i)=>{const pct=candidates.length===1?100:100*i/(candidates.length-1);
   const rank=ranks.get(r.id);if(rank)rank[metric.key]=metric.higher===false?100-pct:pct;});
 }
 return rows.map(r=>({...r,percentiles:ranks.get(r.id)??{}}));
}
export function sortRows(rows:Row[],key:MetricKey,descending=true):Row[]{
 return [...rows].sort((a,b)=>{
  const va=a.values[key],vb=b.values[key];
  if(va===null&&vb===null)return a.player.localeCompare(b.player)||a.id.localeCompare(b.id);
  if(va===null)return 1;
  if(vb===null)return -1;
  return (descending?vb-va:va-vb)||a.player.localeCompare(b.player)||a.id.localeCompare(b.id);
 });
}
export function formatMetric(key:MetricKey, v:number|null):string{
 if(v===null || !Number.isFinite(v))return '—';
 const format=metrics.find(m=>m.key===key)?.format;
 if(format==='int')return String(Math.round(v));
 if(format==='percent')return (v*100).toFixed(1)+'%';
 if(format==='signed')return (v>=0?'+':'')+v.toFixed(1);
 // Exact source Dart engine display contract uses two decimals for ratios.
 return v.toFixed(key==='points_per_shot'||key==='ast_tov'?2:1);
}
