import {useEffect,useMemo,useState} from 'react';
import type {RateBasis,SeasonType} from './data';
import type {Row,MetricKey} from './engine';
import {stintRows} from './engine';
import {advancedGroups,advancedMetricCatalog,advancedChildren,rateSensitiveKeys} from './advancedCatalog';
import type {AdvancedMetric} from './advancedCatalog';

const nativeEngineKeys=new Set<MetricKey>([
 'gp','min','age','pts','ast','reb','oreb','dreb','stl','blk','tov','pf','fgm','fga',
 'fg_pct','two_pm','two_pa','two_pct','three_pm','three_pa','three_pct','ftm','fta','ft_pct',
 'ts_pct','efg_pct','points_per_shot','ast_tov','three_rate','ft_rate','plus_minus','bpm',
 'game_score_proxy','stocks','defense_events','possessions_proxy','scoring_load'
]);
const labels:Record<RateBasis,string>={perGame:'Per-game values.',per36:'Per 36 minutes.',
 per48:'Per 48 minutes.',per75:'Per 75 possessions.',per100:'Per 100 possessions.',totals:'Season totals.'};
const rawNumber=(v:unknown):number|null=>{
 if(v===null||v===undefined||typeof v==='boolean')return null;
 // Match original Dart NbaTerminalMetricResolver._number normalization.
 const cleaned=String(v).replaceAll(',','').replaceAll('%','')
  .replaceAll('lb','').replaceAll('lbs','').replaceAll('in','').trim();
 if(cleaned==='')return null;
 const n=Number(cleaned);
 return Number.isFinite(n)?n:null;
};
export function metricValue(row:Row,metricKey:string):number|null{
 const metric=advancedMetricCatalog[metricKey];
 if(!metric)return null;
 // Flutter reference resolver checks source-native aliases BEFORE computed engine values.
 // Normalize punctuation/casing in source keys as the Dart catalog resolver does.
 const norm=(s:string)=>s.toLowerCase().replace(/[^a-z0-9]/g,'');
 const rawKeys=Object.keys(row.raw);
 for(const alias of metric.raw){
  let v=rawNumber(row.raw[alias]);
  if(v===null){
   const match=rawKeys.find(k=>norm(k)===norm(alias));
   if(match)v=rawNumber(row.raw[match]);
  }
  if(v!==null)return metric.format==='percent'&&Math.abs(v)>1?v/100:v;
 }
 if(metric.engine && nativeEngineKeys.has(metric.engine as MetricKey))
  return row.values[metric.engine as MetricKey]??null;
 // Flutter only falls back to engine row.value(key), not arbitrary raw[key].
 // Source-native fields must have declared catalog aliases; avoid falsely
 // populating fields that Flutter genuinely considers unavailable.
 // Explicit Flutter catalog fallbacks; missing inputs remain missing.
 if(metricKey==='pps'){
  const p=row.values.pts,a=row.values.fga;
  return p!==null&&a!==null&&a>0?p/a:null;
 }
 if(metricKey==='net_rating'){
  const offense=metricValue(row,'ortg'),defense=metricValue(row,'drtg');
  return offense!==null&&defense!==null?offense-defense:null;
 }
 if(metricKey==='contested_rpg'||metricKey==='uncontested_rpg'){
  const prefix=metricKey==='contested_rpg'?'contested':'uncontested';
  const offense=metricValue(row,prefix+'_orb_pg'),defense=metricValue(row,prefix+'_dreb_pg');
  return offense===null&&defense===null?null:(offense??0)+(defense??0);
 }
 return null;
}
// Flutter's Overview and Rate Adjusted groups explicitly override the shared
// catalog abbreviations. Catalog-driven families retain native short labels,
// e.g. RPG/100 in Rebounding rather than the Overview label REB/100.
const customCount:Record<string,{per:string;total:string;stem:string}>={
 mpg:{per:'MPG',total:'Minutes',stem:'MIN'},
 ppg:{per:'PPG',total:'Points',stem:'PTS'},
 rpg:{per:'RPG',total:'Rebounds',stem:'REB'},
 apg:{per:'APG',total:'Assists',stem:'AST'},
 spg:{per:'SPG',total:'Steals',stem:'STL'},
 bpg:{per:'BPG',total:'Blocks',stem:'BLK'},
 tpg:{per:'TPG',total:'Turnovers',stem:'TOV'},
 fgm:{per:'FGM PG',total:'Field Goals Made',stem:'FGM'},
 three_pm:{per:'3PM PG',total:'Three-Pointers Made',stem:'3PM'},
 ftm:{per:'FTM PG',total:'Free Throws Made',stem:'FTM'},
};
export function advancedLabel(key:string,basis:RateBasis,group='Overview'):string{
 const m=advancedMetricCatalog[key];
 if(!m)return key.toUpperCase();
 const children:Record<string,{per:string;total:string;stem:string}>={
  oreb:{per:'ORB',total:'Offensive Rebounds',stem:'OREB'},
  dreb:{per:'DREB',total:'Defensive Rebounds',stem:'DREB'},
  fgm:{per:'FGM',total:'Field Goals Made',stem:'FGM'},
  fga:{per:'FGA',total:'Field Goal Attempts',stem:'FGA'},
  three_pm:{per:'3PM',total:'Three-Pointers Made',stem:'3PM'},
  three_pa:{per:'3PA',total:'Three-Point Attempts',stem:'3PA'},
  ftm:{per:'FTM',total:'Free Throws Made',stem:'FTM'},
  fta:{per:'FTA',total:'Free Throw Attempts',stem:'FTA'}
 };
 const custom=group==='Rate Adjusted'?customCount[key]:
  group==='Overview'?(children[key]??customCount[key]):
  group==='Shooting & Efficiency'?children[key]:undefined;
 // Flutter's Overview PF is a fixed label, although the underlying value
 // still reflects the chosen rate basis.
 if(group==='Overview'&&key==='pf')return 'PF';
 if(custom&&m.engine&&rateSensitiveKeys.has(m.engine)){
  if(basis==='perGame')return custom.per;
  if(basis==='totals')return custom.total;
  return custom.stem+'/'+({per36:'36',per48:'48',per75:'75',per100:'100'} as Record<string,string>)[basis];
 }
 if(!m.engine||!rateSensitiveKeys.has(m.engine))return m.label;
 if(basis==='perGame'||basis==='totals')return m.label;
 return m.label+'/'+({per36:'36',per48:'48',per75:'75',per100:'100'} as Record<string,string>)[basis];
}
export function advancedText(row:Row,key:string):string{
 const metric=advancedMetricCatalog[key];
 if(metric?.format==='text')return String(row.raw[key]??'').trim()||'—';
 const v=metricValue(row,key);
 if(v===null)return '—';
 // Use Flutter catalog display formats, not the smaller Stats engine formatter.
 if(metric?.format==='percent')return (v*100).toFixed(metric.decimals)+'%';
 if(metric?.format==='integer')return String(Math.round(v));
 if(metric?.format==='feetInches')return v<0?'—':Math.floor(Math.round(v)/12)+"'"+(Math.round(v)%12)+'"';
 if(metric?.format==='signed')return (v>=0?'+':'')+v.toFixed(metric?.decimals??1);
 return v.toFixed(metric?.decimals??1);
}
const availableMetric=(k:string)=>advancedMetricCatalog[k]!==undefined;
export type AdvancedTableOptions={search:string;team:string;position:string;minGp:number;minMpg:number;sort:string;descending:boolean};
export function advancedFilteredSortedRows(rows:Row[],o:AdvancedTableOptions):Row[]{
 const q=o.search.trim().toLowerCase();
 return rows.filter(r=>{
  const match=!q||(r.player+' '+r.team+' '+r.position).toLowerCase().includes(q);
  // Original Flutter reference filters row.value('min') in the selected basis.
  return match&&(o.team==='All'||r.team.split(/[,/ ]+/).includes(o.team))&&
   (o.position==='All'||r.position===o.position)&&
   (r.values.gp??0)>=o.minGp&&(r.values.min??0)>=o.minMpg;
 }).sort((a,b)=>{
  if(advancedMetricCatalog[o.sort]?.format==='text'){
   const va=advancedText(a,o.sort),vb=advancedText(b,o.sort);
   if(va==='—')return vb==='—'?0:1;
   if(vb==='—')return -1;
   return o.descending?-va.localeCompare(vb):va.localeCompare(vb);
  }
  const va=metricValue(a,o.sort),vb=metricValue(b,o.sort);
  if(va===null&&vb===null)return a.player.localeCompare(b.player);
  if(va===null)return 1;
  if(vb===null)return -1;
  return (o.descending?vb-va:va-vb)||a.player.localeCompare(b.player);
 });
}
type Props={rows:Row[];basis:RateBasis;segment:SeasonType;season:string;onPlayer:(id:string)=>void};
export function AdvancedStatsTable({rows,basis,segment,season,onPlayer}:Props){
 const [group,setGroup]=useState('Overview');
 const [search,setSearch]=useState('');
 const [team,setTeam]=useState('All');
 const [position,setPosition]=useState('All');
 const [minGp,setMinGp]=useState(segment==='regular'?50:0);
 const [minMpg,setMinMpg]=useState(20);
 const [sort,setSort]=useState('ppg');
 const [descending,setDescending]=useState(true);
 const [expandedMetrics,setExpandedMetrics]=useState<Set<string>>(()=>new Set());
 const [expandedPlayers,setExpandedPlayers]=useState<Set<string>>(()=>new Set());
 const [page,setPage]=useState(1);
 const [pageSize,setPageSize]=useState(20);
 useEffect(()=>{setMinGp(segment==='regular'?50:0);setMinMpg(20);setPage(1);setTeam('All');setExpandedPlayers(new Set())},[segment]);
 useEffect(()=>{setPage(1)},[basis,season,group,search,team,position,minGp,minMpg,sort,descending,pageSize]);
 const current=advancedGroups.find(x=>x.name===group)??advancedGroups[0];
 const keys=useMemo(()=>{
  const out:string[]=[];
  for(const k of current.keys){
   if(!availableMetric(k))continue;
   out.push(k);
   if(expandedMetrics.has(k))for(const c of advancedChildren(current.name,k))if(availableMetric(c))out.push(c);
  }
  return out;
 },[current,expandedMetrics]);
 const teams=useMemo(()=>['All',...new Set(rows.flatMap(r=>r.team.split(/[,/ ]+/).filter(t=>/^[A-Z0-9]{2,4}$/.test(t))))].sort(),[rows]);
 const filtered=useMemo(()=>advancedFilteredSortedRows(rows,
  {search,team,position,minGp,minMpg,sort,descending}),
  [rows,search,team,position,minGp,minMpg,sort,descending]);
 const pages=Math.max(1,Math.ceil(filtered.length/pageSize));
 const currentPage=Math.min(page,pages);
 const paged=filtered.slice((currentPage-1)*pageSize,currentPage*pageSize);
 const csv=()=>{
  const escape=(v:string)=>'"'+v.replaceAll('"','""')+'"';
  const cols=['Player','Team','Position',...keys.map(k=>advancedLabel(k,basis,group))];
  const data=[cols,...filtered.map(r=>[r.player,r.team,r.position,...keys.map(k=>advancedText(r,k))])];
  const text=data.map(line=>line.map(escape).join(',')).join('\n');
  if(navigator.clipboard?.writeText)void navigator.clipboard.writeText(text).catch(()=>{});
  else {
   const blob=new Blob([text],{type:'text/csv;charset=utf-8'}),url=URL.createObjectURL(blob);
   const anchor=document.createElement('a');anchor.href=url;anchor.download='arcside-advanced-'+season+'.csv';anchor.click();URL.revokeObjectURL(url);
  }
 };
 const pager=<div className="advanced-pager">
  <span>{filtered.length?((currentPage-1)*pageSize+1)+'–'+Math.min(currentPage*pageSize,filtered.length):'0'} of {filtered.length}</span>
  <span className="advanced-pager-options">Rows {([10,20,50,100] as const).map(n=><button type="button" key={n} className={pageSize===n?'active-control':''} onClick={()=>setPageSize(n)}>{n}</button>)}</span>
  <button disabled={currentPage===1} onClick={()=>setPage(p=>Math.max(1,p-1))} aria-label="Previous page">‹</button>
  <span>Page {currentPage} / {pages}</span>
  <button disabled={currentPage>=pages} onClick={()=>setPage(p=>Math.min(pages,p+1))} aria-label="Next page">›</button>
 </div>;
 return <section className="panel advanced-panel" aria-label="Statistical table">
  <div className="panel-title"><div><p className="eyebrow">NBA / FLUTTER-CATALOG STAT GROUPS</p>
   <h2>Advanced player statistics</h2><p className="subtle">{filtered.length} of {rows.length} player rows · {segment==='regular'?'Regular season':'Playoffs'} · {season}</p></div></div>
  <div className="toolbar advanced-toolbar">
   <label>Stat group<select aria-label="Stat group" value={group} onChange={e=>{setGroup(e.target.value);setSort((advancedGroups.find(g=>g.name===e.target.value)?.keys[0])??'gp');setDescending(true);setExpandedMetrics(new Set())}}>
    {advancedGroups.map(g=><option key={g.name} value={g.name}>{g.name}</option>)}</select></label>
   <label>Find player<input aria-label="Find player" value={search} onChange={e=>setSearch(e.target.value)} placeholder="Search players"/></label>
   <label>Team<select value={team} onChange={e=>setTeam(e.target.value)}>{teams.map(t=><option key={t}>{t}</option>)}</select></label>
   <label>Position<select value={position} onChange={e=>setPosition(e.target.value)}>{['All','PG','SG','SF','PF','C'].map(p=><option key={p}>{p}</option>)}</select></label>
   <label>GP<select aria-label="Minimum GP" value={minGp} onChange={e=>setMinGp(Number(e.target.value))}>{[50,65,60,40,30,20,10,0].map(n=><option key={n} value={n}>{n===0?'All':n+'+'}</option>)}</select></label>
   <label>MPG<select aria-label="Minimum MPG" value={minMpg} onChange={e=>setMinMpg(Number(e.target.value))}>{[0,30,25,20,15,10].map(n=><option key={n} value={n}>{n===0?'All':n+'+'}</option>)}</select></label>
   <button onClick={()=>{setSearch('');setTeam('All');setPosition('All');setMinGp(segment==='regular'?50:0);setMinMpg(20)}}>Reset filters</button>
   <button onClick={csv}>Copy CSV</button>
  </div>
  <div className="advanced-groups" role="group" aria-label="Advanced stat groups">
   {advancedGroups.map(g=><button key={g.name} className={g.name===group?'active-control':''} aria-pressed={g.name===group}
     onClick={()=>{setGroup(g.name);setSort(g.keys[0]);setDescending(true);setExpandedMetrics(new Set())}}>{g.name}</button>)}
  </div>
  <div className="advanced-description"><p>{current.description}</p><p>{labels[basis]} Fields unavailable from the selected original dataset display as —.</p></div>
  {pager}
  <div className="table-scroll advanced-table-scroll" tabIndex={0} role="region" aria-label="Scrollable advanced player stats">
   <table className="stats-table advanced-stats-table"><thead><tr><th scope="col">Player</th><th scope="col">Team</th><th scope="col">Position</th>
    {keys.map(k=>{const m:AdvancedMetric=advancedMetricCatalog[k];return <th key={k} scope="col" aria-sort={sort===k?(descending?'descending':'ascending'):undefined}>
     <span className="advanced-column-heading">{advancedChildren(group,k).length>0&&<button aria-label={'Expand '+m.label} aria-expanded={expandedMetrics.has(k)}
      onClick={()=>setExpandedMetrics(p=>{const n=new Set(p);if(n.has(k))n.delete(k);else n.add(k);return n})}>{expandedMetrics.has(k)?'▾':'▸'}</button>}
      <button className="sort-button" aria-label={'Sort by '+advancedLabel(k,basis,group)} title={m.description}
       onClick={()=>{setDescending(prev=>sort===k?!prev:true);setSort(k)}}>{advancedLabel(k,basis,group)} {sort===k?(descending?'↓':'↑'):''}</button></span></th>})}
   </tr></thead><tbody>
    {paged.flatMap(r=>{
     const children=expandedPlayers.has(r.id)?stintRows(r,basis):[];
     const all=[r,...children];
     return all.map((rr,i)=><tr key={r.id+':'+i} className={i?'stint-row':''}>
      <td className="player-cell">{i?'↳ ':''}{i===0&&stintRows(r,basis).length>0&&<button aria-label={'Expand stints for '+r.player} onClick={()=>setExpandedPlayers(p=>{const n=new Set(p);if(n.has(r.id))n.delete(r.id);else n.add(r.id);return n})}>{expandedPlayers.has(r.id)?'−':'+'}</button>}
      <button className="text-button" onClick={()=>onPlayer(rr.id)}>{rr.player}</button></td>
      <td>{rr.team}</td><td>{rr.position}</td>
      {keys.map(k=><td key={k} className="numeric" title={advancedMetricCatalog[k].description}>{advancedText(rr,k)}</td>)}
     </tr>);
    })}
   </tbody></table>
  </div>
  {pager}
  <p className="table-note">Source-backed values · null remains unavailable · original Flutter metric catalog. This experimental React implementation is not yet certified for complete interface parity.</p>
 </section>
}
