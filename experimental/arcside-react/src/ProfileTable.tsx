import {useMemo,useState} from 'react';
import type {JsonRow,RateBasis,SeasonType} from './data';
import {advancedGroups,advancedMetricCatalog,advancedChildren} from './advancedCatalog';
import type {AdvancedMetric} from './advancedCatalog';

// The dossier's published career rows are an independent source contract.
// Do not fabricate unpublished statistics or infer rate conversions that
// the original Flutter player profile does not perform.
const asRows=(v:unknown):JsonRow[]=>Array.isArray(v)?
 v.filter((r):r is JsonRow=>r!==null&&typeof r==='object'&&!Array.isArray(r)):[];
const source=(row:JsonRow,aliases:string[])=>{
 for(const key of aliases){const value=row[key];if(value!==undefined&&value!==null&&value!=='')return value;}
 return null;
};
const number=(v:unknown):number|null=>{
 if(typeof v==='number')return Number.isFinite(v)?v:null;
 if(typeof v!=='string')return null;
 const parsed=Number(v.replaceAll(',','').replaceAll('%','').trim());
 return Number.isFinite(parsed)?parsed:null;
};
export function dossierSegments(dossier:JsonRow|null){
 return {regular:asRows(dossier?.regular_seasons),playoffs:asRows(dossier?.playoff_seasons)};
}
export function dossierName(dossier:JsonRow|null,fallback='Player profile'){
 const profile=dossier?.profile;
 const record=profile&&typeof profile==='object'&&!Array.isArray(profile)?profile as JsonRow:{};
 return String(source(record,['canonical_name','player_name','name'])??
  source(dossier??{},['canonical_name','player_name','player_label'])??fallback);
}
const ordered=(rows:JsonRow[])=>[...rows].sort((a,b)=>
 String(b.season_id??'').localeCompare(String(a.season_id??'')));
