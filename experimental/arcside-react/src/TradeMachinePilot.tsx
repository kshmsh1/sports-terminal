import {useEffect,useMemo,useState} from 'react';
import {nba2026Cap,validateTrade} from './tradeEngine';
import type {TradeAsset,TradeAssignment,TradeScenario} from './tradeEngine';
import type {DatedContractSnapshot} from './data';
import {getDatedContracts} from './data';
type RawDraft={id:string;label:string;originTeam:string;destinationTeam:string;type:TradeAsset['type'];salary:string;metadata:string};
const asNumber=(s:string)=>{const n=Number(s);return Number.isFinite(n)?n:null};
const sample=[
 {id:'a',label:'Player A',originTeam:'AAA',destinationTeam:'BBB',type:'player',salary:'8000000',metadata:'{}'},
 {id:'b',label:'Player B',originTeam:'BBB',destinationTeam:'AAA',type:'player',salary:'8000000',metadata:'{}'}
] as RawDraft[];
export function TradeMachinePilot(){
 const [teamA,setTeamA]=useState('AAA'),[teamB,setTeamB]=useState('BBB');
 const [salaryA,setSalaryA]=useState('140000000'),[salaryB,setSalaryB]=useState('140000000');
 const [asOf,setAsOf]=useState('2026-11-20');
 const [drafts,setDrafts]=useState<RawDraft[]>(sample),[dirty,setDirty]=useState(false);
 const [details,setDetails]=useState(false);
 const [publishedContracts,setPublishedContracts]=useState<DatedContractSnapshot|null>(null);
 const [publishedError,setPublishedError]=useState('');
 useEffect(()=>{const controller=new AbortController();
  getDatedContracts(controller.signal).then(setPublishedContracts)
   .catch(e=>{if(!controller.signal.aborted)setPublishedError(String(e.message??e))});
  return ()=>controller.abort();
 },[]);
 const [pickFirst,setPickFirst]=useState('');
 const [pickSecond,setPickSecond]=useState('');
 const publishedTeams=[...new Set((publishedContracts?.records??[]).map(x=>x.team))].sort();
 const publishedPlayers=(team:string)=>(publishedContracts?.records??[]).filter(x=>x.team===team&&x.salaries['2026-27']>0);
 const addPublishedPlayer=(recordId:string,destinationTeam:string)=>{
  const item=publishedContracts?.records.find(x=>x.id===recordId);if(!item)return;
  setDirty(true);
  setDrafts(prev=>[...prev,{id:'published-'+item.id,label:item.player,originTeam:item.team,
   destinationTeam,type:'player',salary:String(item.salaries['2026-27']),metadata:JSON.stringify({
    source:item.sourceLabel,dated_salary_as_of:publishedContracts?.asOf??'',guaranteed:item.guaranteed
   })}]);
 };

 const info=useMemo(()=>{
  const errors:string[]=[];
  const teams=[teamA.trim().toUpperCase(),teamB.trim().toUpperCase()];
  if(teams.some(x=>!x)||teams[0]===teams[1])errors.push('Teams must be two distinct nonempty identifiers.');
  const salA=asNumber(salaryA),salB=asNumber(salaryB);
  if(salA===null||salB===null||salA<0||salB<0)errors.push('Enter valid nonnegative team salaries.');
  const assignments:TradeAssignment[]=[];
  for(const [i,d] of drafts.entries()){
   const salary=asNumber(d.salary);
   if(salary===null||salary<0){errors.push('Asset '+(i+1)+' has an invalid salary.');continue}
   let metadata:Record<string,unknown>={};
   try{const parsed=JSON.parse(d.metadata||'{}');if(!parsed||Array.isArray(parsed)||typeof parsed!=='object')
    throw Error('Metadata must be an object');metadata=parsed}
   catch{errors.push('Asset '+(i+1)+' has malformed metadata JSON.');continue}
   assignments.push({asset:{id:d.id,label:d.label,originTeam:d.originTeam,
    type:d.type,salary,metadata},destinationTeam:d.destinationTeam});
  }
  if(errors.length)return {errors,scenario:null,report:null};
  const capContexts={ [teams[0]]:nba2026Cap(teams[0],salA!),
   [teams[1]]:nba2026Cap(teams[1],salB!)};
  const scenario:TradeScenario={id:'phase3-review',name:'Review scenario',operatingSeason:'2026-27',
   teams,assignments,capContexts,asOfDateIso:asOf?asOf+'T00:00:00Z':''};
  return {errors,scenario,report:validateTrade(scenario)};
 },[teamA,teamB,salaryA,salaryB,drafts,asOf]);
 const update=(index:number,patch:Partial<RawDraft>)=>{setDirty(true);
  setDrafts(old=>old.map((d,i)=>i===index?{...d,...patch}:d))};
 const add=()=>{setDirty(true);setDrafts(old=>[...old,{id:'new-'+old.length,label:'New asset',
  originTeam:teamA,destinationTeam:teamB,type:'player',salary:'0',metadata:'{}'}])};
 return <section className="panel trade-pilot" aria-label="Trade Machine experimental model">
  <div className="panel-title"><div><p className="eyebrow">REACT PHASE 3 / INDEPENDENT DART-CONTRACT PORT</p>
   <h2>Trade Machine · CBA validation pilot</h2><p className="subtle">2026–27 modeled cap rules. Independently ported TypeScript validator; illustrative inputs only. Not an approved trade transaction engine or full production Trade Machine.</p></div></div>
  <div className="trade-grid">
   <label>First team identifier<input aria-label="Trade first team" value={teamA} onChange={e=>{setDirty(true);setTeamA(e.target.value.toUpperCase())}}/></label>
   <label>First team payroll ($)<input aria-label="First team salary" inputMode="numeric" value={salaryA} onChange={e=>{setDirty(true);setSalaryA(e.target.value)}}/></label>
   <label>Second team identifier<input aria-label="Trade second team" value={teamB} onChange={e=>{setDirty(true);setTeamB(e.target.value.toUpperCase())}}/></label>
   <label>Second team payroll ($)<input aria-label="Second team salary" inputMode="numeric" value={salaryB} onChange={e=>{setDirty(true);setSalaryB(e.target.value)}}/></label>
   <label>As-of date<input aria-label="Trade as-of date" type="date" value={asOf} onChange={e=>{setDirty(true);setAsOf(e.target.value)}}/></label>
  </div>
  <fieldset className="trade-published-assets"><legend>Source-backed player salary library · optional scenario inputs</legend>
   <p className="subtle">Published salary values as of {publishedContracts?.asOf??'unavailable'}. These are historical seed records, not verified current cap charges or tradeable assets.</p>
   {publishedError&&<p role="alert">Published salary snapshot unavailable: {publishedError}</p>}
   <div className="trade-grid">
    <label>First team published player<select aria-label="First team published player" value={pickFirst} onChange={e=>setPickFirst(e.target.value)}>
     <option value="">Choose from dated roster</option>{publishedPlayers(teamA).map(x=><option key={x.id} value={x.id}>{x.player} · {x.salaries['2026-27'].toLocaleString()}</option>)}</select></label>
    <button disabled={!pickFirst} onClick={()=>{addPublishedPlayer(pickFirst,teamB);setPickFirst('')}}>Add first-team player</button>
    <label>Second team published player<select aria-label="Second team published player" value={pickSecond} onChange={e=>setPickSecond(e.target.value)}>
     <option value="">Choose from dated roster</option>{publishedPlayers(teamB).map(x=><option key={x.id} value={x.id}>{x.player} · {x.salaries['2026-27'].toLocaleString()}</option>)}</select></label>
    <button disabled={!pickSecond} onClick={()=>{addPublishedPlayer(pickSecond,teamA);setPickSecond('')}}>Add second-team player</button>
   </div>
   <p className="subtle">{publishedTeams.length} original source team identifiers available. All selections remain editable hypothetical assets.</p>
  </fieldset>
  <h3>Assigned assets</h3><div className="trade-assets">{drafts.map((d,i)=><fieldset key={i} className="trade-asset">
   <legend>Asset {i+1}</legend>
   <div className="trade-grid">
    <label>Asset ID<input aria-label={'Asset '+(i+1)+' ID'} value={d.id} onChange={e=>update(i,{id:e.target.value})}/></label>
    <label>Label<input aria-label={'Asset '+(i+1)+' label'} value={d.label} onChange={e=>update(i,{label:e.target.value})}/></label>
    <label>Asset type<select aria-label={'Asset '+(i+1)+' type'} value={d.type} onChange={e=>update(i,{type:e.target.value as TradeAsset['type']})}>
     {['player','draftPick','draftRights','cash','freeAgentRights','tradeException','signingException'].map(t=><option key={t}>{t}</option>)}
    </select></label>
    <label>From team<input aria-label={'Asset '+(i+1)+' from'} value={d.originTeam} onChange={e=>update(i,{originTeam:e.target.value.toUpperCase()})}/></label>
    <label>To team<input aria-label={'Asset '+(i+1)+' to'} value={d.destinationTeam} onChange={e=>update(i,{destinationTeam:e.target.value.toUpperCase()})}/></label>
    <label>Nominal salary / cash ($)<input aria-label={'Asset '+(i+1)+' salary'} value={d.salary} inputMode="numeric" onChange={e=>update(i,{salary:e.target.value})}/></label>
   </div>
   <label>Source-reported metadata JSON<textarea aria-label={'Asset '+(i+1)+' metadata'} rows={2} value={d.metadata} onChange={e=>update(i,{metadata:e.target.value})}/></label>
   <button onClick={()=>{setDirty(true);setDrafts(prev=>prev.filter((_,n)=>n!==i))}}>Remove asset {i+1}</button>
  </fieldset>)}</div>
  <div className="trade-actions">
   <button onClick={add}>Add asset</button>
   <button onClick={()=>{setDrafts(sample);setTeamA('AAA');setTeamB('BBB');setSalaryA('140000000');setSalaryB('140000000');setAsOf('2026-11-20');setDirty(false)}}>Reset example</button>
   <button onClick={()=>setDetails(x=>!x)} aria-expanded={details}>Show modeled validation details</button>
  </div>
  {info.errors.length>0&&<div role="alert">{info.errors.join(' ')}</div>}
  {info.report&&<div className="trade-results" aria-label="Modeled validation results">
   <p role="status">{info.report.isValid?'No modeled blocking errors':'Modeled transaction has blocking errors'} · {info.report.errorCount} errors · {info.report.warningCount} warnings{dirty?' · modified scenario':' · example scenario'}</p>
   <div className="table-scroll"><table className="stats-table"><thead><tr><th>Team</th><th>Outgoing matching</th><th>Incoming matching</th><th>Post-trade payroll</th><th>Max incoming</th><th>Projected roster</th><th>Apron</th></tr></thead>
    <tbody>{Object.values(info.report.teamSummaries).map(t=><tr key={t.team}><td>{t.team}</td>
     <td>{t.outgoingSalary.toLocaleString()}</td><td>{t.incomingSalary.toLocaleString()}</td>
     <td>{t.postTradeSalary.toLocaleString()}</td><td>{Number.isFinite(t.maximumIncomingSalary)?t.maximumIncomingSalary.toLocaleString():'No finite modeled limit'}</td>
     <td>{t.projectedRosterPlayers}</td><td>{t.apronStatus}</td></tr>)}</tbody></table></div>
   {details&&<div aria-label="CBA findings">{info.report.findings.length?info.report.findings.map((f,i)=>
    <p key={i}><strong>{f.severity.toUpperCase()} · {f.code}</strong> · {f.team??'Scenario'}: {f.message}</p>):
    <p>No findings on this modeled scenario.</p>}</div>}
  </div>}
  <p className="table-note">The original Flutter Trade Machine is authoritative. This experimental UI can import dated, source-labeled player salary records, but still lacks verified live cap team payroll, draft protections, complete asset eligibility and a full production transaction workflow; it cannot confirm CBA legality. Full production feature parity remains blocked.</p>
 </section>;
}
