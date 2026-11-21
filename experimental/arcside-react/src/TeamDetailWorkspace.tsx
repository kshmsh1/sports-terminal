import {useEffect,useMemo,useState} from 'react';
import type {DatedContractSnapshot,JsonRow,SeasonSnapshot} from './data';
import {getDatedContracts,getTeamDossier,getTeamIndex,getSeason} from './data';
import {buildRows} from './engine';
const rows=(v:unknown):JsonRow[]=>Array.isArray(v)?v.filter((x):x is JsonRow=>x!==null&&typeof x==='object'&&!Array.isArray(x)):[];
const obj=(v:unknown):JsonRow=>v&&typeof v==='object'&&!Array.isArray(v)?v as JsonRow:{};
const str=(v:unknown,missing='—')=>v===undefined||v===null||v===''?missing:String(v);
const amount=(x:unknown)=>typeof x==='number'&&Number.isFinite(x)?'$'+Math.round(x).toLocaleString():'—';
const norm=(x:string)=>x.toLowerCase().replace(/[^a-z0-9]/g,'');
export function TeamsDirectory({onTeam}:{onTeam:(id:string)=>void}){
 const [teams,setTeams]=useState<JsonRow[]>([]),[query,setQuery]=useState(''),[error,setError]=useState('');
 useEffect(()=>{const controller=new AbortController();getTeamIndex(controller.signal).then(setTeams)
  .catch(e=>{if(!controller.signal.aborted)setError(String(e.message??e))});
  return ()=>controller.abort();
 },[]);
 const found=teams.filter(r=>[r.canonical_name,r.abbreviation,r.team_key].some(v=>
  str(v,'').toLowerCase().includes(query.trim().toLowerCase())));
 return <section className="panel" aria-label="NBA teams directory">
  <div className="panel-title"><div><p className="eyebrow">NBA / SOURCE TEAM INDEX</p>
   <h2>Teams</h2><p className="subtle">Search published team identities and open original historical dossiers.</p></div></div>
  <label>Find team<input aria-label="Find team" value={query} onChange={e=>setQuery(e.target.value)}
   placeholder="Team name or abbreviation"/></label>
  {error&&<p role="alert">{error}</p>}
  <div className="teams-directory">{found.slice(0,150).map((r,i)=><button key={String(r.team_key??i)}
   onClick={()=>onTeam(str(r.team_key,''))}>
   <strong>{str(r.canonical_name)}</strong><span>{str(r.abbreviation)} · {str(r.franchise_key)}</span>
  </button>)}</div>
  {found.length>150&&<p className="subtle">Showing 150 of {found.length} matching published identities.</p>}
  <p className="table-note">Team index values originate in the original NBA v5 corpus; no team identities are synthesized.</p>
 </section>;
}
export function teamCareerSeasons(dossier:JsonRow,segment:'regular'|'playoffs'){
 return rows(dossier.seasons).filter(r=>{
  const text=String(r.season_type??'regular').toLowerCase();
  return segment==='playoffs'?text.includes('play'):!text.includes('play');
 });
}
export function joinTeamRoster(contracts:DatedContractSnapshot|null,abbr:string,snapshot:SeasonSnapshot|null){
 const players=snapshot?buildRows(snapshot,'perGame'):[];
 const mapped=new Map(players.map(p=>[norm(p.player),p]));
 return (contracts?.records??[]).filter(c=>c.team===abbr&&Number(c.salaries['2026-27']??0)>0)
  .map(c=>({contract:c,previous:mapped.get(norm(c.player))}))
  .sort((a,b)=>(b.previous?.values.min??-1)-(a.previous?.values.min??-1)||
   b.contract.salaries['2026-27']-a.contract.salaries['2026-27']);
}
const cols=['season_id','team_abbreviation','games','wins','losses','win_pct','pts','opp_pts','srs','pace','offensive_rating','defensive_rating','net_rating'] as const;
export function TeamDetailWorkspace({teamKey,snapshot,onPlayer,onGame,onTeam}:{
 teamKey:string;snapshot:SeasonSnapshot|null;onPlayer:(id:string)=>void;onGame:(id:string)=>void;onTeam:(key:string)=>void;
}){
 const [index,setIndex]=useState<JsonRow[]>([]),[dossier,setDossier]=useState<JsonRow|null>(null);
 const [contracts,setContracts]=useState<DatedContractSnapshot|null>(null);
 const [teamSeason,setTeamSeason]=useState<SeasonSnapshot|null>(null);
 const [historySegment,setHistorySegment]=useState<'regular'|'playoffs'>('regular');
 const [error,setError]=useState(''),[loading,setLoading]=useState(true);
 useEffect(()=>{const controller=new AbortController();setLoading(true);setError('');setDossier(null);
  Promise.allSettled([getTeamIndex(controller.signal),getDatedContracts(controller.signal)]).then(async results=>{
   if(results[0].status!=='fulfilled')throw results[0].reason;
   const items=results[0].value,salary=results[1].status==='fulfilled'?results[1].value:null;
   if(controller.signal.aborted)return;
   setIndex(items);setContracts(salary);
   setDossier(await getTeamDossier(teamKey,items,controller.signal));
  }).catch(e=>{if(!controller.signal.aborted)setError(String(e.message??e))})
   .finally(()=>{if(!controller.signal.aborted)setLoading(false)});
  return ()=>controller.abort();
 },[teamKey]);
 useEffect(()=>{const controller=new AbortController();
  getSeason('2025-26','regular',controller.signal).then(data=>{if(!controller.signal.aborted)setTeamSeason(data)})
   .catch(()=>{if(!controller.signal.aborted)setTeamSeason(null)});
  return ()=>controller.abort();
 },[]);
 const profile=obj(dossier?.profile),franchise=obj(dossier?.franchise);
 const abbr=str(profile.abbreviation,'');
 const roster=useMemo(()=>joinTeamRoster(contracts,abbr,teamSeason??snapshot),[contracts,abbr,teamSeason,snapshot]);
 const history=dossier?teamCareerSeasons(dossier,historySegment):[];
 const injuries=rows(dossier?.injuries_2026_27??dossier?.current_injuries??dossier?.injuries);
 const transactions=rows(dossier?.transactions_2026_27??dossier?.current_transactions??dossier?.transactions);
 const recent=rows(dossier?.recent_games),notable=rows(dossier?.notable_players);
 const names=(p:JsonRow)=>str(p.player_name,str(p.name));
 return <section className="panel team-detail-workspace" aria-label="Team detail">
  {loading&&<p role="status">Loading original NBA team dossier…</p>}
  {error&&<p role="alert">Original team profile unavailable: {error}</p>}
  {dossier&&<>
   <div className="panel-title"><div><p className="eyebrow">NBA / CANONICAL TEAM DOSSIER</p>
    <h2>{str(profile.canonical_name,str(profile.name,teamKey))}</h2>
    <p className="subtle">{abbr} · {str(franchise.canonical_name)} · original historical record</p></div>
    <button onClick={()=>onTeam(abbr||teamKey)}>Team comparison</button></div>
   <div className="profile-summary">
    <div><span>2026–27 DATED ROSTER</span><strong>{roster.length}</strong></div>
    <div><span>HISTORICAL SEASONS</span><strong>{new Set(rows(dossier.seasons).map(r=>r.season_id)).size}</strong></div>
    <div><span>TEAM KEY</span><strong>{teamKey}</strong></div>
   </div>
   <h3>2026–27 depth chart · illustrative position grouping</h3>
   <p className="subtle">Positions and previous playing time come from the verified canonical season when available. This is not an official coaching depth chart.</p>
   <div className="team-detail-positions">{['PG','SG','SF','PF','C','Other'].map(position=>{
    const group=roster.filter(x=>(x.previous?.position??'').split(/[,/ ]+/).includes(position)||
     position==='Other'&&!['PG','SG','SF','PF','C'].some(p=>(x.previous?.position??'').includes(p)));
    return <div key={position}><strong>{position}</strong><p>{group.length?group.map(x=>x.contract.player).join(' · '):'—'}</p></div>;
   })}</div>
   <h3>2026–27 roster and dated salary records</h3>
   {roster.length?<div className="table-scroll" role="region" tabIndex={0} aria-label="Team roster"><table className="stats-table">
    <thead><tr><th>Player</th><th>Position</th><th>Salary</th><th>Guaranteed</th><th>Previous GP</th><th>Previous PPG</th></tr></thead>
    <tbody>{roster.map(({contract,previous})=><tr key={contract.id}><td>
     {previous?<button className="sort-button" onClick={()=>onPlayer(previous.id)}>{contract.player}</button>:contract.player}</td>
     <td>{previous?.position??'—'}</td><td className="numeric">{amount(contract.salaries['2026-27'])}</td>
     <td className="numeric">{amount(contract.guaranteed)}</td><td className="numeric">{previous?.values.gp??'—'}</td>
     <td className="numeric">{previous?.values.pts?.toFixed(1)??'—'}</td></tr>)}</tbody>
   </table></div>:<p className="empty">No 2026–27 salary-seed roster is available for this team. No roster has been inferred.</p>}
   <p className="subtle">Salary seed as of {contracts?.asOf??'unavailable'}; previous-season stats from the original 2025–26 regular-season source, not an assumed live depth chart.</p>
   <div className="team-detail-pair">
    <div><h3>Injuries</h3>{injuries.length?<ul>{injuries.map((r,i)=><li key={i}>{names(r)} · {str(r.status)}</li>)}</ul>:<p className="empty">No published injury feed for this team.</p>}</div>
    <div><h3>Transactions</h3>{transactions.length?<ul>{transactions.map((r,i)=><li key={i}>{str(r.date)} · {str(r.description,str(r.transaction))}</li>)}</ul>:<p className="empty">No published transaction feed for this team.</p>}</div>
   </div>
   <h3>Season history</h3>
   <div className="row-wrap" role="group" aria-label="Team history segment">
    {(['regular','playoffs'] as const).map(segment=><button key={segment} aria-pressed={historySegment===segment}
     className={historySegment===segment?'selected':''} onClick={()=>setHistorySegment(segment)}>
     {segment==='regular'?'Regular season':'Playoffs'}</button>)}
   </div>
   {history.length?<div className="table-scroll" role="region" tabIndex={0} aria-label="Team season history"><table className="stats-table">
    <thead><tr>{cols.map(c=><th key={c}>{c.replaceAll('_',' ').toUpperCase()}</th>)}</tr></thead>
    <tbody>{history.map((r,i)=><tr key={i}>{cols.map(c=><td key={c}>{str(r[c])}</td>)}</tr>)}</tbody>
   </table></div>:<p className="empty">No published {historySegment} history rows for this team.</p>}
   <div className="team-detail-pair">
    <div><h3>Notable players</h3>{notable.length?<ul>{notable.slice(0,25).map((r,i)=><li key={i}>
     {typeof r.player_key==='string'?<button className="sort-button" onClick={()=>onPlayer(String(r.player_key))}>{names(r)}</button>:names(r)}
    </li>)}</ul>:<p className="empty">No published notable-player rows.</p>}</div>
    <div><h3>Recent historical games</h3>{recent.length?<ul>{recent.slice(0,25).map((r,i)=><li key={i}>
     <button className="sort-button" onClick={()=>onGame(str(r.game_key,str(r.nba_game_id,'')))}>{str(r.game_date)} · {str(r.away_team_abbreviation)} @ {str(r.home_team_abbreviation)}</button>
    </li>)}</ul>:<p className="empty">No published recent game rows.</p>}</div>
   </div>
   <p className="table-note">Original Flutter team detail also consumes a separate live schedule feed. That feed is not assumed to exist in this read-only React pilot. Historical statistics and dated contracts are not live roster confirmations.</p>
  </>}
  <p className="subtle">Indexed team identities: {index.length}. Original team resolution and team files take precedence over abbreviation guesses.</p>
 </section>;
}
