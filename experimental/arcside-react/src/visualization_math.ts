// Phase 3 Visualization Studio -- source-based deterministic selection and OLS.
// These functions never create fallback NBA values for missing metrics.
import type {MetricKey,Row} from './engine';
import type {RateBasis} from './data';

export type ChartKind='scatter'|'bubble'|'bar'|'histogram'|'box'|'cumulative'|'radar';
export type ColorBy='Team'|'Position'|'None';
export type LabelDensity='Selective'|'More'|'All';
export const scatterPopulationSizes=[0,10,20,30,40,60,100] as const;
export const visualizationKinds:{value:ChartKind;label:string}[]=[
 {value:'scatter',label:'Scatter'},{value:'bubble',label:'Bubble'},
 {value:'bar',label:'Player ranking'},{value:'histogram',label:'Distribution'},
 {value:'box',label:'Position box plot'},{value:'cumulative',label:'Cumulative percentile'},
 {value:'radar',label:'Player profile'}];
export const valueFor=(row:Row,key:MetricKey)=>row.values[key];
// Mirror Flutter Visualization Studio's _studioHasMetric. A computed rate
// without a source-supported numerator is not a valid plotted observation.
const sourceFields:Partial<Record<MetricKey,string[]>>={
 min:['minutes','mp','minutes_per_game','mpg'],
 pts:['points','pts','points_per_game','ppg'],
 reb:['rebounds','trb','reb','rebounds_per_game','rpg'],
 ast:['assists','ast','assists_per_game','apg'],
 stl:['steals','stl','steals_per_game','spg'],
 blk:['blocks','blk','blocks_per_game','bpg'],
 tov:['turnovers','tov','turnovers_per_game'],
 fg_pct:['field_goals_made','fg','fgm','fg_pct','field_goal_percentage'],
 three_pm:['three_pointers_made','fg3','three_pm'],
 three_pa:['three_point_attempts','fg3a','three_pa'],
 three_pct:['three_pointers_made','three_point_percentage','fg3_pct'],
 ft_pct:['free_throws_made','free_throw_percentage','ft_pct'],
 plus_minus:['plus_minus'],bpm:['bpm','avg_bpm','box_plus_minus']
};
export function sourceHasMetric(row:Row,key:MetricKey,basis:RateBasis='perGame'):boolean{
 const v=row.values[key];
 if(v===null||!Number.isFinite(v))return false;
 if(key==='gp')return true;
 const raw=row.raw;
 const minute=raw.minutes??raw.mp??raw.minutes_per_game??raw.mpg;
 const n=minute===null||minute===undefined?null:Number(minute);
 if((basis==='per36'||basis==='per48')&&(n===null||!Number.isFinite(n)||n<=0))return false;
 if((basis==='per75'||basis==='per100')&&!(n!==null&&Number.isFinite(n)&&n>0)&&
  raw.field_goal_attempts==null&&raw.fga==null)return false;
 const aliases=sourceFields[key];
 if(aliases&&!aliases.some(a=>raw[a]!==undefined&&raw[a]!==null))return false;
 if(key==='ts_pct'||key==='efg_pct'){
  if(!((raw.points!=null&&raw.field_goal_attempts!=null)||
   raw.true_shooting_percentage!=null||raw.effective_field_goal_percentage!=null))return false;
 }
 if(key==='game_score_proxy'&&
  (raw.points==null||raw.rebounds==null||raw.assists==null))return false;
 return true;
}

