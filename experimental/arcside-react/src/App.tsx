import {useEffect,useMemo,useRef,useState} from 'react';
import type {Manifest,RateBasis,Season,SeasonSnapshot,SeasonType,JsonRow} from './data';
import {getManifest,getSeasons,getSeason,getPlayerDossier} from './data';
import type {MetricKey,Row} from './engine';
import {advancedKeys,bases,buildRows,formatMetric,metrics,overviewKeys,sortRows,stintRows} from './engine';
import {Chart} from './Chart';

type ViewState={path:string;season:string;segment:SeasonType;basis:RateBasis};
function fromUrl():ViewState {
 const p=new URLSearchParams(location.search);
 const segment=p.get('segment')==='playoffs'?'playoffs':'regular';
 const rawBasis=p.get('basis') as RateBasis;
 return {path:location.pathname,season:p.get('season')??'',segment,basis:bases.some(x=>x.value===rawBasis)?rawBasis:'perGame'};
}
function urlFor(v:ViewState):string {
 const qs=new URLSearchParams();
 if(v.season)qs.set('season',v.season);
 qs.set('segment',v.segment);qs.set('basis',v.basis);
 return v.path+'?'+qs.toString();
}
const qualify=(r:Row,segment:SeasonType)=> (r.values.gp??0)>=(segment==='regular'?50:4);
const metricLabel=(m:MetricKey)=>metrics.find(x=>x.key===m)?.label??m;
const allowedRoutes=['/stats','/advanced','/visualizations','/labs/python','/labs/sheets'];
function labelFor(route:string):string {
 return ({'/stats':'Stats','/advanced':'Advanced Stats','/visualizations':'Visualizations',
 '/labs/python':'Python Lab','/labs/sheets':'Excel Workspace'} as Record<string,string>)[route]??'Player detail';
}
export function App(){
 const [view,setView]=useState(fromUrl);
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
  getSeason(view.season,view.segment,controller.signal).then(setSnapshot).catch(e=>{
   if(!controller.signal.aborted)setError(String(e.message??e));
  }).finally(()=>{if(!controller.signal.aborted)setLoading(false)});
  return ()=>controller.abort();
 },[view.season,view.segment,manifest]);
 useEffect(()=>{
  if(!view.path.startsWith('/player/')){setDossier(null);return;}
  const controller=new AbortController();setDossier(null);
  const key=decodeURIComponent(view.path.slice('/player/'.length));
  getPlayerDossier(key,controller.signal).then(setDossier).catch(e=>{
   if(!controller.signal.aborted)setError(String(e.message??e));
  });
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
 const isLab=view.path.startsWith('/labs/');
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
   <div className="sidebar-foot"><span className="dot"/> PHASE 3 / EXPERIMENT
    <p>Flutter remains the reference implementation. Not a production release.</p></div>
  </aside>
  <div className="main-frame">
   <header className="topbar">
    <div><div className="crumb">NBA / {labelFor(view.path)}</div>
     <div className="top-title">{labelFor(view.path)}</div></div>
    <div className="top-actions">
     <span className="manifest-pill">{manifest?'NBA STATIC v'+manifest.static_schema_version:'SOURCE UNVERIFIED'}</span>
     <button onClick={()=>setTheme(x=>x==='dark'?'light':'dark')}
      aria-label={'Switch to '+(theme==='dark'?'light':'dark')+' theme'}>{theme==='dark'?'Light mode':'Dark mode'}</button>
    </div>
   </header>
   <main id="main" className="main-content">
    <div className="workbench-controls">
     <label>Season<select value={view.season} onChange={e=>change({season:e.target.value})}
      disabled={!seasons.length}>{seasons.map(s=><option key={s.season_id} value={s.season_id}>{s.label??s.season_id}</option>)}</select></label>
     <fieldset className="segment-controls"><legend>Season type</legend>
      <button className={view.segment==='regular'?'selected':''} aria-pressed={view.segment==='regular'}
       onClick={()=>change({segment:'regular'})}>Regular season</button>
      <button className={view.segment==='playoffs'?'selected':''} aria-pressed={view.segment==='playoffs'}
       onClick={()=>change({segment:'playoffs'})}>Playoffs</button></fieldset>
     <label>Rate basis<select value={view.basis} onChange={e=>change({basis:e.target.value as RateBasis})}>
       {bases.map(b=><option value={b.value} key={b.value}>{b.label}</option>)}</select></label>
     <span className="workbench-caption">One season · one source contract · shared context</span>
    </div>
    {error&&<div className="warning" role="alert"><strong>Data or integration gate not met.</strong> {error}
      <p>No historical values have been invented or substituted. Generate the canonical static corpus and reload.</p></div>}
    {loading&&<p role="status" className="loading">Loading verified NBA static data…</p>}
    {!allowedRoutes.includes(view.path)&&!view.path.startsWith('/player/')&&
     <div className="panel"><h2>Route not found</h2><button onClick={()=>navigate('/stats')}>Return to Stats</button></div>}
    {(view.path==='/stats'||view.path==='/advanced')&&<section className="panel" aria-label="Statistical table">
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
       <th scope="col">Pos</th>{keys.map(k=><th scope="col" key={k}>
        <button className="sort-button" aria-label={'Sort by '+metricLabel(k)}
         aria-sort={undefined} onClick={()=>{setSort(k);setDescending(s=>k===sort?!s:true)}}>
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
    {view.path==='/visualizations'&&<Chart rows={filtered} basis={view.basis}/>}
    {isLab&&<section className="panel lab-panel">
     <div className="panel-title"><div><p className="eyebrow">BROWSER-NATIVE WORKSPACE / ORIGINAL MODULE</p>
       <h2>{labelFor(view.path)}</h2>
       <p className="subtle">Runs the existing HTML/JS module under /web/labs; no replacement engine or data synchronization.</p></div>
       <a className="button-link" href={view.path==='/labs/python'?'/labs/python/index.html':'/labs/sheets/index.html'}
        target="_blank" rel="noopener noreferrer">Open standalone</a>
     </div>
     <p className="bridge-status" role="status">Context handshake: {labAck?'acknowledged':'pending / standalone Lab may ignore context'}.
      No credentials, workbooks, or code are sent.</p>
     <iframe ref={labRef} title={labelFor(view.path)} className="lab-frame"
      src={view.path==='/labs/python'?'/labs/python/index.html':'/labs/sheets/index.html'}
      onLoad={sendLabContext}/>
    </section>}
    {view.path.startsWith('/player/')&&<section className="panel">
     <button onClick={()=>navigate('/stats')}>← Return to Stats</button>
     <p className="eyebrow">CANONICAL PLAYER DOSSIER</p>
     <h2>{String(dossier?.player_name??dossier?.canonical_name??dossier?.player_label??'Loading player')}</h2>
     <p className="subtle">Reads the original published player dossier when its canonical index maps this identifier.</p>
     {dossier&&<dl className="profile-data">{Object.entries(dossier).filter(([k,v])=>
      ['player_key','player_id','canonical_name','birth_date','height','position','draft_year','team_name'].includes(k)
       && typeof v!=='object').map(([k,v])=><div key={k}><dt>{k.replaceAll('_',' ')}</dt><dd>{String(v??'—')}</dd></div>)}</dl>}
    </section>}
    <footer className="footer">Arcside experimental React workbench · Read-only, static-first · Existing Flutter shell unchanged</footer>
   </main>
  </div>
 </div>;
}
