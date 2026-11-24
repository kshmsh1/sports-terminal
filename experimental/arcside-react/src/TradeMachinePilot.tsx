import {useEffect,useMemo,useState} from 'react';
import {nba2026Cap,validateTrade} from './tradeEngine';
import type {TradeAsset,TradeAssignment,TradeScenario,TradeReport,TradeFinding} from './tradeEngine';
import type {DatedContractSnapshot,TeamCapLedgerSnapshot,OriginalDraftExceptions,OriginalTradeException} from './data';
import {getDatedContracts,getOriginalTeamCapLedger,getOriginalDraftExceptions} from './data';
type RawDraft={id:string;label:string;originTeam:string;destinationTeam:string;type:TradeAsset['type'];salary:string;metadata:string};
// Input validation is strict: JS Number('') === 0 and Number('0x10') === 16
// must never silently turn an empty or malformed salary into a valid trade.
export function parseTradeAmount(input:string):number|null{
 const raw=input.trim();
 if(!/^(?:0|[1-9]\d*)(?:\.\d{1,2})?$/.test(raw))return null;
 const value=Number(raw);
 return Number.isFinite(value)&&Number.isSafeInteger(Math.round(value*100))?value:null;
}
// A dated source cap ledger must be explicitly applied. Never imply that an
// illustrative payroll or a sum of player contracts is authoritative.
export function originalCapContext(team:string,salary:number,ledger:TeamCapLedgerSnapshot|null,active:boolean){
 const base=nba2026Cap(team,salary);
 const source=ledger?.teams.find(r=>r.team===team);
 if(!active||!source||source.salaryPosition!==salary)return base;
 return nba2026Cap(team,salary,{hardCappedAt:source.hardCap==='first'?base.firstApron:
  source.hardCap==='second'?base.secondApron:null});
}
// A source TPE belongs to the RECEIVING team. It cannot be transferred.
export function reviewTeamTpes(base:TradeReport,scenario:TradeScenario,
 selections:Record<string,string>,source:OriginalTradeException[],asOf:string):TradeReport{
 const findings:TradeFinding[]=[...base.findings];
 const add=(team:string,code:string,message:string,severity:TradeFinding['severity'])=>
  findings.push({team,code,message,severity,assetId:null});
 for(const team of scenario.teams){
  const id=selections[team];if(!id)continue;
  const tpe=source.find(x=>x.id===id&&x.team===team);
  if(!tpe){add(team,'TPE_MISSING','Selected exception does not belong to the acquiring team.','error');continue}
  if(tpe.available<=0){add(team,'TPE_EXHAUSTED','Selected exception is exhausted.','error');continue}
  if(!asOf||tpe.expires<asOf){add(team,'TPE_EXPIRED','Selected exception expired '+tpe.expires+' or lacks an as-of date.','error');continue}
  const context=scenario.capContexts[team];
  if(!context){add(team,'TPE_MISSING_CONTEXT','Missing receiving-team cap context.','error');continue}
  const incoming=scenario.assignments.filter(x=>x.destinationTeam===team&&x.asset.type==='player')
   .reduce((value,x)=>value+x.asset.salary,0);
  if(incoming<=0){add(team,'TPE_UNUSED','No incoming standard player salary to absorb.','warning');continue}
  if(context.teamSalary>context.secondApron||
   (base.teamSummaries[team]?.postTradeSalary??Infinity)>context.secondApron){
   add(team,'TPE_APRON','Selected TPE is blocked by the modeled second-apron restriction.','error');continue
  }
  if(incoming>tpe.available+100000){
   add(team,'TPE_AMOUNT','Incoming salary exceeds TPE capacity plus modeled $100K allowance.','error');continue
  }
  for(let i=findings.length-1;i>=0;i--){
   if(findings[i].team===team&&findings[i].code==='SALARY_MATCH')findings.splice(i,1);
  }
  add(team,'TPE_OK',tpe.sourceTransaction+' models absorption of $'+incoming.toLocaleString()+
   ' using $'+tpe.available.toLocaleString()+' TPE capacity (expires '+tpe.expires+').','info');
 }
 const errorCount=findings.filter(x=>x.severity==='error').length;
 return {...base,findings,errorCount,
  warningCount:findings.filter(x=>x.severity==='warning').length,isValid:errorCount===0};
}
const sample=[
 {id:'a',label:'Player A',originTeam:'AAA',destinationTeam:'BBB',type:'player',salary:'8000000',metadata:'{}'},
 {id:'b',label:'Player B',originTeam:'BBB',destinationTeam:'AAA',type:'player',salary:'8000000',metadata:'{}'}
] as RawDraft[];
export function TradeMachinePilot(){
 const [teamA,setTeamA]=useState(''),[teamB,setTeamB]=useState('');
 const [salaryA,setSalaryA]=useState(''),[salaryB,setSalaryB]=useState('');
 const [extraTeams,setExtraTeams]=useState<{name:string;salary:string}[]>([]);
 const [asOf,setAsOf]=useState('2026-11-20');
 const [drafts,setDrafts]=useState<RawDraft[]>([]),[dirty,setDirty]=useState(false);
 const [example,setExample]=useState(false);
 const [details,setDetails]=useState(false);
 const [publishedContracts,setPublishedContracts]=useState<DatedContractSnapshot|null>(null);
 const [publishedError,setPublishedError]=useState('');
 const [capLedger,setCapLedger]=useState<TeamCapLedgerSnapshot|null>(null);
 const [draftSource,setDraftSource]=useState<OriginalDraftExceptions|null>(null);
 const [draftSourceError,setDraftSourceError]=useState('');
 const [sourceDraftId,setSourceDraftId]=useState(''),[sourceTpeId,setSourceTpeId]=useState('');
 const [tpeTeam,setTpeTeam]=useState('');
 const [selectedTpeByTeam,setSelectedTpeByTeam]=useState<Record<string,string>>({});
 const [sourceAssetDestination,setSourceAssetDestination]=useState('');
 const [capError,setCapError]=useState('');
 const [usingOriginalLedger,setUsingOriginalLedger]=useState(false);
 const [allTeamSource,setAllTeamSource]=useState(''),[allTeamDestination,setAllTeamDestination]=useState('');
 const [allTeamPlayer,setAllTeamPlayer]=useState('');
 useEffect(()=>{const controller=new AbortController();
  getDatedContracts(controller.signal).then(setPublishedContracts)
   .catch(e=>{if(!controller.signal.aborted)setPublishedError(String(e.message??e))});
  getOriginalTeamCapLedger(controller.signal).then(setCapLedger)
   .catch(e=>{if(!controller.signal.aborted)setCapError(String(e.message??e))});
  getOriginalDraftExceptions(controller.signal).then(setDraftSource)
   .catch(e=>{if(!controller.signal.aborted)setDraftSourceError(String(e.message??e))});
  return ()=>controller.abort();
 },[]);
 const [pickFirst,setPickFirst]=useState('');
 const [pickSecond,setPickSecond]=useState('');
 const participating=[teamA.trim().toUpperCase(),teamB.trim().toUpperCase(),
  ...extraTeams.map(t=>t.name.trim().toUpperCase())];
 const publishedDraft=(draftSource?.draftAssets??[]).filter(x=>participating.includes(x.team));
 const publishedTpes=(draftSource?.exceptions??[]).filter(x=>participating.includes(x.team));
 const routeSourceDraft=()=>{
  const item=publishedDraft.find(x=>x.id===sourceDraftId);
  if(!item||!item.tradable||item.frozen||!sourceAssetDestination||
   item.team===sourceAssetDestination||drafts.some(d=>d.id===item.id))return;
  setDirty(true);
  setDrafts(prev=>[...prev,{id:item.id,label:item.label,originTeam:item.team,
   destinationTeam:sourceAssetDestination,type:'draftPick',salary:'0',
   metadata:JSON.stringify({draft_year:item.year,round:String(item.round),
    stepien_safe:item.stepienSafe,frozen:item.frozen,swap_right:item.swapRight,
    protection:item.protection,conveyance_uncertain:item.conditional,
    source:item.source,source_dossier:item.description})}]);
  setSourceDraftId('');
 };
 const chooseReceivingTpe=()=>{
  const item=publishedTpes.find(x=>x.id===sourceTpeId);
  if(!item||item.team!==tpeTeam||!participating.includes(tpeTeam)||
   item.available<=0||item.expires<asOf)return;
  setSelectedTpeByTeam(prev=>({...prev,[tpeTeam]:item.id}));
  setDirty(true);setSourceTpeId('');
 };
 const publishedTeams=[...new Set([...(publishedContracts?.records??[]).map(x=>x.team),...(capLedger?.teams??[]).map(x=>x.team)])].sort();
 const applyOriginalLedger=()=>{
  const entries=participating.map(team=>capLedger?.teams.find(row=>row.team===team));
  if(entries.some(x=>!x)){
   setCapError('Select only teams with original Flutter cap ledgers before applying the reference.');
   return;
  }
  setSalaryA(String(entries[0]!.salaryPosition));setSalaryB(String(entries[1]!.salaryPosition));
  setExtraTeams(prev=>prev.map((x,i)=>({...x,salary:String(entries[i+2]!.salaryPosition)})));
  setCapError('');setUsingOriginalLedger(true);setDirty(true);
 };
 const publishedPlayers=(team:string)=>(publishedContracts?.records??[]).filter(x=>x.team===team&&x.salaries['2026-27']>0);
 const addPublishedPlayer=(recordId:string,destinationTeam:string)=>{
  const item=publishedContracts?.records.find(x=>x.id===recordId);if(!item||drafts.some(d=>d.id==='published-'+item.id)||!participating.includes(item.team)||!participating.includes(destinationTeam)||item.team===destinationTeam)return;
  setDirty(true);
  setDrafts(prev=>[...prev,{id:'published-'+item.id,label:item.player,originTeam:item.team,
   destinationTeam,type:'player',salary:String(item.salaries['2026-27']),metadata:JSON.stringify({
    source:item.sourceLabel,dated_salary_as_of:publishedContracts?.asOf??'',guaranteed:item.guaranteed
   })}]);
 };

 const info=useMemo(()=>{
  const errors:string[]=[];
  const teams=[teamA.trim().toUpperCase(),teamB.trim().toUpperCase(),
   ...extraTeams.map(t=>t.name.trim().toUpperCase())];
  if(teams.some(x=>!x)||new Set(teams).size!==teams.length)
   errors.push('All participating teams must have distinct nonempty identifiers.');
  const salaries=[salaryA,salaryB,...extraTeams.map(t=>t.salary)].map(parseTradeAmount);
  if(salaries.some(x=>x===null))errors.push('Enter nonnegative numeric payrolls with no commas or currency symbols.');
  const assignments:TradeAssignment[]=[];
  for(const [i,d] of drafts.entries()){
   if(d.type==='tradeException'||d.type==='signingException'){
    errors.push('Asset '+(i+1)+': TPEs and signing exceptions are not transferable. Select receiving-team TPE capacity or model a player/draft asset instead.');
    continue;
   }
   const salary=parseTradeAmount(d.salary);
   if(salary===null||salary<0){errors.push('Asset '+(i+1)+' has an invalid salary.');continue}
   let metadata:Record<string,unknown>={};
   try{const parsed=JSON.parse(d.metadata||'{}');if(!parsed||Array.isArray(parsed)||typeof parsed!=='object')
    throw Error('Metadata must be an object');metadata=parsed}
   catch{errors.push('Asset '+(i+1)+' has malformed metadata JSON.');continue}
   assignments.push({asset:{id:d.id,label:d.label,originTeam:d.originTeam,
    type:d.type,salary,metadata},destinationTeam:d.destinationTeam});
  }
  if(errors.length||drafts.length===0)return {errors,scenario:null,report:null};
  const capContexts=Object.fromEntries(teams.map((team,i)=>
   [team,originalCapContext(team,salaries[i]!,capLedger,usingOriginalLedger)]));
  const scenario:TradeScenario={id:'phase3-review',name:'Review scenario',operatingSeason:'2026-27',
   teams,assignments,capContexts,asOfDateIso:asOf?asOf+'T00:00:00Z':''};
  const base=validateTrade(scenario);
  return {errors,scenario,report:reviewTeamTpes(base,scenario,selectedTpeByTeam,
   draftSource?.exceptions??[],asOf)};
 },[teamA,teamB,salaryA,salaryB,extraTeams,drafts,asOf,capLedger,usingOriginalLedger,draftSource,selectedTpeByTeam]);
 const update=(index:number,patch:Partial<RawDraft>)=>{setDirty(true);
  setDrafts(old=>old.map((d,i)=>i===index?{...d,...patch}:d))};
 const add=()=>{setDirty(true);setDrafts(old=>[...old,{id:'manual-'+crypto.randomUUID(),label:'New asset',
  originTeam:teamA,destinationTeam:teamB,type:'player',salary:'0',metadata:'{}'}])};
 return <section className="panel trade-pilot" aria-label="Trade Machine experimental model">
  <div className="panel-title"><div><p className="eyebrow">NBA / FRONT OFFICE</p>
   <h2>Trade Machine</h2><p className="subtle">Build a hypothetical 2026–27 trade using dated NBA cap, salary and draft records. Modeled checks are incomplete and do not establish CBA legality.</p></div></div>
  <div className="trade-start"><p className="subtle">{example?"Hypothetical example · illustrative teams and salaries, not NBA records.":"Select real teams, apply the dated payroll ledgers, then add assets."}</p><button onClick={()=>{setExample(false);setTeamA("");setTeamB("");setSalaryA("");setSalaryB("");setDrafts([]);setExtraTeams([]);setUsingOriginalLedger(false);setSelectedTpeByTeam({});setTpeTeam("");setPickFirst("");setPickSecond("");setSourceDraftId("");setSourceTpeId("");setSourceAssetDestination("");setAllTeamSource("");setAllTeamDestination("");setAllTeamPlayer("");setDirty(false)}}>New trade</button><button onClick={()=>{setExample(true);setDrafts(sample);setTeamA("AAA");setTeamB("BBB");setSalaryA("140000000");setSalaryB("140000000");setExtraTeams([]);setUsingOriginalLedger(false);setSelectedTpeByTeam({});setTpeTeam("");setDirty(false)}}>Reset example</button></div>
  <datalist id="trade-team-options">{publishedTeams.map(team=><option value={team} key={team}/>)}</datalist>
  <div className="trade-grid">
   <label>First team identifier<input list="trade-team-options" placeholder="Choose NBA team" aria-label="Trade first team" value={teamA} onChange={e=>{setDirty(true);setUsingOriginalLedger(false);setTeamA(e.target.value.toUpperCase())}}/></label>
   <label>First team payroll ($)<input aria-label="First team salary" inputMode="numeric" value={salaryA} onChange={e=>{setDirty(true);setUsingOriginalLedger(false);setSalaryA(e.target.value)}}/></label>
   <label>Second team identifier<input list="trade-team-options" placeholder="Choose NBA team" aria-label="Trade second team" value={teamB} onChange={e=>{setDirty(true);setUsingOriginalLedger(false);setTeamB(e.target.value.toUpperCase())}}/></label>
   <label>Second team payroll ($)<input aria-label="Second team salary" inputMode="numeric" value={salaryB} onChange={e=>{setDirty(true);setUsingOriginalLedger(false);setSalaryB(e.target.value)}}/></label>
   {extraTeams.map((team,index)=><div key={index} className="trade-extra-team">
    <label>Participating team {index+3}<input list="trade-team-options" placeholder="Choose NBA team" aria-label={'Trade team '+(index+3)}
     value={team.name} onChange={e=>{setDirty(true);setExtraTeams(xs=>xs.map((x,i)=>i===index?{...x,name:e.target.value.toUpperCase()}:x));setUsingOriginalLedger(false)}}/></label>
    <label>Team {index+3} payroll ($)<input aria-label={'Trade team '+(index+3)+' salary'}
     inputMode="decimal" value={team.salary} onChange={e=>{setDirty(true);setExtraTeams(xs=>xs.map((x,i)=>i===index?{...x,salary:e.target.value}:x));setUsingOriginalLedger(false)}}/></label>
    <button aria-label={'Remove team '+(index+3)} onClick={()=>{setDirty(true);setUsingOriginalLedger(false);setExtraTeams(xs=>xs.filter((_,i)=>i!==index))}}>Remove team {index+3}</button>
   </div>)}
   <label>As-of date<input aria-label="Trade as-of date" type="date" value={asOf} onChange={e=>{setDirty(true);setAsOf(e.target.value)}}/></label>
  </div>
  <div className="trade-actions"><button disabled={extraTeams.length>=3}
   onClick={()=>{setDirty(true);setUsingOriginalLedger(false);setExtraTeams(xs=>[...xs,{name:example?['CCC','DDD','EEE'][xs.length]:'',salary:example?'140000000':''}])}}>
   Add participating team (2–5)</button></div>
  <fieldset className="trade-published-assets"><legend>Original Flutter 2026–27 team-cap reference</legend>
   <p className="subtle">Reference contains {capLedger?.teams.length??0} source-backed cap/salary ledgers; not a live clearing feed. Payroll uses Flutter Trade Machine's salary-position total, distinct from cap ledger total. Source SHA: {capLedger?.dartSalarySourceSha256.slice(0,12)??'unavailable'}.</p>
   <button disabled={!capLedger} onClick={applyOriginalLedger}>Apply original team cap ledgers to participating teams</button>
   {usingOriginalLedger&&<p role="status">Using original Flutter dated cap ledgers and hard-cap designations. Manual payroll edits switch back to hypothetical modeling.</p>}
   {capError&&<p role="alert">Original cap reference: {capError}</p>}
  </fieldset>
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
   <div className="trade-grid">
    <label>Additional source player from team<select aria-label="Source player origin team" value={allTeamSource}
     onChange={e=>{setAllTeamSource(e.target.value);setAllTeamPlayer('')}}>
     <option value="">Choose participating team</option>
     {participating.filter(x=>publishedTeams.includes(x)).map(x=><option key={x}>{x}</option>)}
    </select></label>
    <label>Additional source player<select aria-label="Source player record" value={allTeamPlayer}
     onChange={e=>setAllTeamPlayer(e.target.value)}>
     <option value="">Choose source-backed player</option>
     {publishedPlayers(allTeamSource).map(x=><option key={x.id} value={x.id}>{x.player} · {x.salaries['2026-27'].toLocaleString()}</option>)}
    </select></label>
    <label>Destination team<select aria-label="Source player destination team" value={allTeamDestination}
     onChange={e=>setAllTeamDestination(e.target.value)}>
     <option value="">Choose receiving team</option>
     {participating.filter(x=>x&&x!==allTeamSource).map(x=><option key={x}>{x}</option>)}
    </select></label>
    <button disabled={!allTeamPlayer||!allTeamDestination||allTeamSource===allTeamDestination}
     onClick={()=>{addPublishedPlayer(allTeamPlayer,allTeamDestination);setAllTeamPlayer('')}}>Add source player to trade</button>
   </div>
   <p className="subtle">{publishedTeams.length} original source team identifiers available. All selections remain editable hypothetical assets.</p>
  </fieldset>
  <fieldset className="trade-published-assets"><legend>Original Flutter draft rights and traded-player exceptions</legend>
   <p className="subtle">{draftSource?.draftAssets.length??0} first/second-round source interests and {draftSource?.exceptions.length??0} original TPE records. The ledger is dated {draftSource?.sourceAsOf??'unavailable'}, with ownership/protection uncertainty preserved. These assets are hypothetical until independently verified.</p>
   {draftSourceError&&<p role="alert">{draftSourceError}</p>}
   <div className="trade-grid">
    <label>Source draft interest<select aria-label="Source draft interest" value={sourceDraftId}
     onChange={e=>{setSourceDraftId(e.target.value);setSourceTpeId('')}}>
     <option value="">Select dated pick/right</option>
     {publishedDraft.map(x=><option key={x.id} value={x.id} disabled={!x.tradable||x.frozen}>
      {x.team} · {x.label}{!x.tradable?' · obligated/unavailable':''}{x.frozen?' · frozen':''}{x.conditional?' · conditional':''}</option>)}
    </select></label>
    <label>Team using exception to acquire player<select aria-label="TPE receiving team"
     value={tpeTeam} onChange={e=>{setTpeTeam(e.target.value);setSourceTpeId('')}}>
     <option value="">Choose receiving team</option>
     {participating.filter(Boolean).map(x=><option key={x}>{x}</option>)}
    </select></label>
    <label>Source traded-player exception<select aria-label="Source trade exception" value={sourceTpeId}
     onChange={e=>setSourceTpeId(e.target.value)}>
     <option value="">Select dated TPE</option>
     {publishedTpes.filter(x=>x.team===tpeTeam).map(x=><option key={x.id} value={x.id} disabled={x.available<=0||x.expires<asOf}>
      {x.sourceTransaction} · {'$'}{x.available.toLocaleString()} · expires {x.expires}</option>)}
    </select></label>
    <label>Source asset receiving team<select aria-label="Source asset receiving team" value={sourceAssetDestination}
     onChange={e=>setSourceAssetDestination(e.target.value)}>
     <option value="">Choose participating team</option>
     {participating.filter(Boolean).map(x=><option key={x}>{x}</option>)}
    </select></label>
    <button disabled={!sourceDraftId||!sourceAssetDestination||
     publishedDraft.find(x=>x.id===sourceDraftId)?.team===sourceAssetDestination}
     onClick={routeSourceDraft}>Add source draft interest</button>
    <button disabled={!sourceTpeId||!tpeTeam}
     onClick={chooseReceivingTpe}>Use TPE for receiving team</button>
    <button disabled={!tpeTeam||!selectedTpeByTeam[tpeTeam]} onClick={()=>{
     setSelectedTpeByTeam(prev=>{const next={...prev};delete next[tpeTeam];return next})}}>
     Clear receiving team TPE</button>
   </div>
   <p className="subtle">A traded-player exception is a receiving-team acquisition mechanism; it is never transferred to another team. This modeled TPE review is not a legal CBA authorization.</p>
   {participating.filter(x=>selectedTpeByTeam[x]).map(team=><p key={team} className="subtle">
    {team} models acquisition with {publishedTpes.find(x=>x.id===selectedTpeByTeam[team])?.sourceTransaction??'unavailable source exception'}.
   </p>)}
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
   <button disabled={!teamA||!teamB} onClick={add}>Add asset</button>
   <button onClick={()=>setDetails(x=>!x)} aria-expanded={details}>Show modeled validation details</button>
  </div>
  {!drafts.length&&<p className="subtle trade-empty">No assets assigned. Add source-backed players or picks to begin a trade scenario.</p>}
  {dirty&&info.errors.length>0&&<div role="alert">{info.errors.join(' ')}</div>}
  {info.report&&<div className="trade-results" aria-label="Modeled validation results">
   <p role="status">{info.report.isValid?'No modeled blocking errors':'Modeled transaction has blocking errors'} · {info.report.errorCount} errors · {info.report.warningCount} warnings{example?' · illustrative example':' · hypothetical scenario'}</p>
   <div className="table-scroll"><table className="stats-table"><thead><tr><th>Team</th><th>Outgoing matching</th><th>Incoming matching</th><th>Post-trade payroll</th><th>Max incoming</th><th>Projected roster</th><th>Apron</th></tr></thead>
    <tbody>{Object.values(info.report.teamSummaries).map(t=><tr key={t.team}><td>{t.team}</td>
     <td>{t.outgoingSalary.toLocaleString()}</td><td>{t.incomingSalary.toLocaleString()}</td>
     <td>{t.postTradeSalary.toLocaleString()}</td><td>{Number.isFinite(t.maximumIncomingSalary)?t.maximumIncomingSalary.toLocaleString():'No finite modeled limit'}</td>
     <td>{t.projectedRosterPlayers}</td><td>{t.apronStatus}</td></tr>)}</tbody></table></div>
   {details&&<div aria-label="CBA findings">{info.report.findings.length?info.report.findings.map((f,i)=>
    <p key={i}><strong>{f.severity.toUpperCase()} · {f.code}</strong> · {f.team??'Scenario'}: {f.message}</p>):
    <p>No findings on this modeled scenario.</p>}</div>}
  </div>}
  <p className="table-note">Dated source inputs, not live clearing data. Full draft conveyance, Stepien eligibility, exception use and CBA coverage remain incomplete; the original Flutter reference remains available.</p>
 </section>;
}
