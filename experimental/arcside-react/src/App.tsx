import {lazy,Suspense,useEffect,useMemo,useRef,useState} from 'react';
import type {Manifest,RateBasis,Season,SeasonSnapshot,SeasonType,JsonRow,DatedContractSnapshot} from './data';
import {getManifest,getSeasons,getSeason,getPlayerDossier,getDatedContracts,getFrontOfficeContracts} from './data';
import type {MetricKey,Row} from './engine';
import {advancedKeys,bases,buildRows,formatMetric,metrics,overviewKeys,sortRows,stintRows} from './engine';

import {dossierName,dossierSegments} from './ProfileDossier';
import {GlobalSearch} from './GlobalSearch';
const HomeWorkspace=lazy(()=>import('./HomeWorkspace').then(m=>({default:m.HomeWorkspace})));
const AdvancedStatsTable=lazy(()=>import('./AdvancedStatsTable').then(m=>({default:m.AdvancedStatsTable})));
const Chart=lazy(()=>import('./Chart').then(m=>({default:m.Chart})));
const CanonicalProfileStats=lazy(()=>import('./CanonicalProfileStats').then(m=>({default:m.CanonicalProfileStats})));
const PlayerProfileTables=lazy(()=>import('./ProfileTable').then(m=>({default:m.PlayerProfileTables})));
const ProfileSummary=lazy(()=>import('./ProfileContext').then(m=>({default:m.ProfileSummary})));
const ProfileContracts=lazy(()=>import('./ProfileContext').then(m=>({default:m.ProfileContracts})));
const ProfileHonors=lazy(()=>import('./ProfileContext').then(m=>({default:m.ProfileHonors})));
const ProfileSourceContext=lazy(()=>import('./ProfileContext').then(m=>({default:m.ProfileSourceContext})));
const TradeWorkspace=lazy(()=>import('./TradeWorkspace').then(m=>({default:m.TradeWorkspace})));
const ComparisonWorkspace=lazy(()=>import('./ComparisonWorkspaces').then(m=>({default:m.ComparisonWorkspace})));
const BoxScoresWorkspace=lazy(()=>import('./BoxScoresWorkspace').then(m=>({default:m.BoxScoresWorkspace})));
const FinancialsWorkspace=lazy(()=>import('./FinancialsWorkspace').then(m=>({default:m.FinancialsWorkspace})));
const WithWithoutWorkspace=lazy(()=>import('./WithWithoutWorkspace').then(m=>({default:m.WithWithoutWorkspace})));
const TeamDetailWorkspace=lazy(()=>import('./TeamDetailWorkspace').then(m=>({default:m.TeamDetailWorkspace})));
const TeamsDirectory=lazy(()=>import('./TeamDetailWorkspace').then(m=>({default:m.TeamsDirectory})));
const GamesWorkspace=lazy(()=>import('./GamesWorkspace').then(m=>({default:m.GamesWorkspace})));
const FranchiseHistoryWorkspace=lazy(()=>import('./FranchiseHistoryWorkspace').then(m=>({default:m.FranchiseHistoryWorkspace})));

