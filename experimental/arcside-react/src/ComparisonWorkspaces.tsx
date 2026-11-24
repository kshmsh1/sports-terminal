import {useEffect,useMemo,useState} from 'react';
import type {JsonRow,RateBasis,Season,SeasonSnapshot,SeasonType} from './data';
import {getSeason} from './data';
import {buildRows,formatMetric,metrics} from './engine';
import type {MetricKey,Row} from './engine';

export const playerCompareKeys:MetricKey[]=['gp','min','pts','reb','ast','stl','blk','tov','fg_pct','three_pct','ft_pct','ts_pct','bpm'];
export const teamCompareKeys=['games','wins','losses','win_pct','ppg','opp_ppg','point_diff','pace','ortg','drtg','net_rtg','srs','fg_pct','three_pct','ft_pct','efg_pct','ts_pct'] as const;
type TeamKey=typeof teamCompareKeys[number];
export interface TeamRow{key:string;name:string;abbreviation:string;values:Partial<Record<TeamKey,number>>}
const asRows=(x:unknown):JsonRow[]=>Array.isArray(x)?x.filter((v):v is JsonRow=>v!==null&&typeof v==='object'&&!Array.isArray(v)):[];
const text=(row:JsonRow,keys:string[],fallback='')=>{
 for(const key of keys)if(row[key]!=null&&String(row[key]).trim()!=='')return String(row[key]).trim();
 return fallback;
};
const num=(x:unknown):number|null=>typeof x==='number'&&Number.isFinite(x)?x:
 typeof x==='string'&&x.trim()!==''&&Number.isFinite(Number(x))?Number(x):null;
