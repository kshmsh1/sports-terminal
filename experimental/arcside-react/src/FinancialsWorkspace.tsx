import {useEffect,useMemo,useState} from 'react';
export interface TeamFinancialRecord{team:string;standardRoster:number;twoWayRoster:number;capSpace:number;taxSpace:number;firstApronSpace:number;secondApronSpace:number;hardCap:string|null;availableExceptions:Record<string,number>;largestTpe:number|null;largestTpeExpires:string|null}
export interface TeamFinancialReport{kind:string;sourceAsOf:string;source:string;dartSourceSha256:string;teams:TeamFinancialRecord[]}
const dollars=(n:number|null)=>n===null?'—':(n<0?'−$':'$')+Math.abs(n).toLocaleString('en-US',{maximumFractionDigits:0});
export function FinancialsWorkspace(){
 const [report,setReport]=useState<TeamFinancialReport|null>(null);
 const [selected,setSelected]=useState('');
 const [error,setError]=useState('');
 useEffect(()=>{const controller=new AbortController();
  fetch('/data/phase3/2026-27-team-financials.json',{credentials:'same-origin',signal:controller.signal})
   .then(async res=>{if(!res.ok)throw Error('Original financial reference unavailable ('+res.status+')');
    return res.json() as Promise<TeamFinancialReport>})
   .then(data=>{if(data.kind!=='ARCSIDE_ORIGINAL_FLUTTER_TEAM_FINANCIALS_2026_27_V1'||data.teams.length!==30)
    throw Error('Original Flutter financial reference contract not verified');
    if(!controller.signal.aborted)setReport(data);
   }).catch(e=>{if(!controller.signal.aborted)setError(String(e.message??e))});
  return ()=>controller.abort();
 },[]);
 const rows=useMemo(()=>[...(report?.teams??[])].sort((a,b)=>a.team.localeCompare(b.team)),[report]);
 const team=rows.find(r=>r.team===selected)??null;
 return <section className="panel financials-workspace" aria-label="NBA team financials">
  <div className="panel-title"><div><p className="eyebrow">NBA / ORIGINAL FLUTTER FINANCIAL REFERENCE</p>
   <h2>Financials</h2><p className="subtle">2026–27 team cap, tax and apron space. Dated reference, not a live cap ledger.</p></div></div>
  {error&&<p role="alert">{error}</p>}
  {!report&&!error&&<p role="status">Loading original published team financial snapshot…</p>}
  {report&&<>
   <p className="subtle">Source: {report.source} · {report.sourceAsOf} · {rows.length} teams · Original Dart source fingerprint {report.dartSourceSha256.slice(0,12)}</p>
   <div className="financial-layout">
    <div className="table-scroll" role="region" tabIndex={0} aria-label="NBA team financial table">
     <table className="stats-table"><thead><tr><th>Team</th><th>Roster</th><th>Cap space</th><th>Tax space</th><th>First apron</th><th>Second apron</th></tr></thead>
      <tbody>{rows.map(row=><tr key={row.team} className={team?.team===row.team?'selected-financial':''}>
       <td><button onClick={()=>setSelected(row.team)} aria-pressed={team?.team===row.team} className="sort-button">{row.team}</button></td>
       <td className="numeric">{row.standardRoster}</td><td className="numeric">{dollars(row.capSpace)}</td>
       <td className="numeric">{dollars(row.taxSpace)}</td><td className="numeric">{dollars(row.firstApronSpace)}</td>
       <td className="numeric">{dollars(row.secondApronSpace)}</td>
      </tr>)}</tbody></table>
    </div>
    <div className="financial-inspector" aria-label="Financial team inspector">
     {!team?<p className="empty">Select a team to inspect its original 2026–27 cap snapshot.</p>:<>
      <h3>{team.team} · Financial overview</h3>
      <dl className="financial-facts">{([
       ['Standard contracts',String(team.standardRoster)],['Two-way contracts',String(team.twoWayRoster)],
       ['Cap space',dollars(team.capSpace)],['Tax space',dollars(team.taxSpace)],
       ['First apron space',dollars(team.firstApronSpace)],['Second apron space',dollars(team.secondApronSpace)],
       ['Hard-cap status',team.hardCap==='first'?'1st apron':team.hardCap==='second'?'2nd apron':'None'],
       ['Largest TPE',dollars(team.largestTpe)],['TPE expiration',team.largestTpeExpires??'—']
      ] as const).map(([key,value])=><div key={key}><dt>{key}</dt><dd>{value}</dd></div>)}</dl>
      <h3>Available signing exceptions</h3>{Object.keys(team.availableExceptions).length?
       Object.entries(team.availableExceptions).map(([key,n])=><p key={key}>{key.replaceAll('_',' ').toUpperCase()} · {dollars(n)}</p>):
       <p className="subtle">None listed in this dated reference.</p>}
     </>}
    </div>
   </div>
  </>}
  <p className="table-note">This read-only panel reflects the same transcribed snapshot used by the authoritative Flutter financial screen. It does not infer player contract balances or current transaction eligibility.</p>
 </section>;
}