type ViewState={path:string;season:string;segment:SeasonType;basis:RateBasis};
function fromUrl():ViewState {
 const p=new URLSearchParams(location.search);
 const segment=p.get('segment')==='playoffs'?'playoffs':'regular';
 const rawBasis=p.get('basis') as RateBasis;
 return {path:location.pathname==='/'?'/stats':location.pathname,season:p.get('season')??'',segment,basis:bases.some(x=>x.value===rawBasis)?rawBasis:'perGame'};
}
function urlFor(v:ViewState):string {
 const qs=new URLSearchParams();
 if(v.season)qs.set('season',v.season);
 qs.set('segment',v.segment);qs.set('basis',v.basis);
 return v.path+'?'+qs.toString();
}
const qualify=(r:Row,segment:SeasonType)=> (r.values.gp??0)>=(segment==='regular'?50:4);
const metricLabel=(m:MetricKey)=>metrics.find(x=>x.key===m)?.label??m;
const allowedRoutes=['/home','/stats','/advanced','/visualizations','/trade','/player-compare','/team-compare','/box-scores','/financials','/with-without','/teams','/games','/franchise-history','/workspaces/python','/workspaces/sheets'];
function labelFor(route:string):string {
 return ({'/home':'NBA Home','/stats':'Stats','/advanced':'Advanced Stats','/visualizations':'Visualizations',
 '/trade':'Trade Machine',
 '/player-compare':'Player Compare','/team-compare':'Team Compare',
 '/box-scores':'Box Scores','/financials':'Financials','/with-without':'With/Without',
 '/teams':'Teams','/games':'Games','/franchise-history':'Franchise History',
 '/workspaces/python':'Python Lab','/workspaces/sheets':'Excel Workspace'} as Record<string,string>)[route]??(route.startsWith('/team/')?'Team detail':route.startsWith('/game/')?'Game detail':'Player detail');
}
export function App(){
 const [view,setView]=useState(fromUrl);
 useEffect(()=>{if(location.pathname==='/')history.replaceState({},'',urlFor(fromUrl()))},[]);
 const [theme,setTheme]=useState(()=>{try{return localStorage.getItem('arcside.phase3.theme')==='light'?'light':'dark'}catch{return 'dark'}});
 const [manifest,setManifest]=useState<Manifest|null>(null);
 const [seasons,setSeasons]=useState<Season[]>([]);
 const [snapshot,setSnapshot]=useState<SeasonSnapshot|null>(null);
 const [error,setError]=useState('');
 const [loading,setLoading]=useState(true);
 const [search,setSearch]=useState('');
 const [team,setTeam]=useState('All');
 const [position,setPosition]=useState('All');
 const [qualified,setQualified]=useState(true);
 const [sort,setSort]=useState<MetricKey>('pts');
 const [descending,setDescending]=useState(true);
 const [expanded,setExpanded]=useState<Set<string>>(new Set());
 const [scrollTop,setScrollTop]=useState(0);
 const tableRef=useRef<HTMLDivElement>(null);
 const [labAck,setLabAck]=useState(false);
 const labRef=useRef<HTMLIFrameElement>(null);
 const [dossier,setDossier]=useState<JsonRow|null>(null);
 const [datedContracts,setDatedContracts]=useState<DatedContractSnapshot|null>(null);
 const [registryContracts,setRegistryContracts]=useState<JsonRow[]>([]);
 const [contractLoading,setContractLoading]=useState(false);
 useEffect(()=>{
  const onPop=()=>setView(fromUrl());
  window.addEventListener('popstate',onPop);return ()=>window.removeEventListener('popstate',onPop);
 },[]);
 useEffect(()=>{document.documentElement.dataset.theme=theme;
  try{localStorage.setItem('arcside.phase3.theme',theme)}catch{/* storage disabled */}
 },[theme]);
 useEffect(()=>{
  const controller=new AbortController();setLoading(true);setError('');
  Promise.all([getManifest(controller.signal),getSeasons(controller.signal)]).then(([m,ss])=>{
   setManifest(m);setSeasons(ss);
   if(!view.season&&ss.length) setView(v=>({...v,season:ss[0].season_id}));
  }).catch(e=>{if(!controller.signal.aborted)setError(String(e.message??e))}).finally(()=>{
   if(!controller.signal.aborted)setLoading(false);
  });
  return ()=>controller.abort();
 },[]);
 useEffect(()=>{
  if(!view.season||!manifest)return;
  const controller=new AbortController();setSnapshot(null);setError('');setLoading(true);
  getSeason(view.season,view.segment,controller.signal).then(value=>{if(!controller.signal.aborted)setSnapshot(value)}).catch(e=>{
   if(!controller.signal.aborted)setError(String(e.message??e));
  }).finally(()=>{if(!controller.signal.aborted)setLoading(false)});
  return ()=>controller.abort();
 },[view.season,view.segment,manifest]);
 useEffect(()=>{
  if(!view.path.startsWith('/player/')){setDossier(null);return;}
  const controller=new AbortController();setDossier(null);
  const key=decodeURIComponent(view.path.slice('/player/'.length));
  getPlayerDossier(key,controller.signal).then(value=>{if(!controller.signal.aborted)setDossier(value)}).catch(e=>{
   if(!controller.signal.aborted)setError(String(e.message??e));
  });
  return ()=>controller.abort();
 },[view.path]);
 useEffect(()=>{
  if(!view.path.startsWith('/player/')){
   setDatedContracts(null);setRegistryContracts([]);setContractLoading(false);return;
  }
  const controller=new AbortController();
  setDatedContracts(null);setRegistryContracts([]);setContractLoading(true);
  Promise.allSettled([
   getDatedContracts(controller.signal),
   getFrontOfficeContracts(controller.signal)
  ]).then(results=>{
   if(controller.signal.aborted)return;
   if(results[0].status==='fulfilled')setDatedContracts(results[0].value);
   if(results[1].status==='fulfilled')setRegistryContracts(results[1].value);
  }).finally(()=>{if(!controller.signal.aborted)setContractLoading(false)});
  return ()=>controller.abort();
 },[view.path]);
 useEffect(()=>{setExpanded(new Set());setScrollTop(0);if(tableRef.current)tableRef.current.scrollTop=0},[view.season,view.segment,view.basis,search,team,position,qualified,sort,descending]);
 function change(patch:Partial<ViewState>,push=false){
  const next={...view,...patch},u=urlFor(next);
  if(push)history.pushState({},'',u);else history.replaceState({},'',u);
  setView(next);
 }
 function navigate(path:string){change({path},true);window.scrollTo({top:0})}
 const rows=useMemo(()=>snapshot?buildRows(snapshot,view.basis):[],[snapshot,view.basis]);
 const teams=useMemo(()=>['All',...new Set(rows.flatMap(r=>r.team.split(/[,/ ]+/).filter(x=>/^[A-Z]{2,4}$/.test(x))))].sort(),[rows]);
 const positions=['All','PG','SG','SF','PF','C','G','F'];
 const filtered=useMemo(()=>sortRows(rows.filter(r=>{
  const matches=(r.player+' '+r.team+' '+r.position).toLowerCase().includes(search.toLowerCase().trim());
  return matches&&(team==='All'||r.team.split(/[,/ ]+/).includes(team))&&
   (position==='All'||r.position===position)&&(!qualified||qualify(r,view.segment));
 }),sort,descending),[rows,search,team,position,qualified,view.segment,sort,descending]);
 const visible=useMemo(()=>{
  const list:{row:Row;stint:boolean;parent:string}[]=[];
  for(const row of filtered){
   list.push({row,stint:false,parent:row.id});
   if(expanded.has(row.id))for(const child of stintRows(row,view.basis))list.push({row:child,stint:true,parent:row.id});
  }
  return list;
 },[filtered,expanded,view.basis]);
 const ROW_HEIGHT=38,VIEW_HEIGHT=544;
 const start=Math.max(0,Math.floor(scrollTop/ROW_HEIGHT)-8);
 const end=Math.min(visible.length,start+Math.ceil(VIEW_HEIGHT/ROW_HEIGHT)+18);
 const items=visible.slice(start,end);
 const keys=view.path==='/advanced'?advancedKeys:overviewKeys;
 const isLab=view.path.startsWith('/workspaces/');
 useEffect(()=>{
  const onMessage=(evt:MessageEvent)=>{
   if(evt.origin!==location.origin||evt.source!==labRef.current?.contentWindow)return;
   const data=evt.data;
   if(data?.type==='arcside:context:ack'&&data?.version===1&&
    data?.season===view.season&&data?.segment===view.segment)setLabAck(true);
  };
  window.addEventListener('message',onMessage);return ()=>window.removeEventListener('message',onMessage);
 },[view.season,view.segment,isLab]);
 function sendLabContext(){
  setLabAck(false);
  if(view.season&&labRef.current?.contentWindow)
   labRef.current.contentWindow.postMessage({type:'arcside:context',version:1,season:view.season,segment:view.segment},location.origin);
 }
 useEffect(()=>{if(isLab)sendLabContext()},[view.season,view.segment,isLab,view.path]);
 return <div className="app-shell">
  <a className="skip" href="#main">Skip to content</a>
  <aside className="sidebar" aria-label="Main navigation">
   <div className="brand"><span className="logo">A</span><div><strong>ARCSIDE</strong><small>ANALYTICAL WORKBENCH</small></div></div>
   <span className="sidebar-heading">NBA RESEARCH</span>
   <nav>{allowedRoutes.map(route=><a key={route} href={urlFor({...view,path:route})}
    className={view.path===route?'nav-link chosen':'nav-link'} aria-current={view.path===route?'page':undefined}
    onClick={e=>{e.preventDefault();navigate(route)}}>{labelFor(route)}</a>)}</nav>
   <div className="sidebar-foot"><span className="dot"/> ARCSIDE REACT
    <p>Primary development frontend · migration validation in progress.</p></div>
  </aside>
  <div className="main-frame">
   <header className="topbar">
    <div><div className="crumb">NBA / {labelFor(view.path)}</div>
     <div className="top-title">{labelFor(view.path)}</div></div>
    <div className="top-actions">
     <GlobalSearch onNavigate={navigate}/>
     <span className="manifest-pill">{manifest?'NBA STATIC v'+manifest.static_schema_version:'SOURCE UNVERIFIED'}</span>
     <button onClick={()=>setTheme(x=>x==='dark'?'light':'dark')}
      aria-label={'Switch to '+(theme==='dark'?'light':'dark')+' theme'}>{theme==='dark'?'Light mode':'Dark mode'}</button>
    </div>
   </header>
   <main id="main" className="main-content">
    {!["/trade","/financials","/box-scores"].includes(view.path)&&<div className="workbench-controls">
     <label>Season<select value={view.season} onChange={e=>change({season:e.target.value})}
      disabled={!seasons.length}>{seasons.map(s=><option key={s.season_id} value={s.season_id}>{s.label??s.season_id}</option>)}</select></label>
     {view.path!=='/home'&&<fieldset className="segment-controls"><legend>Season type</legend>
      <button className={view.segment==='regular'?'selected':''} aria-pressed={view.segment==='regular'}
       onClick={()=>change({segment:'regular'})}>Regular season</button>
      <button className={view.segment==='playoffs'?'selected':''} aria-pressed={view.segment==='playoffs'}
       onClick={()=>change({segment:'playoffs'})}>Playoffs</button></fieldset>}
     {view.path!=='/team-compare'&&view.path!=='/home'&&<label>Rate basis<select value={view.basis} onChange={e=>change({basis:e.target.value as RateBasis})}>
       {bases.map(b=><option value={b.value} key={b.value}>{b.label}</option>)}</select></label>}
     <span className="workbench-caption">Season context</span>
    </div>}
    {error&&<div className="warning" role="alert"><strong>Data or integration gate not met.</strong> {error}
      <p>No historical values have been invented or substituted. Generate the canonical static corpus and reload.</p></div>}
    {loading&&<p role="status" className="loading">Loading verified NBA static data…</p>}
    {!allowedRoutes.includes(view.path)&&!view.path.startsWith('/player/')&&!view.path.startsWith('/team/')&&!view.path.startsWith('/game/')&&
     <div className="panel"><h2>Route not found</h2><button onClick={()=>navigate('/stats')}>Return to Stats</button></div>}
    <Suspense fallback={<p role="status" className="loading">Loading selected Arcside workspace…</p>}>
    {view.path==='/home'&&<HomeWorkspace season={view.season} onNavigate={navigate}/>}
    {view.path==='/advanced'&&<AdvancedStatsTable rows={rows}
      basis={view.basis} segment={view.segment} season={view.season}
      onPlayer={id=>navigate('/player/'+encodeURIComponent(id))}/>}
    {view.path==='/stats'&&<section className="panel" aria-label="Statistical table">
     <div className="panel-title"><div><p className="eyebrow">NBA / SOURCE-BACKED DATA</p>
      <h2>{view.path==='/stats'?'Player statistics':'Advanced player statistics'}</h2>
      <p className="subtle">{filtered.length.toLocaleString()} of {rows.length.toLocaleString()} player rows ·
       {view.segment==='regular'?'Regular season':'Postseason'} · {view.season}</p></div>
      <div className="row-wrap"><button onClick={()=>navigate(view.path==='/stats'?'/advanced':'/stats')}>
       Open {view.path==='/stats'?'Advanced Stats':'Stats'}</button></div>
     </div>
     <div className="toolbar">
      <label>Find player<input aria-label="Find player" placeholder="Search players" value={search}
       onChange={e=>setSearch(e.target.value)}/></label>
      <label>Team<select value={team} onChange={e=>setTeam(e.target.value)}>
       {teams.map(t=><option key={t} value={t}>{t}</option>)}</select></label>
      <label>Position<select value={position} onChange={e=>setPosition(e.target.value)}>
       {positions.map(p=><option key={p}>{p}</option>)}</select></label>
      <label className="check"><input type="checkbox" checked={qualified}
       onChange={e=>setQualified(e.target.checked)}/>
       Qualify ({view.segment==='regular'?'50':'4'}+ GP)</label>
     </div>
     <div className="table-scroll" ref={tableRef} onScroll={e=>setScrollTop(e.currentTarget.scrollTop)}
      tabIndex={0} role="region" aria-label="Scrollable player stats">
      <table className="stats-table"><thead><tr>
       <th scope="col">#</th><th scope="col" className="player-header">Player</th><th scope="col">Team</th>
       <th scope="col">Pos</th>{keys.map(k=><th scope="col" key={k} aria-sort={sort===k?(descending?'descending':'ascending'):undefined}>
        <button className="sort-button" aria-label={'Sort by '+metricLabel(k)}
         onClick={()=>{setSort(k);setDescending(s=>k===sort?!s:true)}}>
         {metricLabel(k)} {sort===k?(descending?'↓':'↑'):''}</button></th>)}
       </tr></thead><tbody>
       {start>0&&<tr aria-hidden="true" className="spacer-row"><td style={{height:start*ROW_HEIGHT}} colSpan={4+keys.length}/></tr>}
       {items.map((item,i)=>{
        const r=item.row,stints=!item.stint?stintRows(r,view.basis):[];
        return <tr key={item.parent+(item.stint?'-'+r.team:'')} className={item.stint?'stint-row':''}
         style={{height:ROW_HEIGHT}}>
         <td>{item.stint?'↳':start+i+1}</td>
         <td className="player-cell">{stints.length>=2&&<button className="expand" aria-label={(expanded.has(r.id)?'Collapse':'Expand')+' stints for '+r.player}
          aria-expanded={expanded.has(r.id)} onClick={()=>setExpanded(s=>{const next=new Set(s);if(next.has(r.id))next.delete(r.id);else next.add(r.id);return next})}>
          {expanded.has(r.id)?'−':'+'}</button>}
          {!item.stint?<a href={urlFor({...view,path:'/player/'+encodeURIComponent(r.id)})}
           onClick={e=>{e.preventDefault();navigate('/player/'+encodeURIComponent(r.id))}}>{r.player}</a>:r.player}</td>
         <td>{r.team}</td><td>{r.position}</td>{keys.map(k=><td key={k} className="numeric">{formatMetric(k,r.values[k])}</td>)}
        </tr>;
       })}
       {end<visible.length&&<tr aria-hidden="true" className="spacer-row"><td style={{height:(visible.length-end)*ROW_HEIGHT}} colSpan={4+keys.length}/></tr>}
       </tbody></table>
     </div>
     <p className="table-note">Virtualized row window · stable player-ID joins · “—” means unavailable, not zero.
      Source-verified team stints only. Scroll inside the table to inspect additional rows.</p>
    </section>}
    {view.path==='/visualizations'&&<Chart rows={rows} basis={view.basis} segment={view.segment}/>}
     {view.path==='/trade'&&<TradeWorkspace/>}
    {view.path==='/player-compare'&&<ComparisonWorkspace key="player-comparison" kind="player" seasons={seasons}
     onContext={context=>change(context)}
     season={view.season} segment={view.segment} basis={view.basis} snapshot={snapshot}
     onPlayer={id=>navigate('/player/'+encodeURIComponent(id))}/>}
    {view.path==='/team-compare'&&<ComparisonWorkspace key="team-comparison" kind="team" seasons={seasons}
     onContext={context=>change(context)}
     season={view.season} segment={view.segment} basis={view.basis} snapshot={snapshot}/>}
    {view.path==='/box-scores'&&<BoxScoresWorkspace onPlayer={id=>navigate('/player/'+encodeURIComponent(id))}/>}
    {view.path==='/financials'&&<FinancialsWorkspace/>}
    {view.path==='/with-without'&&<WithWithoutWorkspace rows={rows} season={view.season}
     segment={view.segment} basis={view.basis}/>}
    {view.path==='/teams'&&<TeamsDirectory onTeam={id=>navigate('/team/'+encodeURIComponent(id))}/>}
    {view.path.startsWith('/team/')&&<TeamDetailWorkspace
     teamKey={decodeURIComponent(view.path.slice('/team/'.length))}
     snapshot={snapshot} onPlayer={id=>navigate('/player/'+encodeURIComponent(id))}
     onGame={id=>navigate('/game/'+encodeURIComponent(id))}
     onTeam={id=>navigate('/team-compare')}/>}
    {(view.path==='/games'||view.path.startsWith('/game/'))&&<GamesWorkspace
     season={view.season} segment={view.segment}
     initialGame={view.path.startsWith('/game/')?decodeURIComponent(view.path.slice('/game/'.length)):''}
     onTeam={id=>navigate('/team/'+encodeURIComponent(id))}
     onPlayer={id=>navigate('/player/'+encodeURIComponent(id))}/>}
    {view.path==='/franchise-history'&&<FranchiseHistoryWorkspace
     onTeam={id=>navigate('/team/'+encodeURIComponent(id))}/>}

    {isLab&&<section className="panel lab-panel">
     <div className="panel-title"><div><p className="eyebrow">BROWSER-NATIVE WORKSPACE / ORIGINAL MODULE</p>
       <h2>{labelFor(view.path)}</h2>
       <p className="subtle">Runs the existing HTML/JS module under /web/labs; no replacement engine or data synchronization.</p></div>
       <a className="button-link" href={view.path==='/workspaces/python'?'/labs/python/index.html':'/labs/sheets/index.html'}
        target="_blank" rel="noopener noreferrer">Open standalone</a>
     </div>
     <p className="bridge-status" role="status">Context handshake: {labAck?'acknowledged':'pending / standalone Lab may ignore context'}.
      No credentials, workbooks, or code are sent.</p>
     <iframe ref={labRef} title={labelFor(view.path)} className="lab-frame"
      src={view.path==='/workspaces/python'?'/labs/python/index.html':'/labs/sheets/index.html'}
      onLoad={sendLabContext}/>
    </section>}
    {view.path.startsWith('/player/')&&<section className="panel">
     <button onClick={()=>navigate('/stats')}>← Return to Stats</button>
     <p className="eyebrow">CANONICAL PLAYER DOSSIER</p>
     <h2>{dossierName(dossier,'Loading player')}</h2>
     <p className="subtle">Original source-backed historical player dossier. The active season type determines career and advanced statistics below.</p>
     {dossier&&<div className="profile-data" aria-label="Published player profile">
      {Object.entries((dossier.profile&&typeof dossier.profile==='object'&&!Array.isArray(dossier.profile)?dossier.profile:{}) as Record<string,unknown>)
       .filter(([k,v])=>['canonical_name','positions','primary_position','birth_date','height','draft_year','draft_number'].includes(k)
        && v!==null && typeof v!=='object').map(([k,v])=><div key={k}><dt>{k.replaceAll('_',' ')}</dt><dd>{String(v)}</dd></div>)}
     </div>}
     {dossier&&<ProfileSummary dossier={dossier}/>}
     {dossier&&<div className="profile-stats-wrapper">
      <div className="profile-segment-actions" role="group" aria-label="Player career season type">
       <button aria-pressed={view.segment==='regular'} className={view.segment==='regular'?'active-control':''}
        onClick={()=>change({segment:'regular'})}>Regular season</button>
       <button aria-pressed={view.segment==='playoffs'} className={view.segment==='playoffs'?'active-control':''}
        onClick={()=>change({segment:'playoffs'})}>Playoffs</button>
       <span>{dossierSegments(dossier)[view.segment].length} original published rows</span>
      </div>
      <CanonicalProfileStats key={view.path} dossier={dossier} playerKey={decodeURIComponent(view.path.slice('/player/'.length))} segment={view.segment} basis={view.basis} season={view.season} activeSnapshot={snapshot}/>
      <PlayerProfileTables dossier={dossier} segment={view.segment} basis={view.basis}/>
      <ProfileContracts dossier={dossier} dated={datedContracts} registry={registryContracts}
        playerKey={decodeURIComponent(view.path.slice('/player/'.length))}
        playerName={dossierName(dossier)} loading={contractLoading}/>
      <ProfileHonors dossier={dossier}/>
      <ProfileSourceContext dossier={dossier}/>
     </div>}
    </section>}
    </Suspense>
     <footer className="footer">Arcside · Source-backed NBA research · Local development beta</footer>
   </main>
  </div>
 </div>;
}