const recordNum=(r:JsonRow,...keys:string[])=>keys.map(k=>num(r[k])).find(n=>n!==null)??null;
const logsFields=['points','opponent_points','field_goals_made','field_goal_attempts','three_pointers_made','three_point_attempts','free_throws_made','free_throw_attempts'];
export function buildTeamRows(snapshot:SeasonSnapshot):TeamRow[]{
 const logsBy=new Map<string,JsonRow[]>();
 for(const log of asRows(snapshot.team_game_logs)){
  const key=text(log,['team_id','team_key']);if(key)logsBy.set(key,[...(logsBy.get(key)??[]),log]);
 }
 const teamMeta=new Map<string,JsonRow>();
 for(const team of asRows(snapshot.teams)){
  const key=text(team,['team_id','team_key','id']);if(key)teamMeta.set(key,team);
 }
 const records=new Map<string,JsonRow>();
 for(const record of [...asRows(snapshot.team_records),...asRows(snapshot.standings)]){
  const key=text(record,['team_id','team_key']);if(key&&!records.has(key))records.set(key,record);
 }
 for(const key of logsBy.keys())if(!records.has(key))records.set(key,teamMeta.get(key)??{team_id:key});
 for(const [key,row] of teamMeta)if(!records.has(key))records.set(key,row);
 return [...records].map(([key,record])=>{
  const logs=logsBy.get(key)??[],meta=teamMeta.get(key)??{};
  const games=recordNum(record,'games','gp');
  const complete=games!==null&&games>0&&logs.length===games;
  const winsLog=logs.filter(r=>text(r,['result']).toUpperCase().startsWith('W')).length;
  const lossesLog=logs.filter(r=>text(r,['result']).toUpperCase().startsWith('L')).length;
  const wins=recordNum(record,'wins')??(complete&&winsLog+lossesLog===games?winsLog:null);
  const losses=recordNum(record,'losses')??(complete&&winsLog+lossesLog===games?lossesLog:null);
  const totals:Record<string,number>={};
  const covered=new Map<string,number>();
  for(const log of logs)for(const field of logsFields){
   const v=num(log[field]);if(v!==null){totals[field]=(totals[field]??0)+v;covered.set(field,(covered.get(field)??0)+1)}
  }
  const observed=(field:string)=>complete&&covered.get(field)===games?totals[field]:null;
  const pts=recordNum(record,'points')??observed('points');
  const opp=recordNum(record,'opponent_points')??observed('opponent_points');
  const shot=(field:string)=>complete&&covered.get(field)===games?totals[field]:null;
  const fgM=shot('field_goals_made'),fgA=shot('field_goal_attempts');
  const threeM=shot('three_pointers_made'),threeA=shot('three_point_attempts');
  const ftM=shot('free_throws_made'),ftA=shot('free_throw_attempts');
  const ratio=(a:number|null,b:number|null)=>a!==null&&b!==null&&b>0?a/b:null;
  const values:TeamRow['values']={};
  const set=(k:TeamKey,v:number|null)=>{if(v!==null&&Number.isFinite(v))values[k]=v};
  set('games',games);set('wins',wins);set('losses',losses);
  set('win_pct',wins!==null&&losses!==null?ratio(wins,wins+losses):null);
  set('pace',recordNum(record,'pace'));set('ortg',recordNum(record,'offensive_rating','ortg'));
  set('drtg',recordNum(record,'defensive_rating','drtg'));
  set('net_rtg',recordNum(record,'net_rating','net_rtg'));set('srs',recordNum(record,'srs'));
  set('ppg',ratio(pts,games));set('opp_ppg',ratio(opp,games));
  set('point_diff',pts!==null&&opp!==null?ratio(pts-opp,games):null);
  set('fg_pct',ratio(fgM,fgA));set('three_pct',ratio(threeM,threeA));
  set('ft_pct',ratio(ftM,ftA));
  set('efg_pct',fgM!==null&&threeM!==null?ratio(fgM+.5*threeM,fgA):null);
  set('ts_pct',pts!==null&&fgA!==null&&ftA!==null?ratio(pts,2*(fgA+.44*ftA)):null);
  return {key,name:text(record,['team_name','name'],text(meta,['team_name','name'],key)),
   abbreviation:text(record,['team_abbreviation','abbreviation'],text(meta,['abbreviation'],key)),values};
 }).sort((a,b)=>a.name.localeCompare(b.name));
}
export function leaderIndices(values:(number|null)[],higher=true){
 const valid=values.map((value,i)=>({value,i})).filter(x=>x.value!==null&&Number.isFinite(x.value));
 if(valid.length<2)return [] as number[];
 const best=higher?Math.max(...valid.map(v=>v.value!)):Math.min(...valid.map(v=>v.value!));
 return valid.filter(v=>Math.abs(v.value!-best)<.000001).map(v=>v.i);
}
type Slot={id:number;season:string;selected:string};
let nextSlotId=1;
const seed=(season:string):Slot[]=>[{id:nextSlotId++,season,selected:''},{id:nextSlotId++,season,selected:''}];
export function ComparisonWorkspace({kind,seasons,season,segment,basis,snapshot,onPlayer,onContext}:{
 kind:'player'|'team';seasons:Season[];season:string;segment:SeasonType;basis:RateBasis;
 snapshot:SeasonSnapshot|null;onPlayer?:(id:string)=>void;
 onContext?:(context:{segment:SeasonType;basis:RateBasis})=>void
}){
 const [slots,setSlots]=useState<Slot[]>(()=>seed(season));
 // Historical comparisons may intentionally compare different seasons. The
 // global season is an initial default; changing a slot must not be overridden.
 const [localSnapshots,setLocalSnapshots]=useState<Record<string,SeasonSnapshot>>({});
 const [error,setError]=useState('');
 const [slotQueries,setSlotQueries]=useState<Record<number,string>>({});
 const [group,setGroup]=useState('Basic');
 const [metricSet,setMetricSet]=useState<string[]>([]);
 const [savedName,setSavedName]=useState(''),[savedVersion,setSavedVersion]=useState(0);
 const groups=kind==='player'?{
  Basic:['pts','reb','ast','stl','blk','tov','pf'],
  Scoring:['pts','fgm','fga','three_pm','fta','points_per_shot'],
  Shooting:['fg_pct','two_pct','three_pct','ft_pct','efg_pct','ts_pct'],
  Playmaking:['ast','tov','ast_tov'],Rebounding:['reb','oreb','dreb'],
  Defense:['stl','blk','stocks','defense_events','pf'],
  Impact:['bpm','plus_minus','game_score_proxy','ts_pct']
 }:{
  Basic:['wins','losses','win_pct','ppg','opp_ppg','point_diff'],
  Shooting:['fg_pct','three_pct','ft_pct','efg_pct','ts_pct'],
  Efficiency:['pace','ortg','drtg','net_rtg','srs'],
  Games:['games','wins','losses','win_pct']
 };
 const selectedMetrics: string[]=metricSet.length?metricSet:(groups as unknown as Record<string,string[]>)[group]??groups.Basic;
 useEffect(()=>{setSlots(prev=>prev.map(s=>s.season?s:{...s,season}))},[season]);
 useEffect(()=>{
  const missing=[...new Set(slots.map(s=>s.season).filter(Boolean))].filter(s=>!(s===snapshot?.season_id&&snapshot?.season_type===segment)).filter(s=>!localSnapshots[segment+':'+s]);
  if(!missing.length)return;
  setError('');
  const controller=new AbortController();let alive=true;
  Promise.all(missing.map(s=>getSeason(s,segment,controller.signal).then(data=>[segment+':'+s,data] as const)))
   .then(entries=>{if(alive)setLocalSnapshots(prev=>({...prev,...Object.fromEntries(entries)}))})
   .catch(e=>{if(alive&&!controller.signal.aborted)setError(String(e.message??e))});
  return ()=>{alive=false;controller.abort()};
 },[slots,segment,snapshot,localSnapshots]);
 useEffect(()=>{setMetricSet([]);setSlotQueries({})},[kind]);
 const candidates=useMemo(()=>{
  const m=new Map<string,{id:string;label:string;player?:Row;team?:TeamRow}[]>();
  for(const s of slots.map(x=>x.season).filter(Boolean)){
   if(m.has(s))continue;
   const snap=s===snapshot?.season_id&&snapshot.season_type===segment?snapshot:localSnapshots[segment+':'+s];
   if(!snap){m.set(s,[]);continue}
   m.set(s,kind==='player'?buildRows(snap,basis).map(row=>({id:row.id,label:row.player,player:row})).sort((a,b)=>a.label.localeCompare(b.label)):
    buildTeamRows(snap).map(team=>({id:team.key,label:team.name,team})));
  }
  return m;
 },[slots,snapshot,localSnapshots,basis,segment,kind]);
 const selected=slots.map(slot=>candidates.get(slot.season)?.find(r=>r.id===slot.selected));
 const saveKey='arcside.phase3.compare.'+kind+'.v1';
 const savePreset=()=>{
  const name=savedName.trim();if(!name)return;
  try{
   const old=JSON.parse(localStorage.getItem(saveKey)??'{}') as Record<string,unknown>;
   localStorage.setItem(saveKey,JSON.stringify({...old,[name]:{slots,group,metricSet,segment,basis}}));
   setSavedVersion(x=>x+1);
  }catch(e){setError('Local comparison preset could not be saved: '+String(e))}
 };
 const presets=useMemo(()=>{
  try{return JSON.parse(localStorage.getItem(saveKey)??'{}') as Record<string,unknown>}
  catch{return {} as Record<string,unknown>}
 },[saveKey,savedVersion]);
 const restorePreset=(name:string)=>{
  const item=presets[name];
  if(!item||typeof item!=='object'||Array.isArray(item))return;
  const data=item as Record<string,unknown>;
  if(!Array.isArray(data.slots)||data.slots.length<2||data.slots.length>5)return;
  const restored=data.slots.filter(v=>v&&typeof v==='object'&&!Array.isArray(v)&&
   typeof v.season==='string'&&typeof v.selected==='string').map(v=>{
    const row=v as Slot;return {id:nextSlotId++,season:row.season,selected:row.selected};
   });
  if(restored.length===data.slots.length){
   const restoredSegment=data.segment==='playoffs'?'playoffs':'regular';
   const permittedBases:RateBasis[]=['perGame','per36','per48','per75','per100','totals'];
   const restoredBasis=permittedBases.includes(data.basis as RateBasis)?data.basis as RateBasis:basis;
   const permittedMetrics=new Set<string>(kind==='player'?metrics.map(m=>m.key):teamCompareKeys);
   setSlots(restored);setSlotQueries({});setGroup(typeof data.group==='string'&&data.group in groups?data.group:'Basic');
   setMetricSet(Array.isArray(data.metricSet)?data.metricSet.filter((x):x is string=>typeof x==='string'&&permittedMetrics.has(x)):[]);
   onContext?.({segment:restoredSegment,basis:restoredBasis});
  }
 };
 const label=(metric:string)=>kind==='player'?metrics.find(m=>m.key===metric)?.label??metric:
  ({games:'GP',wins:'W',losses:'L',win_pct:'W%',ppg:'PPG',opp_ppg:'OPP PPG',point_diff:'DIFF',
   pace:'PACE',ortg:'ORTG',drtg:'DRTG',net_rtg:'NET',srs:'SRS',fg_pct:'FG%',three_pct:'3P%',
   ft_pct:'FT%',efg_pct:'eFG%',ts_pct:'TS%'} as Record<string,string>)[metric]??metric;
 const value=(x:typeof selected[number],metric:string)=>{
  if(!x)return null;
  return kind==='player'?x.player?.values[metric as MetricKey]??null:x.team?.values[metric as TeamKey]??null;
 };
 const format=(metric:string,n:number|null)=>n===null?'—':kind==='player'?
  formatMetric(metric as MetricKey,n):['win_pct','fg_pct','three_pct','ft_pct','efg_pct','ts_pct'].includes(metric)?
  (n*100).toFixed(1)+'%':metric==='games'||metric==='wins'||metric==='losses'?String(Math.round(n)):n.toFixed(1);
 const update=(id:number,patch:Partial<Slot>)=>setSlots(prev=>prev.map(s=>s.id===id?{...s,...patch}:s));
 const tally=slots.map((_,i)=>({i,wins:0,ties:0}));
 for(const metric of selectedMetrics){
  const winners=leaderIndices(selected.map(x=>value(x,metric)),!['tov','pf','opp_ppg','drtg'].includes(metric));
  for(const i of winners)if(winners.length===1)tally[i].wins++;else tally[i].ties++;
 }
 return <section className="panel comparison-workspace" aria-label={kind==='player'?'Player comparison':'Team comparison'}>
  <div className="panel-title"><div><p className="eyebrow">NBA / CANONICAL SEASON SHARDS</p>
   <h2>{kind==='player'?'Player Comparison':'Team Comparison'}</h2>
   <p className="subtle">Two to five {kind==='player'?'players':'teams'} · distinct historical seasons · {segment} · {basis}. Missing source values remain unavailable.</p></div>
   <button onClick={()=>{setSlots(seed(season));setSlotQueries({});setGroup('Basic');setMetricSet([]);setError('')}}>Reset comparison</button></div>
  <div className="comparison-slots">{slots.map((slot,index)=>{
   const options=candidates.get(slot.season)??[],used=new Set(slots.filter(x=>x.id!==slot.id&&x.season===slot.season).map(x=>x.selected));
   const q=(slotQueries[slot.id]??'').trim().toLowerCase();
   const choices=options.filter(o=>o.id===slot.selected||(!used.has(o.id)&&(!q||[o.label,o.player?.team,o.team?.abbreviation].join(' ').toLowerCase().includes(q))));
   return <div className="comparison-slot" key={slot.id}>
    <div className="row-wrap"><strong>{kind==='player'?'Player':'Team'} {index+1}</strong>
     {slots.length>2&&<button aria-label={'Remove comparison slot '+(index+1)} onClick={()=>setSlots(prev=>prev.filter(x=>x.id!==slot.id))}>Remove</button>}</div>
    <label>Season<select aria-label={'Compare '+(kind==='player'?'player':'team')+' season '+(index+1)} value={slot.season} onChange={e=>{update(slot.id,{season:e.target.value,selected:''});setSlotQueries(prev=>({...prev,[slot.id]:''}))}}>
     {seasons.map(s=><option key={s.season_id} value={s.season_id}>{s.label??s.season_id}</option>)}</select></label>
    <label>Search {kind==='player'?'players':'teams'}<input aria-label={'Search comparison '+kind+' '+(index+1)} placeholder={kind==='player'?'Name or team':'Team name or abbreviation'} value={slotQueries[slot.id]??''} onChange={e=>setSlotQueries(prev=>({...prev,[slot.id]:e.target.value}))}/></label>
    <label>{kind==='player'?'Player':'Team'}<select aria-label={'Compare '+(kind==='player'?'player':'team')+' '+(index+1)} value={slot.selected} onChange={e=>update(slot.id,{selected:e.target.value})}>
     <option value="">Choose {kind==='player'?'player':'team'}</option>
     {choices.map(o=><option key={o.id} value={o.id}>{o.label}{kind==='player'&&o.player?.team?' · '+o.player.team:''}</option>)}</select></label>
    {!choices.length&&<p className="subtle">{q?'No matching selections.':'Waiting for published season data or no eligible records.'}</p>}
    {selected[index]&&<p className="subtle">{slot.season} · {kind==='player'?selected[index]?.player?.team:selected[index]?.team?.abbreviation}</p>}
   </div>;
  })}</div>
  <div className="row-wrap comparison-actions">
   <button disabled={slots.length>=5} onClick={()=>setSlots(prev=>[...prev,{id:nextSlotId++,season:prev.at(-1)?.season??season,selected:''}])}>Add {kind==='player'?'player':'team'}</button>
   {slots.length===2&&<button onClick={()=>setSlots(prev=>[prev[1],prev[0]])}>Swap</button>}
  </div>
  <div className="toolbar comparison-metric-toolbar"><label>Metric group<select aria-label="Compare metric group" value={group in groups?group:'Basic'} onChange={e=>{setGroup(e.target.value);setMetricSet([])}}>
   {Object.keys(groups).map(g=><option key={g}>{g}</option>)}</select></label>
   <label>Custom metrics<select aria-label="Add comparison metric" value="" onChange={e=>{if(e.target.value)setMetricSet(prev=>[...new Set([...(prev.length?prev:selectedMetrics),e.target.value])])}}>
    <option value="">Add metric…</option>{(kind==='player'?metrics.map(m=>m.key):[...teamCompareKeys]).filter(k=>!selectedMetrics.includes(k)).map(k=><option key={k} value={k}>{label(k)}</option>)}</select></label></div>
  <div className="toolbar comparison-presets">
   <label>Preset name<input aria-label="Comparison preset name" value={savedName} placeholder="My historical comparison"
    onChange={e=>setSavedName(e.target.value)}/></label>
   <button disabled={!savedName.trim()} onClick={savePreset}>Save local preset</button>
   <label>Saved comparison<select aria-label="Saved comparison" value="" onChange={e=>restorePreset(e.target.value)}>
    <option value="">Load preset…</option>{Object.keys(presets).sort().map(k=><option key={k} value={k}>{k}</option>)}
   </select></label>
  </div>
  {error&&<p role="alert">{error}</p>}
  {selected.filter(Boolean).length<2?<p className="empty">Select at least two source-backed {kind==='player'?'players':'teams'} to see a comparison. A single value cannot establish a winner.</p>:
  <div className="table-scroll" role="region" tabIndex={0} aria-label={kind==='player'?'Player comparison metrics':'Team comparison metrics'}>
   <table className="stats-table comparison-matrix"><thead><tr><th scope="col">Metric</th>
    {slots.map((slot,i)=><th key={slot.id} scope="col">{selected[i]?.label??'Not selected'} · {slot.season}</th>)}</tr></thead>
    <tbody>{selectedMetrics.map(metric=>{
     const winners=leaderIndices(selected.map(x=>value(x,metric)),!['tov','pf','opp_ppg','drtg'].includes(metric));
     return <tr key={metric}><th scope="row">{label(metric)}</th>
      {slots.map((slot,i)=>{const number=value(selected[i],metric);
       return <td key={slot.id} className={winners.includes(i)?'numeric comparison-leader':'numeric'}>{format(metric,number)}{winners.includes(i)?' ★':''}</td>})}</tr>})}
    </tbody>
   </table></div>}
  {selected.filter(Boolean).length>=2&&<div className="comparison-standings">
   {tally.filter(x=>selected[x.i]).sort((a,b)=>b.wins-a.wins||b.ties-a.ties).map(r=><p key={r.i}><strong>{selected[r.i]?.label}</strong> · {r.wins} outright leads · {r.ties} shared leads
    {kind==='player'&&onPlayer&&selected[r.i]?.player&&<button onClick={()=>onPlayer(selected[r.i]!.id)}>Player profile</button>}</p>)}
  </div>}
  <p className="table-note">Source: {kind==='player'?'canonical player-season rows with Stats rate transformations':'canonical team records and complete per-field game logs'}. Missing data is not zero.</p>
 </section>;
}
