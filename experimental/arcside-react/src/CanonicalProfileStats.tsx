
import {useEffect,useMemo,useState} from 'react';
import type {JsonRow,SeasonSnapshot,RateBasis,SeasonType} from './data';
import {getSeason} from './data';
import {normalize,formatMetric,metrics,overviewKeys,stintRows} from './engine';
import type {Row} from './engine';
import {advancedGroups,advancedMetricCatalog,advancedChildren} from './advancedCatalog';
import {advancedLabel,advancedText} from './AdvancedStatsTable';
import {dossierSegments} from './ProfileDossier';
type Match={season:string;status:'matched'|'missing'|'ambiguous'|'unavailable';raw?:JsonRow;profile?:JsonRow};
export function matchSeasonPlayer(snapshot:SeasonSnapshot,key:string):Match{
 const candidates=snapshot.player_season_totals.filter(x=>String(x.player_id??x.player_key??x.id??'')===key);
 if(candidates.length!==1)return {season:snapshot.season_id,status:candidates.length?'ambiguous':'missing'};
 const profile=snapshot.players.find(x=>String(x.player_id??x.player_key??x.id??'')===key)??{};
 return {season:snapshot.season_id,status:'matched',raw:candidates[0],profile};
}
export function CanonicalProfileStats({dossier,playerKey,segment,basis,season,activeSnapshot}:{
 dossier:JsonRow;playerKey:string;segment:SeasonType;basis:RateBasis;season:string;activeSnapshot:SeasonSnapshot|null;
}){
 const [scope,setScope]=useState<'selected'|'career'>('selected');
 const [mode,setMode]=useState<'stats'|'advanced'>('advanced'),[group,setGroup]=useState('Overview');
 const [expanded,setExpanded]=useState<string[]>([]),[expandedSeasons,setExpandedSeasons]=useState<string[]>([]);
 const [loaded,setLoaded]=useState<{key:string;rows:Match[];pending:number}>({key:'',rows:[],pending:0});
 const seasons=useMemo(()=>scope==='selected'?[season].filter(Boolean):[...new Set(dossierSegments(dossier)[segment].map(r=>String(r.season_id??'')).filter(s=>/^\d{4}-\d{2}$/.test(s)))].sort().reverse(),[scope,season,dossier,segment]);
 const requestKey=playerKey+'|'+segment+'|'+seasons.join(',');
 useEffect(()=>{
  const controller=new AbortController();let cursor=0,remaining=seasons.length;
  setLoaded({key:requestKey,rows:[],pending:remaining});
  const worker=async()=>{while(cursor<seasons.length&&!controller.signal.aborted){
   const id=seasons[cursor++];let result:Match;
   try{const shard=activeSnapshot?.season_id===id&&activeSnapshot.season_type===segment?activeSnapshot:await getSeason(id,segment,controller.signal);
    result=matchSeasonPlayer(shard,playerKey);
   }catch{result={season:id,status:'unavailable'}}
   if(controller.signal.aborted)return;
   remaining--;
   setLoaded(prev=>prev.key===requestKey?{key:requestKey,rows:[...prev.rows,result],pending:remaining}:prev);
  }};
  // Limit simultaneous full-season requests, retain only the exact player's records.
  void Promise.all(Array.from({length:Math.min(3,seasons.length)},()=>worker()));
  return ()=>controller.abort();
 },[requestKey]); // activeSnapshot is a reuse hint, not a reason to reload an entire career
 const results=loaded.key===requestKey?loaded.rows:[],pending=loaded.key===requestKey?loaded.pending:seasons.length;
 const normalized=useMemo(()=>results.filter(m=>m.status==='matched'&&m.raw).map(m=>({season:m.season,row:normalize(m.raw!,m.profile??{},basis)})).sort((a,b)=>b.season.localeCompare(a.season)),[results,basis]);
 const family=advancedGroups.find(g=>g.name===group)??advancedGroups[0];
 const keys=family.keys.flatMap(k=>[k,...(expanded.includes(k)?advancedChildren(group,k):[])]).filter(k=>advancedMetricCatalog[k]);
 const show=(row:Row)=>mode==='stats'?overviewKeys.map(k=><td key={k} className="numeric">{formatMetric(k,row.values[k])}</td>):keys.map(k=><td key={k} className="numeric">{advancedText(row,k)}</td>);
 return <section className="panel profile-stats-panel canonical-profile" aria-label="Canonical league-table statistics">
  <div className="panel-title"><div><p className="eyebrow">SAME SOURCE AS STATS / ADVANCED STATS</p><h2>League-table statistics</h2><p className="subtle">Exact canonical player-ID joins from published season shards. Separate from the historical dossier below.</p></div></div>
  <div className="toolbar"><label>Season coverage<select aria-label="Profile league-table coverage" value={scope} onChange={e=>setScope(e.target.value as typeof scope)}><option value="selected">Selected season</option><option value="career">All published career seasons</option></select></label>
  <div role="group" aria-label="Profile league-table type" className="row-wrap"><button aria-pressed={mode==='stats'} onClick={()=>setMode('stats')}>Stats</button><button aria-pressed={mode==='advanced'} onClick={()=>setMode('advanced')}>Advanced Stats</button></div>
  {mode==='advanced'&&<label>Stat family<select aria-label="Profile league-table stat family" value={group} onChange={e=>{setGroup(e.target.value);setExpanded([])}}>{advancedGroups.map(g=><option key={g.name}>{g.name}</option>)}</select></label>}</div>
  {mode==='advanced'&&<div className="advanced-groups" role="group" aria-label="Profile league-table metric groups">{advancedGroups.map(g=><button key={g.name} aria-pressed={g.name===group} className={g.name===group?'active-control':''} onClick={()=>{setGroup(g.name);setExpanded([])}}>{g.name}</button>)}</div>}
  <p className="table-note" role="status">{normalized.length} of {seasons.length} exact season matches · {pending} pending · {results.filter(x=>x.status!=='matched').length} unavailable or ambiguous · {basis}</p>
  {normalized.length>0&&<div className="table-scroll profile-table-scroll" tabIndex={0} role="region" aria-label="Canonical player season statistics"><table className="stats-table advanced-stats-table profile-table">
  <thead><tr><th scope="col">Season</th><th scope="col">Team</th><th scope="col">Position</th>{mode==='stats'?overviewKeys.map(k=><th key={k} scope="col">{metrics.find(m=>m.key===k)?.label??k}</th>):keys.map(k=><th key={k} scope="col" title={advancedMetricCatalog[k].description}><span className="advanced-column-heading">{advancedChildren(group,k).length>0&&<button aria-label={'Expand league '+advancedMetricCatalog[k].label} aria-expanded={expanded.includes(k)} onClick={()=>setExpanded(p=>p.includes(k)?p.filter(x=>x!==k):[...p,k])}>{expanded.includes(k)?'▾':'▸'}</button>}{advancedLabel(k,basis,group)}</span></th>)}</tr></thead>
  <tbody>{normalized.flatMap(({season,row})=>{
   const stints=stintRows(row,basis);
   return [<tr key={season}><td>{stints.length>0&&<button aria-label={'Expand team stints '+season} aria-expanded={expandedSeasons.includes(season)} onClick={()=>setExpandedSeasons(p=>p.includes(season)?p.filter(x=>x!==season):[...p,season])}>{expandedSeasons.includes(season)?'−':'+'}</button>}{season}</td><td>{row.team}</td><td>{row.position}</td>{show(row)}</tr>,
    ...(expandedSeasons.includes(season)?stints.map(s=><tr className="stint-row" key={season+':'+s.team}><td>↳</td><td>{s.team}</td><td>{s.position}</td>{show(s)}</tr>):[])];
  })}</tbody></table></div>}
  {results.some(x=>x.status!=='matched')&&<details className="trade-source-detail"><summary>Unmatched season source details</summary>{results.filter(x=>x.status!=='matched').sort((a,b)=>b.season.localeCompare(a.season)).map(x=><p key={x.season}>{x.season} · {x.status}</p>)}<p>Missing or ambiguous canonical matches are not replaced by guessed names or combined team totals.</p></details>}
 </section>
}