export function rowTeams(row:Row):string[]{
 const direct=row.team.split(/[,/\s]+/).filter(v=>/^[A-Z]{2,4}$/.test(v));
 const fromStints=Array.isArray(row.raw.team_stints)?
  row.raw.team_stints.flatMap(stint=>{
   if(!stint||typeof stint!=='object'||Array.isArray(stint))return [];
   const t=(stint as Record<string,unknown>).team_ids??(stint as Record<string,unknown>).team_abbreviation;
   return typeof t==='string'?t.split(/[,/\s]+/).filter(v=>/^[A-Z]{2,4}$/.test(v)):[];
  }):[];
 return [...new Set([...direct,...fromStints])];
}
export function selectVisualizationRows(rows:Row[],opts:{
 x:MetricKey;y:MetricKey;minGames:number;population:number;filter:string;
 kind:ChartKind;size?:MetricKey;rankingSize?:number;basis?:RateBasis;
}){
 const matching=rows.filter(row=>{
  if((row.values.gp??0)<opts.minGames)return false;
  if(opts.filter.startsWith('team:')&&!rowTeams(row).includes(opts.filter.slice(5)))return false;
  if(opts.filter.startsWith('player:')&&row.id!==opts.filter.slice(7))return false;
  return true;
 });
 const eligible=matching.filter(row=>{
  if(opts.kind==='radar')return (['pts','reb','ast','stl','blk','ts_pct'] as MetricKey[])
   .some(key=>sourceHasMetric(row,key,opts.basis));
  if(!sourceHasMetric(row,opts.y,opts.basis))return false;
  if(['scatter','bubble'].includes(opts.kind)&&!sourceHasMetric(row,opts.x,opts.basis))return false;
  if(opts.kind==='bubble'&&!sourceHasMetric(row,opts.size??'reb',opts.basis))return false;
  return true;
 });
 const ranked=[...eligible].sort((a,b)=>{
  const v=(b.values[opts.y]??-Infinity)-(a.values[opts.y]??-Infinity);
  return v||(a.player<b.player?-1:a.player>b.player?1:0)||(a.id<b.id?-1:a.id>b.id?1:0);
 });
 const fullPopulation=['histogram','box','cumulative'].includes(opts.kind);
 const cap=opts.kind==='bar'?(opts.rankingSize??20):opts.population;
 const plotted=fullPopulation?eligible:cap===0?ranked:ranked.slice(0,cap);
 return {matching,eligible,ranked,plotted};
}
export interface LinearStats {
 count:number;r:number;rSquared:number;slope:number;intercept:number;
 meanX:number;meanY:number;minX:number;maxX:number;
}
export function linearStats(rows:Row[],x:MetricKey,y:MetricKey):LinearStats|null{
 const pts=rows.flatMap(row=>{
  const a=row.values[x],b=row.values[y];
  return a===null||b===null||!Number.isFinite(a)||!Number.isFinite(b)?[]:[[a,b]];
 });
 const n=pts.length;
 if(n<2)return null;
 const mx=pts.reduce((s,v)=>s+v[0],0)/n,my=pts.reduce((s,v)=>s+v[1],0)/n;
 let xx=0,yy=0,xy=0,minX=Infinity,maxX=-Infinity;
 for(const [a,b] of pts){
  const dx=a-mx,dy=b-my;xx+=dx*dx;yy+=dy*dy;xy+=dx*dy;
  minX=Math.min(a,minX);maxX=Math.max(a,maxX);
 }
 const slope=xx===0?0:xy/xx,intercept=my-slope*mx;
 const denominator=Math.sqrt(xx*yy);
 const r=denominator===0?0:Math.max(-1,Math.min(1,xy/denominator));
 return {count:n,r,rSquared:r*r,slope,intercept,meanX:mx,meanY:my,minX,maxX};
}
export const correlationLabel=(r:number)=>{
 const value=Math.abs(r),direction=r>=0?'positive':'negative';
 return value>=.7?'strong '+direction:value>=.4?'moderate '+direction:
 value>=.2?'weak '+direction:'little linear relationship';
};
export function quantile(sorted:number[],p:number):number|null{
 if(!sorted.length)return null;
 const x=(sorted.length-1)*p,l=Math.floor(x),r=Math.ceil(x);
 return sorted[l]+(sorted[r]-sorted[l])*(x-l);
}
export function histogram(values:number[],count:number){
 if(!values.length)return [];
 const min=Math.min(...values),max=Math.max(...values),size=(max-min||1)/count;
 return Array.from({length:count},(_,i)=>{
  const left=min+size*i,right=i===count-1?max:min+size*(i+1);
  return {min:left,max:right,count:values.filter(v=>v>=left&&(i===count-1?v<=right:v<right)).length};
 });
}