const decimal=(v:unknown,places=1)=>{const n=number(v);return n===null?'—':n.toFixed(places)};
const integer=(v:unknown)=>{const n=number(v);return n===null?'—':String(Math.round(n))};
const perGame=(r:JsonRow,aliases:string[])=>{
 const v=number(source(r,aliases)),games=number(source(r,['games','gp']));
 return v===null||games===null||games<=0?'—':(v/games).toFixed(1);
};
const percent=(r:JsonRow,aliases:string[])=>{
 const v=number(source(r,aliases));
 return v===null?'—':(Math.abs(v)>1?v:v*100).toFixed(1)+'%';
};
const signed=(r:JsonRow,aliases:string[])=>{
 const v=number(source(r,aliases));return v===null?'—':(v>=0?'+':'')+v.toFixed(1);
};
const careerColumns=[
 {key:'gp',label:'GP',render:(r:JsonRow)=>integer(source(r,['games','gp']))},
 {key:'mpg',label:'MPG',render:(r:JsonRow)=>perGame(r,['minutes','min'])},
 {key:'ppg',label:'PPG',render:(r:JsonRow)=>perGame(r,['pts','points'])},
 {key:'rpg',label:'RPG',render:(r:JsonRow)=>perGame(r,['reb','rebounds'])},
 {key:'orb',label:'ORB',parent:'rpg',render:(r:JsonRow)=>perGame(r,['oreb','offensive_rebounds'])},
 {key:'drb',label:'DRB',parent:'rpg',render:(r:JsonRow)=>perGame(r,['dreb','defensive_rebounds'])},
 {key:'apg',label:'APG',render:(r:JsonRow)=>perGame(r,['ast','assists'])},
 {key:'spg',label:'SPG',render:(r:JsonRow)=>perGame(r,['stl','steals'])},
 {key:'bpg',label:'BPG',render:(r:JsonRow)=>perGame(r,['blk','blocks'])},
 {key:'tpg',label:'TPG',render:(r:JsonRow)=>perGame(r,['tov','turnovers'])},
 {key:'pf',label:'PF',render:(r:JsonRow)=>perGame(r,['pf','personal_fouls'])},
 {key:'fg',label:'FG%',render:(r:JsonRow)=>percent(r,['fg_pct','field_goal_percentage'])},
 {key:'fgm',label:'FGM',parent:'fg',render:(r:JsonRow)=>perGame(r,['fgm','field_goals_made'])},
 {key:'fga',label:'FGA',parent:'fg',render:(r:JsonRow)=>perGame(r,['fga','field_goal_attempts'])},
 {key:'three',label:'3P%',render:(r:JsonRow)=>percent(r,['three_pct','fg3_pct','three_point_percentage'])},
 {key:'three_pm',label:'3PM',parent:'three',render:(r:JsonRow)=>perGame(r,['three_pm','three_pointers_made','fg3m'])},
 {key:'three_pa',label:'3PA',parent:'three',render:(r:JsonRow)=>perGame(r,['three_pa','three_point_attempts','fg3a'])},
 {key:'ft',label:'FT%',render:(r:JsonRow)=>percent(r,['ft_pct','free_throw_percentage'])},
 {key:'ftm',label:'FTM',parent:'ft',render:(r:JsonRow)=>perGame(r,['ftm','free_throws_made'])},
 {key:'fta',label:'FTA',parent:'ft',render:(r:JsonRow)=>perGame(r,['fta','free_throw_attempts'])},
 {key:'ts',label:'TS%',render:(r:JsonRow)=>percent(r,['ts_pct'])},
 {key:'per',label:'PER',render:(r:JsonRow)=>decimal(source(r,['per']))},
 {key:'bpm',label:'BPM',render:(r:JsonRow)=>signed(r,['bpm'])},
 {key:'vorp',label:'VORP',render:(r:JsonRow)=>decimal(source(r,['vorp']))}
] as const;
const normalized=(name:string)=>name.toLowerCase().replace(/[^a-z0-9]/g,'');
export function dossierMetric(row:JsonRow,metric:AdvancedMetric):number|null{
 const byNormalized=new Map(Object.entries(row).map(([k,v])=>[normalized(k),v]));
 const keys=[...metric.raw,...(metric.engine?[metric.engine]:[]),metric.key];
 for(const key of keys){
  const value=number(row[key]??byNormalized.get(normalized(key)));
  if(value!==null)return metric.format==='percent'&&Math.abs(value)>1?value/100:value;
 }
 return null;
}
export function dossierMetricText(row:JsonRow,metric:AdvancedMetric){
 if(metric.format==='text'){
  const value=source(row,[...metric.raw,...(metric.engine?[metric.engine]:[]),metric.key]);
  return value===null?'—':String(value);
 }
 const value=dossierMetric(row,metric);
 if(value===null)return '—';
 if(metric.format==='percent')return (value*100).toFixed(metric.decimals)+'%';
 if(metric.format==='integer')return String(Math.round(value));
 if(metric.format==='signed')return (value>=0?'+':'')+value.toFixed(metric.decimals);
 return value.toFixed(metric.decimals);
}
export function PlayerProfileTables({dossier,segment,basis}:{
 dossier:JsonRow;segment:SeasonType;basis:RateBasis;
}){
 const segments=dossierSegments(dossier);
 const rows=useMemo(()=>ordered(segments[segment]),[dossier,segment]);
 const [expanded,setExpanded]=useState<Set<string>>(()=>new Set());
 const [group,setGroup]=useState(advancedGroups[0].name);
 const [expandedAdvanced,setExpandedAdvanced]=useState<Set<string>>(()=>new Set());
 const category=advancedGroups.find(g=>g.name===group)??advancedGroups[0];
 const columns=careerColumns.filter(c=>!('parent' in c)||expanded.has(c.parent));
 const requested=category.keys.flatMap(key=>[key,...(expandedAdvanced.has(key)?advancedChildren(category.name,key):[])]);
 const available=requested.map(k=>advancedMetricCatalog[k]).filter((metric):metric is AdvancedMetric=>
  Boolean(metric)&&rows.some(row=>dossierMetric(row,metric)!==null));
 return <>
  <section className="panel profile-stats-panel" aria-label="Player career statistics">
   <div className="panel-title"><div><p className="eyebrow">NBA / ORIGINAL PLAYER DOSSIER</p>
    <h2>Career statistics</h2><p className="subtle">Published historical {segment==='regular'?'regular season':'playoff'} rows · {rows.length} seasons · {basis} shell context</p></div></div>
   {!rows.length?<p className="empty">No source-backed statistics are available for this segment.</p>:
   <div className="table-scroll profile-table-scroll" tabIndex={0} role="region" aria-label="Player career statistics table">
    <table className="stats-table profile-table"><thead><tr>
     <th scope="col">Season</th><th scope="col">Team</th><th scope="col">Pos</th>
     {columns.map(col=><th scope="col" key={col.key}>
      {['rpg','fg','three','ft'].includes(col.key)?
       <button className="sort-button" aria-expanded={expanded.has(col.key)} aria-label={'Expand '+col.label}
        onClick={()=>setExpanded(prev=>{const next=new Set(prev);if(next.has(col.key))next.delete(col.key);else next.add(col.key);return next})}>
        {expanded.has(col.key)?'▾':'▸'} {col.label}</button>:col.label}</th>)}
    </tr></thead><tbody>{rows.map((row,i)=><tr key={String(row.season_id??i)+':'+i}>
     <td>{String(row.season_id??'—')}</td><td>{String(row.team_abbreviation??'—')}</td>
     <td>{String(source(row,['positions','position','pos'])??'—')}</td>
     {columns.map(col=><td key={col.key} className="numeric">{col.render(row)}</td>)}
    </tr>)}</tbody></table>
   </div>}
  </section>
  <section className="panel profile-advanced-panel" aria-label="Player advanced statistics">
   <div className="panel-title"><div><p className="eyebrow">NBA / FLUTTER ADVANCED STAT FAMILIES</p>
    <h2>Advanced statistics</h2><p className="subtle">Source-native values only; missing metrics remain unavailable.</p></div></div>
   <div className="toolbar"><label>Advanced stat family
    <select aria-label="Player advanced stat family" value={group} onChange={e=>{setGroup(e.target.value);setExpandedAdvanced(new Set());}}>
     {advancedGroups.map(g=><option key={g.name}>{g.name}</option>)}</select></label></div>
   <div className="advanced-groups" role="group" aria-label="Player advanced stat groups">
    {advancedGroups.map(g=><button key={g.name} aria-pressed={g.name===group}
     className={g.name===group?'active-control':''} onClick={()=>{setGroup(g.name);setExpandedAdvanced(new Set());}}>{g.name}</button>)}
   </div>
   {!available.length?<p className="empty">{group} statistics have no published source-backed values for these seasons. Missing statistics are not synthesized.</p>:
   <div className="table-scroll profile-table-scroll" tabIndex={0} role="region" aria-label="Player advanced statistics table">
    <table className="stats-table profile-table"><thead><tr>
     <th scope="col">Season</th><th scope="col">Team</th><th scope="col">Pos</th>
     {available.map(metric=><th scope="col" key={metric.key}>
      {advancedChildren(group,metric.key).length>0&&<button className="expand" aria-expanded={expandedAdvanced.has(metric.key)}
       aria-label={'Expand '+metric.label} onClick={()=>setExpandedAdvanced(prev=>{
        const next=new Set(prev);if(next.has(metric.key))next.delete(metric.key);else next.add(metric.key);return next})}>
       {expandedAdvanced.has(metric.key)?'▾':'▸'}</button>}
      {metric.label}</th>)}</tr></thead>
     <tbody>{rows.map((row,i)=><tr key={String(row.season_id??i)+':'+i}>
      <td>{String(row.season_id??'—')}</td><td>{String(row.team_abbreviation??'—')}</td>
      <td>{String(source(row,['positions','position','pos'])??'—')}</td>
      {available.map(metric=><td key={metric.key} className="numeric">{dossierMetricText(row,metric)}</td>)}
     </tr>)}</tbody></table>
   </div>}
  </section>
 </>;
}
