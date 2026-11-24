import {useEffect,useMemo,useState} from 'react';
export interface TeamFinancialRecord{team:string;standardRoster:number;twoWayRoster:number;capSpace:number;taxSpace:number;firstApronSpace:number;secondApronSpace:number;hardCap:string|null;availableExceptions:Record<string,number>;largestTpe:number|null;largestTpeExpires:string|null}
export interface TeamFinancialReport{kind:string;sourceAsOf:string;source:string;dartSourceSha256:string;league?:{salaryCap:number;taxLine:number;firstApron:number;secondApron:number};teams:TeamFinancialRecord[]}
const dollars=(n:number|null|undefined)=>n==null||!Number.isFinite(n)?'—':(n<0?'−$':'$')+Math.abs(n).toLocaleString('en-US',{maximumFractionDigits:0});
const displayTeam=(team:string)=>team==='BRK'?'BKN':team;
const hardCapLabel=(value:string|null)=>value==='first'?'1st Apron':value==='second'?'2nd Apron':value===null?'None':'Unknown';
const roomClass=(n:number)=>n<0?'money-negative':n>0?'money-positive':'';
export function FinancialsWorkspace(){
 const [report,setReport]=useState<TeamFinancialReport|null>(null);
 const [selected,setSelected]=useState('');
 const [query,setQuery]=useState('');
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
 const shown=rows.filter(r=>[r.team,displayTeam(r.team)].join(' ').toLowerCase().includes(query.trim().toLowerCase()));
 return <section className="panel financials-workspace" aria-label="NBA team financials">
  <div className="panel-title"><div><p className="eyebrow">NBA / TEAM CAP SNAPSHOT</p>
   <h2>Financials</h2><p className="subtle">2026–27 team cap, tax and apron space. Dated reference, not a live cap ledger.</p></div></div>
  {error&&<p role="alert">{error}</p>}
  {!report&&!error&&<p role="status">Loading original published team financial snapshot…</p>}
  {report&&<>
   {report.league&&<div className="financial-thresholds" aria-label="2026–27 league thresholds">{[['Salary cap',report.league.salaryCap],['Luxury tax',report.league.taxLine],['First apron',report.league.firstApron],['Second apron',report.league.secondApron]].map(([label,value])=><div key={label}><span>{label}</span><strong>{dollars(value as number)}</strong></div>)}</div>}
   <div className="toolbar"><label>Find team<input aria-label="Find financial team" placeholder="Team abbreviation" value={query} onChange={e=>setQuery(e.target.value)}/></label><span className="subtle">{shown.length} of {rows.length} teams</span></div>
   <p className="subtle">Source: {report.source} · {report.sourceAsOf} · {rows.length} teams · Source fingerprint {report.dartSourceSha256.slice(0,12)}</p>
   <div className="financial-layout">
    <div className="table-scroll" role="region" tabIndex={0} aria-label="NBA team financial table">
     <table className="stats-table"><thead><tr><th scope="col">Team</th><th scope="col">Roster</th><th scope="col">Cap space</th><th scope="col">Tax space</th><th scope="col">First apron</th><th scope="col">Second apron</th><th scope="col">Hard cap</th></tr></thead>
      <tbody>{shown.map(row=><tr key={row.team} className={team?.team===row.team?'selected-financial':''}>
       <td><button onClick={()=>setSelected(row.team)} aria-pressed={team?.team===row.team} className="sort-button">{displayTeam(row.team)}</button></td>
       <td className="numeric">{row.standardRoster} + {row.twoWayRoster} two-way</td><td className={'numeric '+roomClass(row.capSpace)}>{dollars(row.capSpace)}</td>
       <td className={'numeric '+roomClass(row.taxSpace)}>{dollars(row.taxSpace)}</td><td className={'numeric '+roomClass(row.firstApronSpace)}>{dollars(row.firstApronSpace)}</td>
       <td className={'numeric '+roomClass(row.secondApronSpace)}>{dollars(row.secondApronSpace)}</td><td>{hardCapLabel(row.hardCap)}</td>
      </tr>)}</tbody></table>
    </div>
    <div className="financial-inspector" aria-label="Financial team inspector">
     {!team?<p className="empty">Select a team to inspect its original 2026–27 cap snapshot.</p>:<>
      <div className="row-wrap financial-inspector-heading"><h3>{displayTeam(team.team)} · Financial overview</h3><button onClick={()=>setSelected('')}>Close details</button></div>
      <dl className="financial-facts">{([
       ['Standard contracts',String(team.standardRoster)],['Two-way contracts',String(team.twoWayRoster)],
       ['Cap allocation',dollars(report.league?report.league.salaryCap-team.capSpace:null)],['Cap space',dollars(team.capSpace)],['Tax space',dollars(team.taxSpace)],
       ['First apron space',dollars(team.firstApronSpace)],['Second apron space',dollars(team.secondApronSpace)],
       ['Hard-cap status',hardCapLabel(team.hardCap)],
       ['Largest TPE',dollars(team.largestTpe)],['TPE expiration',team.largestTpeExpires??'—']
      ] as const).map(([key,value])=><div key={key}><dt>{key}</dt><dd>{value}</dd></div>)}</dl>
      <h3>Available signing exceptions</h3>{Object.keys(team.availableExceptions).length?
       Object.entries(team.availableExceptions).map(([key,n])=><p key={key}>{key.replaceAll('_',' ').toUpperCase()} · {dollars(n)}</p>):
       <p className="subtle">None listed in this dated reference.</p>}
     </>}
    </div>
   </div>
  </>}
  <p className="table-note">Dated source snapshot. It does not infer player contract balances or current transaction eligibility.</p>
 </section>;
}
