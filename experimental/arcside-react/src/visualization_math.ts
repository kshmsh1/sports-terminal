// Phase 3 Visualization Studio -- source-based deterministic selection and OLS.
// These functions never create fallback NBA values for missing metrics.
import type {MetricKey,Row} from './engine';

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
 kind:ChartKind;size?:MetricKey;rankingSize?:number;
}){
 const matching=rows.filter(row=>{
  if((row.values.gp??0)<opts.minGames)return false;
  if(opts.filter.startsWith('team:')&&!rowTeams(row).includes(opts.filter.slice(5)))return false;
  if(opts.filter.startsWith('player:')&&row.id!==opts.filter.slice(7))return false;
  return true;
 });
 const eligible=matching.filter(row=>{
  if(opts.kind==='radar')return (['pts','reb','ast','stl','blk','ts_pct'] as MetricKey[])
   .some(key=>valueFor(row,key)!==null);
  if(valueFor(row,opts.y)===null)return false;
  if(['scatter','bubble'].includes(opts.kind)&&valueFor(row,opts.x)===null)return false;
  if(opts.kind==='bubble'&&valueFor(row,opts.size??'reb')===null)return false;
  return true;
 });
 const ranked=[...eligible].sort((a,b)=>{
  const v=(b.values[opts.y]??-Infinity)-(a.values[opts.y]??-Infinity);
  return v||a.player.localeCompare(b.player,'en')||a.id.localeCompare(b.id,'en');
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
 if(xx<=1e-14||yy<=1e-14)return null;
 const slope=xy/xx,intercept=my-slope*mx,r=xy/Math.sqrt(xx*yy);
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
