import {useEffect,useMemo,useState} from 'react';
import type {RateBasis,SeasonType,WithWithoutData} from './data';
import {getWithWithout} from './data';
import type {Row} from './engine';
import {formatMetric} from './engine';
const playerId=(r:Row)=>r.id;
const asTeam=(row:Row)=>row.team.split(/[,/ ]+/).filter(x=>/^[A-Z]{2,4}$/.test(x));
const fmt=(v:number|null)=>v===null?'—':v.toFixed(1);
const keys=['pts','ast','reb','tov','ts_pct','fta','three_pct','plus_minus'];
const labels:Record<string,string>={pts:'PTS',ast:'AST',reb:'REB',tov:'TOV',ts_pct:'TS%',fta:'FTA',three_pct:'3P%',plus_minus:'+/-'};
export function WithWithoutWorkspace({rows,season,segment,basis}:{
 rows:Row[];season:string;segment:SeasonType;basis:RateBasis
}){
 const [team,setTeam]=useState('');
 const [first,setFirst]=useState('');
 const [second,setSecond]=useState('');
 const [loaded,setLoaded]=useState<{key:string;data:WithWithoutData}|null>(null);
 const sourceKey=season+':'+segment;
 const data=loaded?.key===sourceKey?loaded.data:null;
 const [loading,setLoading]=useState(false),[error,setError]=useState('');
 const [selectedKeys,setSelectedKeys]=useState(keys);
 const teams=useMemo(()=>[...new Set(rows.flatMap(asTeam))].sort(),[rows]);
 const selectedTeam=teams.includes(team)?team:(teams[0]??'');
 const roster=useMemo(()=>rows.filter(r=>asTeam(r).includes(selectedTeam))
  .sort((a,b)=>(b.values.min??0)-(a.values.min??0)),[rows,selectedTeam]);
 const selectedFirst=roster.find(r=>playerId(r)===first)??roster[0];
 const selectedSecond=roster.find(r=>playerId(r)===second&&r.id!==selectedFirst?.id)??
  roster.find(r=>r.id!==selectedFirst?.id);
 useEffect(()=>{
  if(!season){setLoaded(null);return}
  const controller=new AbortController();setLoading(true);setError('');setLoaded(null);
  getWithWithout(season,segment,controller.signal)
   .then(response=>{if(!controller.signal.aborted)setLoaded({key:season+':'+segment,data:response})})
   .catch(e=>{if(!controller.signal.aborted)setError(String(e.message??e))})
   .finally(()=>{if(!controller.signal.aborted)setLoading(false)});
  return ()=>controller.abort();
 },[season,segment]);
 const split=(a:string,b:string)=>data?.rows.find(r=>r.team===selectedTeam&&r.player_id===a&&r.teammate_id===b)??null;
 const firstSplit=selectedFirst&&selectedSecond?split(selectedFirst.id,selectedSecond.id):null;
 const secondSplit=selectedFirst&&selectedSecond?split(selectedSecond.id,selectedFirst.id):null;
 const line=(row:typeof firstSplit,metric:string)=>{
  if(!row)return {with:null,without:null};
  return {with:row.with[metric]??null,without:row.without[metric]??null};
 };
 return <section className="panel withwithout-workspace" aria-label="With and without analysis">
  <div className="panel-title"><div><p className="eyebrow">NBA / PUBLISHED LINEUP-SPLIT ARCHIVE</p>
   <h2>With / Without</h2>
   <p className="subtle">Compare published pair-level lineup splits alongside the season baseline. Unavailable splits remain blank.</p></div></div>
  <div className="toolbar">
   <label>Team<select aria-label="With/without team" value={selectedTeam} onChange={e=>{setTeam(e.target.value);setFirst('');setSecond('')}}>
    {teams.map(t=><option key={t}>{t}</option>)}</select></label>
   <label>Player A<select aria-label="With/without player A" value={selectedFirst?.id??''} onChange={e=>{setFirst(e.target.value);setSecond('')}}>
    {roster.map(r=><option key={r.id} value={r.id}>{r.player}</option>)}</select></label>
   <label>Player B<select aria-label="With/without player B" value={selectedSecond?.id??''} onChange={e=>setSecond(e.target.value)}>
    {roster.filter(r=>r.id!==selectedFirst?.id).map(r=><option key={r.id} value={r.id}>{r.player}</option>)}</select></label>
  </div>
  {loading&&<p role="status">Checking published lineup split file…</p>}
  {error&&<p role="alert">{error}</p>}
  {!loading&&data&&!data.available&&<p className="empty">{data.message}</p>}
  {data?.available&&<p className="subtle">Lineup source: {data.source||'Published source unspecified'} · {data.rows.length} pair records · {season} {segment}</p>}
  <div className="row-wrap comparison-actions">{keys.map(k=><label key={k} className="check"><input type="checkbox"
   checked={selectedKeys.includes(k)} onChange={e=>setSelectedKeys(prev=>e.target.checked?[...prev,k]:prev.filter(x=>x!==k))}/>{labels[k]??k.toUpperCase()}</label>)}</div>
  <div className="withwithout-grids">
   {[{title:selectedFirst?.player??'Player A',row:selectedFirst,split:firstSplit},
     {title:selectedSecond?.player??'Player B',row:selectedSecond,split:secondSplit}].map((item,i)=>
     <div className="withwithout-player" key={i}>
      <h3>{item.title}</h3>
      <p className="subtle">Season baseline · {basis} · {segment}</p>
      <div className="table-scroll" role="region" aria-label={item.title+' published splits'} tabIndex={0}>
       <table className="stats-table"><thead><tr><th scope="col">Metric</th><th scope="col">Season baseline</th><th scope="col">With teammate</th><th scope="col">Without teammate</th><th scope="col">Shift</th></tr></thead>
        <tbody>{selectedKeys.map(k=>{
         const values=line(item.split,k);
         const diff=values.with!==null&&values.without!==null?values.with-values.without:null;
         return <tr key={k}><th scope="row">{labels[k]??k.toUpperCase()}</th>
          <td className="numeric">{item.row?formatMetric(k as keyof Row['values'],item.row.values[k as keyof Row['values']]??null):'—'}</td>
          <td className="numeric">{fmt(values.with)}</td><td className="numeric">{fmt(values.without)}</td>
          <td className="numeric">{diff===null?'—':(diff>=0?'+':'')+diff.toFixed(1)}</td>
         </tr>})}</tbody></table>
      </div>
      {item.split?<p className="subtle">Minutes together: {fmt(item.split.minutes_with)} · apart: {fmt(item.split.minutes_without)}</p>:
       <p className="subtle">No confirmed pair-level split for this orientation. Season totals cannot establish with/without values.</p>}
     </div>)}
  </div>
  <p className="table-note">Published pair splits are shown in their recorded units. The rate-basis selector changes the season baseline only; it does not rescale split data without verified denominators.</p>
 </section>;
}
