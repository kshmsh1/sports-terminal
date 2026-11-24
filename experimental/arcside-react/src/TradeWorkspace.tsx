
import {useEffect,useMemo,useState} from 'react';
import {getDatedContracts,getOriginalTeamCapLedger,getOriginalDraftExceptions} from './data';
import type {DatedContractSnapshot,TeamCapLedgerSnapshot,OriginalDraftExceptions} from './data';
import type {TeamFinancialReport} from './FinancialsWorkspace';
import type {TradeAsset,TradeAssignment} from './tradeEngine';
import {TradeMachinePilot,parseTradeAmount} from './TradeMachinePilot';
import {nbaTeams,canonicalTeam,nameForTeam,sameTeam,capTier,playerFlags,playerAsset,draftAsset,buildSourceScenario,evaluateSourceTrade,twoWayAsset,rightAsset,signAndTradeAsset,person} from './TradeWorkspaceModel';
import type {TradeContext} from './TradeWorkspaceModel';
import {convertLegacyTrades} from './legacyTradeMigration';

type Sources={contracts:DatedContractSnapshot;ledger:TeamCapLedgerSnapshot;draft:OriginalDraftExceptions;financial:TeamFinancialReport;context:TradeContext};
type Mode='on'|'off'|'deadline';
type SavedTrade={id:string;savedAt:string;teams:string[];date:string;mode:Mode;routes:{id:string;origin:string;destination:string;salary:number}[];tpes:Record<string,string>;renounced?:string[]};
const savedKey='arcside.react.trade.snapshots.v1';
const loadSaved=():SavedTrade[]=>{try{const raw=JSON.parse(localStorage.getItem(savedKey)??'[]');return Array.isArray(raw)?raw.filter(x=>x&&typeof x.id==='string'&&Array.isArray(x.teams)&&Array.isArray(x.routes)&&typeof x.date==='string'&&typeof x.savedAt==='string'):[]}catch{return []}};
type AssetTab='Active roster'|'Draft picks'|'Draft rights'|'Cash'|'Free agents'|'Exceptions';
const tabs:AssetTab[]=['Active roster','Draft picks','Draft rights','Cash','Free agents','Exceptions'];
const money=(n:number|null|undefined)=>n==null||!Number.isFinite(n)?'—':(n<0?'−':'')+'$'+Math.abs(n).toLocaleString('en-US',{maximumFractionDigits:0});
const compact=(n:number|null|undefined)=>n==null||!Number.isFinite(n)?'—':(n<0?'−':'')+'$'+(Math.abs(n)>=1e6?(Math.abs(n)/1e6).toFixed(2)+'M':Math.abs(n)>=1e3?(Math.abs(n)/1e3).toFixed(0)+'K':Math.abs(n).toFixed(0));
const signed=(n:number)=>n>0?'+'+compact(n):compact(n);
const capClass=(n:number)=>n<0?'trade-negative':n>0?'trade-positive':'';
const hardLabel=(v:string|null)=>v==='first'?'1st Apron':v==='second'?'2nd Apron':v===null?'None':'Unknown';
const exceptionNames:Record<string,string>={room_mle:'Room MLE',non_tax_mle:'Non-Tax MLE',tax_mle:'Tax MLE',bae:'Bi-Annual'};
const sourceJson=async<T,>(url:string,signal:AbortSignal):Promise<T>=>{
 const response=await fetch(url,{signal,credentials:'same-origin'});
 if(!response.ok)throw Error('Source unavailable: '+url+' ('+response.status+')');
 return response.json() as Promise<T>;
};
function Badge({team}:{team:string}){return <span className={'trade-team-badge trade-team-'+team.toLowerCase()} aria-hidden="true">{team}</span>}
export function TradeWorkspace(){
 const [sources,setSources]=useState<Sources|null>(null),[error,setError]=useState(''),[reload,setReload]=useState(0);
 const [teams,setTeams]=useState<string[]>([]),[active,setActive]=useState(''),[stage,setStage]=useState<'pick'|'build'|'recent'|'manual'>('pick');
 const [conference,setConference]=useState('All teams'),[tab,setTab]=useState<AssetTab>('Active roster');
 const [query,setQuery]=useState(''),[routedOnly,setRoutedOnly]=useState(false);
 const [date,setDate]=useState('2026-09-30'),[assignments,setAssignments]=useState<TradeAssignment[]>([]);
 const [tpes,setTpes]=useState<Record<string,string>>({}),[pending,setPending]=useState<TradeAsset|null>(null),[destination,setDestination]=useState('');
 const [renounced,setRenounced]=useState<string[]>([]);
 const [mode,setMode]=useState<Mode>('on'),[position,setPosition]=useState('All'),[saved,setSaved]=useState<SavedTrade[]>(loadSaved),[signSalary,setSignSalary]=useState<Record<string,string>>({});
 const effectiveDate=mode==='deadline'?'2027-02-04':date;
 const [importText,setImportText]=useState('');
 const [cashAmount,setCashAmount]=useState(''),[addTeam,setAddTeam]=useState(''),[notice,setNotice]=useState('');
 useEffect(()=>{
  const controller=new AbortController();setError('');setSources(null);
  Promise.all([getDatedContracts(controller.signal),getOriginalTeamCapLedger(controller.signal),
   getOriginalDraftExceptions(controller.signal),
   sourceJson<TeamFinancialReport>('/data/phase3/2026-27-team-financials.json',controller.signal),
   sourceJson<TradeContext>('/data/phase3/2026-27-trade-context.json',controller.signal)])
   .then(([contracts,ledger,draft,financial,context])=>{
    if(controller.signal.aborted)return;
    if(!contracts||financial.kind!=='ARCSIDE_ORIGINAL_FLUTTER_TEAM_FINANCIALS_2026_27_V1'||financial.teams.length!==30||
     context.kind!=='ARCSIDE_DATED_TRADE_CONTEXT_V1'||context.cash.length!==30||!Array.isArray(context.rights)||!Array.isArray(context.freeAgents)||
     nbaTeams.some(([team])=>!ledger.teams.some(x=>sameTeam(x.team,team))||!financial.teams.some(x=>sameTeam(x.team,team))||!context.cash.some(x=>sameTeam(x.team,team))))
     throw Error('Incomplete source-backed 30-team trade context');
    setSources({contracts,ledger,draft,financial,context});
   }).catch(e=>{if(!controller.signal.aborted)setError(String(e.message??e))});
  return ()=>controller.abort();
 },[reload]);
 const current=sources?.financial.teams.find(x=>sameTeam(x.team,active));
 const ledger=sources?.ledger.teams.find(x=>sameTeam(x.team,active));
 const cash=sources?.context.cash.find(x=>sameTeam(x.team,active));
 const roster=useMemo(()=>sources?.contracts.records.filter(x=>sameTeam(x.team,active)).sort((a,b)=>b.salaries['2026-27']-a.salaries['2026-27'])??[],[sources,active]);
 const picks=useMemo(()=>sources?.draft.draftAssets.filter(x=>sameTeam(x.team,active)).sort((a,b)=>a.year-b.year||a.round-b.round)??[],[sources,active]);
 const activeTpes=sources?.draft.exceptions.filter(x=>sameTeam(x.team,active))??[];
 const twoWays=sources?.context.twoWays.filter(x=>sameTeam(x.team,active)&&!roster.some(p=>person(p.player)===person(x.player)))??[];
 const rights=sources?.context.rights.filter(x=>sameTeam(x.team,active))??[],freeAgents=sources?.context.freeAgents.filter(x=>sameTeam(x.team,active))??[];
 const sourceScenario=useMemo(()=>{
  if(!sources)return null;
  const modeled=mode==='off'?assignments.map(a=>({...a,asset:{...a.asset,metadata:{...a.asset.metadata,trade_restricted_until:undefined,trade_restricted:false}}})):assignments;
  return buildSourceScenario(teams,modeled,effectiveDate,sources.ledger.teams,sources.financial.teams,sources.context);
 },[sources,teams,assignments,effectiveDate,mode]);
 const report=useMemo(()=>sourceScenario&&sources&&assignments.length?evaluateSourceTrade(sourceScenario,sources.context,tpes,sources.draft.exceptions,effectiveDate):null,[sourceScenario,sources,tpes,effectiveDate,assignments.length]);
 const canRoute=(asset:TradeAsset)=>!assignments.some(x=>x.asset.id===asset.id)&&teams.includes(asset.originTeam);
 function selectTeam(team:string){
  setTeams(prev=>prev.includes(team)?prev.filter(x=>x!==team):prev.length<5?[...prev,team]:prev);
 }
 function viewTeam(team:string){setActive(team);setTab('Active roster');setQuery('');setPosition('All');setPending(null);setNotice('')}
 function clearRoutes(){setAssignments([]);setTpes({});setRenounced([]);setPending(null);setNotice('');setCashAmount('')}
 function removeTeam(team:string){
  if(teams.length<=2)return;
  const next=teams.filter(x=>x!==team);setTeams(next);
  setAssignments(prev=>prev.filter(x=>x.asset.originTeam!==team&&x.destinationTeam!==team));
  const remaining=assignments.filter(x=>x.asset.originTeam!==team&&x.destinationTeam!==team);
  setTpes(prev=>Object.fromEntries(Object.entries(prev).filter(([id])=>remaining.some(a=>a.asset.id===id))));
  setRenounced(prev=>prev.filter(id=>!sources?.context.freeAgents.some(x=>x.id===id&&sameTeam(x.team,team))));
  setPending(null);if(active===team)viewTeam(next[0]);setNotice('Removed team and its related routes.');
 }
 function removeRoute(id:string){setAssignments(prev=>prev.filter(x=>x.asset.id!==id));setTpes(prev=>Object.fromEntries(Object.entries(prev).filter(([key])=>key!==id)))}
 function route(asset:TradeAsset){
  if(!canRoute(asset))return;
  setPending(asset);setDestination(teams.find(x=>x!==asset.originTeam)??'');setNotice('');
 }
 function confirmRoute(){
  if(!pending||!teams.includes(destination)||destination===pending.originTeam||!canRoute(pending))return;
  const until=pending.metadata?.trade_restricted_until;
  if(mode!=='off'&&typeof until==='string'&&effectiveDate<until){setNotice('This player is restricted for the selected scenario date.');return}
  setAssignments(prev=>[...prev,{asset:pending,destinationTeam:destination}]);setPending(null);setNotice(pending.label+' routed to '+destination);
 }
 const addCash=()=>{
  const amount=parseTradeAmount(cashAmount);
  if(!amount||!cash||amount>cash.availableToSend){setNotice('Enter a positive amount within the dated sending limit.');return}
  route({id:'cash:'+active,type:'cash',label:'Cash considerations',originTeam:active,salary:amount,metadata:{amount}});
 };
 function persistSaved(next:SavedTrade[]){
  try{localStorage.setItem(savedKey,JSON.stringify(next));setSaved(next);return true}catch{setNotice('Local trade snapshot could not be stored.');return false}
 }
 function saveTrade(){
  if(!assignments.length||!sourceScenario)return;
  const entry:SavedTrade={id:crypto.randomUUID(),savedAt:new Date().toISOString(),teams:[...teams],date,mode,
   routes:assignments.map(a=>({id:a.asset.id,origin:a.asset.originTeam,destination:a.destinationTeam,salary:a.asset.salary})),tpes:{...tpes},renounced:[...renounced]};
  if(persistSaved([entry,...saved].slice(0,40)))setNotice('Trade snapshot saved to Recent Trades.');
 }
 function importLegacy(raw:string){
  if(!sources)return;
  try{
   let parsed:unknown=JSON.parse(raw);if(typeof parsed==='string')parsed=JSON.parse(parsed);
   if(!Array.isArray(parsed)||parsed.length>100)throw Error('Expected an array of at most 100 Flutter snapshots.');
   const library=[...sources.contracts.records.map(x=>playerAsset(x,sources.context)),...sources.draft.draftAssets.filter(x=>x.tradable&&!x.frozen).map(draftAsset),...sources.context.twoWays.map(twoWayAsset),...sources.context.rights.map(rightAsset)];
   const result=convertLegacyTrades(parsed,library,sources.context,sources.draft.exceptions);
   if(!result.trades.length){setNotice('No compatible snapshots imported. '+result.rejected.join(' '));return}
   const merged=[...result.trades.filter(x=>!saved.some(s=>s.id===x.id)),...saved].slice(0,40);
   if(persistSaved(merged))setNotice(result.trades.length+' compatible snapshot(s) processed; '+result.rejected.length+' rejected. '+result.rejected.join(' '));
  }catch(e){setNotice('Import rejected: '+String(e instanceof Error?e.message:e))}
 }
 function restoreTrade(entry:SavedTrade){
  if(!sources)return;
  if(!entry||!Array.isArray(entry.teams)||!entry.teams.every(t=>typeof t==='string')||!Array.isArray(entry.routes)||!/^202[67]-\d{2}-\d{2}$/.test(entry.date)){setNotice('Invalid saved trade format.');return}
  const restoredTeams=entry.teams.map(canonicalTeam);
  if(restoredTeams.length<2||restoredTeams.length>5||new Set(restoredTeams).size!==restoredTeams.length||restoredTeams.some(t=>!nbaTeams.some(x=>x[0]===t))){setNotice('Invalid saved team selection.');return}
  const library=[...sources.contracts.records.map(x=>playerAsset(x,sources.context)),...sources.draft.draftAssets.filter(x=>x.tradable&&!x.frozen).map(draftAsset),
   ...sources.context.twoWays.map(twoWayAsset),...sources.context.rights.map(rightAsset)];
  const restored:TradeAssignment[]=[];
  for(const a of entry.routes){
   if(!a||!restoredTeams.includes(a.origin)||!restoredTeams.includes(a.destination)||a.origin===a.destination||restored.some(x=>x.asset.id===a.id)){setNotice('Saved route is invalid; nothing was loaded.');return}
   let asset:TradeAsset|null|undefined=library.find(x=>x.id===a.id&&x.originTeam===a.origin);
   if(!asset&&a.id==='cash:'+a.origin&&Number.isFinite(a.salary)&&a.salary>0){
    const c=sources.context.cash.find(x=>sameTeam(x.team,a.origin));if(c&&a.salary<=c.availableToSend)asset={id:a.id,type:'cash',originTeam:a.origin,label:'Cash considerations',salary:a.salary,metadata:{amount:a.salary}};
   }
   if(!asset){const f=sources.context.freeAgents.find(x=>x.id===a.id&&sameTeam(x.team,a.origin));if(f)asset=signAndTradeAsset(f,a.salary)}
   if(!asset){setNotice('Saved asset no longer matches the published source; nothing was loaded.');return}
   restored.push({asset,destinationTeam:a.destination});
  }
  const validTpes=Object.fromEntries(Object.entries(entry.tpes??{}).filter(([asset,id])=>restored.some(a=>a.asset.id===asset&&sources.draft.exceptions.some(x=>x.id===id&&sameTeam(x.team,a.destinationTeam)))));
  setRenounced((Array.isArray(entry.renounced)?entry.renounced:[]).filter(id=>sources.context.freeAgents.some(x=>x.id===id&&restoredTeams.includes(canonicalTeam(x.team)))&&!restored.some(a=>a.asset.id===id)));
  setTeams(restoredTeams);setDate(entry.date);setMode(['on','off','deadline'].includes(entry.mode)?entry.mode:'on');setAssignments(restored);setTpes(validTpes);viewTeam(restoredTeams[0]);setStage('build');setNotice('Saved scenario reopened against the current dated source.');
 }
 const positionFor=(name:string)=>sources?.context.positions[name]??sources?.context.twoWays.find(x=>person(x.player)===person(name)&&sameTeam(x.team,active))?.position??'Unknown';
 const filtered=(label:string,id:string)=>label.toLowerCase().includes(query.trim().toLowerCase())&&(!routedOnly||assignments.some(x=>x.asset.id===id));
 const routeButton=(asset:TradeAsset,blocked=false)=>{
  const existing=assignments.find(x=>x.asset.id===asset.id);
  return existing?<button className="trade-route-button" onClick={()=>removeRoute(asset.id)} aria-label={'Remove route for '+asset.label}>→ {existing.destinationTeam} · Remove</button>:
   <button className="trade-route-button" disabled={blocked||!canRoute(asset)} onClick={()=>route(asset)} aria-label={'Route '+asset.label}>{blocked?'Restricted':'→ Route'}</button>;
 };
 return <section className="trade-workspace" aria-label="NBA Trade Machine">
  {stage!=='manual'&&<h2 className="trade-product-heading">Trade Machine</h2>}
  <div className="trade-product-nav" role="group" aria-label="Trade views">
   <button className={stage==='pick'||stage==='build'?'selected':''} aria-pressed={stage==='pick'||stage==='build'} onClick={()=>setStage(active&&teams.includes(active)?'build':'pick')}>Build a Trade</button>
   <button className={stage==='recent'?'selected':''} aria-pressed={stage==='recent'} onClick={()=>setStage('recent')}>Recent Trades{saved.length?' '+saved.length:''}</button>
   <button className={stage==='manual'?'selected':''} aria-pressed={stage==='manual'} onClick={()=>setStage('manual')}>Advanced scenario editor</button>
  </div>
  {stage==='manual'?<TradeMachinePilot/>:error?<div className="panel trade-source-error" role="alert">{error} <button onClick={()=>setReload(x=>x+1)}>Retry source load</button></div>:!sources?<p role="status" className="loading">Loading dated NBA trade sources…</p>:<>
   {stage==='recent'&&<section className="panel trade-history"><div className="panel-title"><div><h2>Recent Trades</h2><p className="subtle">Your browser-local modeled trade snapshots.</p></div></div>
    <details className="trade-source-detail"><summary>Import original Flutter saved trades</summary><p>Read the same-origin Flutter SharedPreferences key, or paste its exported JSON. Original browser storage is never modified. All routes are revalidated against dated sources.</p><button onClick={()=>{try{const raw=localStorage.getItem('flutter.sports_terminal.trade_machine.saved_trades.v2')??localStorage.getItem('sports_terminal.trade_machine.saved_trades.v2');if(raw)importLegacy(raw);else setNotice('No Flutter snapshots found at this browser origin; paste an exported JSON array below.')}catch{setNotice('Browser storage unavailable.')}}}>Import from browser storage</button><label>Flutter snapshot JSON<textarea aria-label="Flutter snapshot JSON" value={importText} onChange={e=>setImportText(e.target.value)} rows={4}/></label><button disabled={!importText.trim()} onClick={()=>importLegacy(importText)}>Import JSON</button></details>
    {saved.length?saved.map(entry=><article key={entry.id}><small>{entry.savedAt.slice(0,10)} · {entry.mode}</small><h3>{entry.teams.map(nameForTeam).join(' / ')}</h3><p>{entry.routes.length} routed assets</p><div className="row-wrap"><button onClick={()=>restoreTrade(entry)}>Open snapshot</button><button onClick={()=>persistSaved(saved.filter(x=>x.id!==entry.id))}>Delete snapshot</button></div></article>):<p className="trade-inner subtle">No saved trades yet. Build a trade and save a snapshot.</p>}
    {notice&&<p role="status" className="trade-inner">{notice}</p>}
    <div className="panel-title"><div><h3>Published transaction reference</h3><p className="subtle">Original user-supplied 2026 offseason records; not a live feed.</p></div></div>
    {sources.context.transactions.map((t,i)=><article key={i}><small>{t.date} · {t.teams.join(' / ')}</small><p>{t.summary}</p></article>)}</section>}
   {stage==='pick'&&<section className="panel trade-team-selection">
    <div className="trade-select-toolbar"><label>Season<select aria-label="Trade season" value="2026-27" onChange={()=>{}}><option>2026-27</option></select></label>
     <div className="trade-segment" role="group" aria-label="Conference">{['All teams','East','West'].map(c=><button key={c} aria-pressed={conference===c} onClick={()=>setConference(c)} className={conference===c?'selected':''}>{c}</button>)}</div>
     <span className="subtle trade-selection-count">{teams.length<2?'Select at least 2 teams':teams.length+' teams selected'}</span>
     <button disabled={!teams.length} onClick={()=>{setTeams([]);setActive('');clearRoutes()}}>Clear</button>
     <button className="trade-primary" disabled={teams.length<2} onClick={()=>{clearRoutes();viewTeam(teams[0]);setStage('build')}}>→ Build a Trade</button>
    </div>
    <div className="trade-team-grid">{nbaTeams.filter(t=>conference==='All teams'||t[2]===conference).map(([team,name])=>{
     const l=sources.ledger.teams.find(x=>sameTeam(x.team,team))!,f=sources.financial.teams.find(x=>sameTeam(x.team,team));
     const selected=teams.includes(team);return <button key={team} className={'trade-team-card'+(selected?' selected':'')} disabled={!selected&&teams.length===5}
      aria-pressed={selected} aria-label={name} onClick={()=>selectTeam(team)}><Badge team={team}/><span><strong>{name}</strong><small>{capTier(l,f)}</small></span><span className="trade-team-action">{selected?'✓':'+'}</span></button>;
    })}</div>
    <p className="subtle">Select 2–5 teams. Cap status is derived from dated 2026–27 source ledgers, not live NBA payroll.</p>
   </section>}
   {stage==='build'&&current&&ledger&&<div className="trade-builder">
    <div className="trade-builder-toolbar">
     <div className="trade-team-tabs" role="group" aria-label="Participating teams">{teams.map(t=><div key={t} className="trade-team-tab-wrap"><button aria-pressed={active===t} className={active===t?'selected':''} onClick={()=>viewTeam(t)}><Badge team={t}/>{t}</button>{teams.length>2&&<button className="trade-remove-team" aria-label={'Remove '+t} onClick={()=>removeTeam(t)}>×</button>}</div>)}
     {teams.length<5&&<label className="trade-add-team"><select aria-label="Add participating NBA team" value={addTeam} onChange={e=>{const t=e.target.value;if(t&&!teams.includes(t)){setTeams(prev=>[...prev,t]);setAddTeam('')}}}><option value="">+ Add team</option>{nbaTeams.filter(t=>!teams.includes(t[0])).map(t=><option key={t[0]} value={t[0]}>{t[1]}</option>)}</select></label>}</div>
     <div className="trade-segment" role="group" aria-label="Trade restriction mode">{(['on','off','deadline'] as const).map(m=><button key={m} aria-pressed={mode===m} onClick={()=>{setMode(m);setPending(null)}}>{m==='on'?'On · Restrictions':m==='off'?'Off · Hypothetical':'Deadline · Trade mode'}</button>)}</div>
     <label>Scenario date<input aria-label="Scenario date" disabled={mode==='deadline'} type="date" min="2026-07-01" max="2027-06-30" value={date} onChange={e=>setDate(e.target.value)}/></label>
     <label className="check"><input type="checkbox" checked={routedOnly} onChange={e=>setRoutedOnly(e.target.checked)}/>Routed only</label>
     <button onClick={clearRoutes}>Reset routes</button><button onClick={()=>{clearRoutes();setStage('pick');setActive('')}}>Team selection</button>
    </div>
    <div className="trade-view-strip"><Badge team={active}/><strong>Viewing {nameForTeam(active)}</strong><span>· {tab} · Salary snapshot {sources.contracts.asOf} · Scenario {effectiveDate}</span><span className="trade-view-count">{assignments.length} assets routed</span></div>
    {mode==='off'&&<p role="status" className="trade-inner trade-mode-warning">Hypothetical restrictions-off mode: dated player eligibility checks bypassed. Not a legal trade result.</p>}
    <div className="trade-fin-heading"><strong>{nameForTeam(active)} financial position</strong><small>2026–27 · Team Summary {sources.financial.sourceAsOf}</small></div>
    <div className="trade-fin-grid">{[
     ['Operating As',capTier(ledger,current),''],['Cap Space',signed(current.capSpace),capClass(current.capSpace)],
     ['Tax Space',signed(current.taxSpace),capClass(current.taxSpace)],['1st Apron Space',signed(current.firstApronSpace),capClass(current.firstApronSpace)],
     ['2nd Apron Space',signed(current.secondApronSpace),capClass(current.secondApronSpace)],['Hard Cap',hardLabel(current.hardCap),''],
     ['Available Exceptions',Object.entries(current.availableExceptions).map(([k,v])=>(exceptionNames[k]??k)+': '+compact(v)).join(' · ')||'None listed',''],
     ['Largest TPE',current.largestTpe==null?'None listed':compact(current.largestTpe)+' · exp '+(current.largestTpeExpires??'—'),'']
    ].map(([label,value,cls])=><div className="trade-fin-card" key={label}><small>{label}</small><strong className={cls}>{value}</strong></div>)}</div>
    <div className="trade-builder-grid">
     <section className="trade-board" aria-label="Team asset library">
      <div className="trade-asset-tabs" role="group" aria-label="Asset category">{tabs.map(t=><button key={t} className={tab===t?'selected':''} aria-pressed={tab===t} onClick={()=>{setTab(t);setQuery('')}}>{t}{t==='Active roster'?' '+(roster.length+twoWays.length):t==='Draft picks'?' '+picks.length:''}</button>)}</div>
      {(tab==='Active roster'||tab==='Draft picks'||tab==='Free agents'||tab==='Draft rights')&&<div className="trade-asset-search"><input aria-label="Search trade assets" placeholder={tab==='Active roster'?'Search players…':'Search picks…'} value={query} onChange={e=>setQuery(e.target.value)}/>{tab==='Active roster'&&<select aria-label="Trade roster position" value={position} onChange={e=>setPosition(e.target.value)}>{['All','PG','SG','SF','PF','C','G','F','Unknown'].map(pos=><option key={pos} value={pos}>{pos==='All'?'All positions':pos}</option>)}</select>}</div>}
      {tab==='Active roster'&&<><div className="trade-roster-scroll"><table className="trade-roster"><thead><tr><th scope="col">Player</th><th scope="col">2026–27 salary</th><th scope="col">Contract / guarantee</th><th scope="col">Flags / route</th></tr></thead><tbody>
       {roster.filter(p=>filtered(p.player,p.id)&&(position==='All'||positionFor(p.player)===position)).map(p=>{
        const flags=playerFlags(p,sources.context),asset=playerAsset(p,sources.context),blocked=mode!=='off'&&!!flags.restriction&&effectiveDate<flags.restriction.eligibleDate;
        return <tr key={p.id} className={blocked?'trade-restricted':''}><td><div className="trade-player-name"><span aria-hidden="true">{p.player.split(' ').map(x=>x[0]).slice(0,2).join('')}</span><div><strong>{p.player}</strong>{blocked&&<small>Restricted until {flags.restriction?.eligibleDate}</small>}</div></div></td>
         <td title={money(asset.salary)}>{compact(asset.salary)}</td><td>{flags.partial?'Protected '+compact(flags.partial.amount):p.guaranteed!=null?compact(p.guaranteed)+' guaranteed':'Guarantee unavailable'}</td>
         <td><div className="trade-flags">{flags.kicker&&<small>Trade kicker {flags.kicker.percent}%</small>}{flags.restriction?.veto&&<small>Consent required</small>}{flags.twoWay&&<small>Two-way</small>}{routeButton(asset,blocked)}</div></td></tr>;
       })}
       {twoWays.filter(p=>filtered(p.player,twoWayAsset(p).id)&&(position==='All'||p.position===position)).map(p=>{const asset=twoWayAsset(p);return <tr key={asset.id}><td>{p.player} · {p.position}</td><td>Two-way</td><td>Signed {p.signedDate}</td><td>{routeButton(asset)}</td></tr>})}
      </tbody></table></div>{!roster.some(p=>filtered(p.player,p.id)&&(position==='All'||positionFor(p.player)===position))&&!twoWays.some(p=>filtered(p.player,twoWayAsset(p).id)&&(position==='All'||p.position===position))&&<p className="empty">No matching dated contracts.</p>}
      <p className="trade-source-detail">Positions are limited to the original published position reference; unknown positions are not inferred. Two-way assets are excluded from standard salary matching and require separate eligibility review.</p></>}
      {tab==='Draft picks'&&<div className="trade-draft-list">{picks.filter(p=>filtered(p.label+' '+p.description,p.id)).map(p=><article key={p.id} className={!p.tradable||p.frozen?'trade-restricted':''}><div><strong>{p.year}, Round {p.round}: {p.label}</strong><p>{p.description}</p><div className="trade-flags">{p.conditional&&<small>Conditional</small>}{p.swapRight&&<small>Swap</small>}{p.protection&&<small>{p.protection}</small>}</div></div>{routeButton(draftAsset(p),!p.tradable||p.frozen)}</article>)}
       {!picks.some(p=>filtered(p.label+' '+p.description,p.id))&&<p className="empty">No matching published draft interests.</p>}</div>}
      {tab==='Cash'&&<div className="trade-inner"><h3>Cash considerations</h3><p>Available to send: {money(cash?.availableToSend)} · Available to receive: {money(cash?.availableToReceive)}</p>
       <label>Cash amount ($)<input aria-label="Cash amount" inputMode="decimal" value={cashAmount} onChange={e=>setCashAmount(e.target.value)}/></label><button disabled={!cash||assignments.some(x=>x.asset.id==='cash:'+active)} onClick={addCash}>Route cash</button>
       {cash?.restricted&&<p className="trade-negative">Source reports a second-apron cash-sending restriction; modeled checks apply.</p>}</div>}
      {tab==='Exceptions'&&<div className="trade-inner"><h3>Receiving-team traded-player exceptions</h3><p className="subtle">Assign an exception to a routed incoming player in the trade flow. Exceptions are never transferred.</p>{activeTpes.map(t=><article className="trade-free-agent" key={t.id}><strong>{t.sourceTransaction} · {money(t.available)}</strong><p className="subtle">Expires {t.expires} · {t.available<=0?'Exhausted':t.expires<effectiveDate?'Expired':'Dated capacity'}</p></article>)}{!activeTpes.length&&<p className="empty">No published exceptions for {active}.</p>}</div>}
      {tab==='Draft rights'&&<div className="trade-draft-list">{rights.filter(p=>filtered(p.player,p.id)).map(p=><article key={p.id}><div><strong>{p.player} (draft rights)</strong><p>{p.position} · {p.note}</p></div>{routeButton(rightAsset(p))}</article>)}{!rights.length&&<p className="empty">No source-certified draft-rights records for {active}.</p>}</div>}
      {tab==='Free agents'&&<div className="trade-inner">{freeAgents.filter(p=>filtered(p.player,p.id)).map(p=>{
       const amount=parseTradeAmount(signSalary[p.id]??String(p.minimum??'')),asset=amount===null?null:signAndTradeAsset(p,amount),isRenounced=renounced.includes(p.id);
       return <article className="trade-free-agent" key={p.id}><strong>{p.player}</strong><p className="subtle">{p.position} · {p.rights} · Cap hold {money(p.capHold)}</p>
        <button onClick={()=>{if(isRenounced)setRenounced(prev=>prev.filter(id=>id!==p.id));else{removeRoute(p.id);setRenounced(prev=>[...prev,p.id])}}}>{isRenounced?'Restore cap hold':'Renounce hold'}</button>
        {isRenounced?<p className="subtle">Modeled cap hold renounced. No trade route.</p>:p.minimum!==null&&p.maximum!==null?<><label>Sign-and-trade salary ($)<input aria-label={p.player+' sign-and-trade salary'} inputMode="decimal" value={signSalary[p.id]??String(p.minimum)} onChange={e=>setSignSalary(prev=>({...prev,[p.id]:e.target.value}))}/></label>
         <p className="subtle">Published modeled range: {money(p.minimum)}–{money(p.maximum)}</p>{asset?routeButton(asset):<p role="alert">Enter a salary within the published range.</p>}</>:<p className="subtle">No verified sign-and-trade salary range.</p>}</article>
      })}{!freeAgents.length&&<p className="empty">No source-certified free-agent rights for {active}.</p>}<p className="subtle">Sign-and-trade modeling does not establish signing eligibility. Renounced holds affect only the illustrative cap-room display, matching the original video workflow, not the modeled apron ledger.</p></div>}
     </section>
     <section className="trade-board trade-flow" aria-label="Trade flow">
      {pending&&<div className="trade-route-dialog" role="group" aria-label="Route selected asset"><h3>Route {pending.label}</h3><p className="subtle">{pending.originTeam} · {pending.type==='draftPick'?'Draft interest':money(pending.salary)}</p>
       <label>Destination<select aria-label="Trade destination" value={destination} onChange={e=>setDestination(e.target.value)}>{teams.filter(x=>x!==pending.originTeam).map(t=><option key={t} value={t}>{nameForTeam(t)}</option>)}</select></label>
       <div className="row-wrap"><button className="trade-primary" onClick={confirmRoute}>Confirm route</button><button onClick={()=>setPending(null)}>Cancel</button></div></div>}
      {!assignments.length&&!pending&&<div className="trade-flow-empty"><span aria-hidden="true">⇄</span><h3>Start building the trade</h3><p>Choose an asset, set its destination, then review the modeled checks.</p><div><small>1 · Choose an asset</small><small>2 · Set destination</small><small>3 · Resolve blockers</small></div></div>}
      {!!assignments.length&&<><div className="trade-inner"><div className="row-wrap trade-flow-heading"><h3>Trade flow · {assignments.length} assets</h3><button disabled={!sourceScenario} onClick={saveTrade}>Save snapshot</button></div>{teams.map(t=><article className="trade-flow-team" key={t}><h4><Badge team={t}/>{nameForTeam(t)}</h4>
       {['Outgoing','Incoming'].map(direction=><div key={direction}><small>{direction}</small>{assignments.filter(x=>direction==='Outgoing'?x.asset.originTeam===t:x.destinationTeam===t).map(x=><div className="trade-flow-row" key={x.asset.id}><span>{x.asset.label} <small>{x.asset.originTeam} → {x.destinationTeam}</small></span><strong>{x.asset.type==='draftPick'?'Pick':x.asset.type==='draftRights'?'Rights':x.asset.metadata?.two_way?'Two-way':compact(x.asset.salary)}</strong>{direction==='Outgoing'&&<button aria-label={'Remove '+x.asset.label} onClick={()=>removeRoute(x.asset.id)}>×</button>}{direction==='Incoming'&&x.asset.type==='player'&&!x.asset.metadata?.two_way&&!x.asset.metadata?.sign_and_trade&&<label className="trade-acquisition">Acquisition<select aria-label={'Acquisition for '+x.asset.label} value={tpes[x.asset.id]??''} onChange={e=>setTpes(prev=>({...prev,[x.asset.id]:e.target.value}))}><option value="">Salary matching</option>{sources.draft.exceptions.filter(v=>sameTeam(v.team,t)).map(v=><option key={v.id} value={v.id} disabled={v.available<=0||v.expires<effectiveDate}>{v.sourceTransaction} · {compact(v.available)}</option>)}</select></label>}</div>)}</div>)}
       {renounced.some(id=>sources.context.freeAgents.some(x=>x.id===id&&sameTeam(x.team,t)))&&<p className="subtle">Illustrative cap holds renounced: {money(sources.context.freeAgents.filter(x=>sameTeam(x.team,t)&&renounced.includes(x.id)).reduce((n,x)=>n+x.capHold,0))}</p>}
       {report?.teamSummaries[t]&&<p className="subtle">Projected modeled payroll {money(report.teamSummaries[t].postTradeSalary)} · Illustrative cap room {signed((sources.financial.teams.find(f=>sameTeam(f.team,t))?.capSpace??0)+sources.context.freeAgents.filter(x=>sameTeam(x.team,t)&&renounced.includes(x.id)).reduce((n,x)=>n+x.capHold,0)-(report.teamSummaries[t].postTradeSalary-(sourceScenario?.capContexts[t]?.teamSalary??report.teamSummaries[t].postTradeSalary)))} · Roster {report.teamSummaries[t].projectedRosterPlayers} · Outgoing {compact(report.teamSummaries[t].outgoingSalary)} · Incoming {compact(report.teamSummaries[t].incomingSalary)} · Match limit {compact(report.teamSummaries[t].maximumIncomingSalary)}</p>}</article>)}</div>
       {report?<div className="trade-inner trade-validation" aria-label="Modeled validation results"><h3 className={report.errorCount?'trade-negative':'trade-positive'}>{report.errorCount?'Modeled blockers found':'No modeled blocking errors'}</h3><p role="status">{report.errorCount} errors · {report.warningCount} warnings · {mode==='off'?'Restrictions bypassed · ':''}Not CBA approval</p>
        {report.findings.map((f,i)=><p key={i} className={'trade-finding '+(f.severity==='error'?'trade-negative':'')}><strong>{f.team??'Scenario'} · {f.code}</strong><br/>{f.message}</p>)}</div>:<p role="alert" className="trade-inner">Select a valid date within 2026–27 and confirm all source contexts.</p>}</>}
      {notice&&<p role="status" className="trade-inner">{notice}</p>}
     </section>
    </div>
    <details className="trade-source-detail"><summary>Source dates and validation limitations</summary><p>Roster salary records: {sources.contracts.asOf}; draft/TPE interests: {sources.draft.sourceAsOf}; financial position: {sources.financial.sourceAsOf}. Modeled starting salary uses the original video-screen formula: salary-cap allocation for room teams, first-apron allocation otherwise. Changing the scenario date does not reconstruct historic or future rosters. Guarantee and kicker allocations, Stepien continuity, exception mechanics and other CBA requirements remain incomplete.</p></details>
   </div>}
  </>}
 </section>;
}
