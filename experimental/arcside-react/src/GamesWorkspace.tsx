import {useEffect,useMemo,useState} from 'react';
import type {JsonRow,SeasonType} from './data';
import {getGameDetail,getGameIndex,getGamePlayByPlay} from './data';
const rows=(v:unknown):JsonRow[]=>Array.isArray(v)?v.filter((x):x is JsonRow=>x!==null&&typeof x==='object'&&!Array.isArray(x)):[];
const obj=(v:unknown):JsonRow=>v&&typeof v==='object'&&!Array.isArray(v)?v as JsonRow:{};
const str=(v:unknown,missing='—')=>v===undefined||v===null||String(v).trim()===''?missing:String(v);
export function gameType(row:JsonRow):SeasonType{
 return /play|post/i.test(str(row.season_type,str(row.segment,'')))?'playoffs':'regular';
}
export function selectPublishedGames(index:JsonRow[],season:string,segment:SeasonType,team:string,query:string){
 const q=query.trim().toLowerCase();
 return index.filter(r=>str(r.season_id)===season&&gameType(r)===segment&&
  (team==='All'||[r.home_team_abbreviation,r.away_team_abbreviation,r.home_team_name,r.away_team_name].some(x=>str(x,'')===team))&&
  [r.game_date,r.nba_game_id,r.game_key,r.home_team_abbreviation,r.away_team_abbreviation,r.home_team_name,r.away_team_name]
   .some(x=>str(x,'').toLowerCase().includes(q)));
}
export function GamesWorkspace({season,segment,initialGame='',onTeam,onPlayer}:{
 season:string;segment:SeasonType;initialGame?:string;onTeam:(key:string)=>void;onPlayer:(key:string)=>void
}){
 const [games,setGames]=useState<JsonRow[]>([]),[error,setError]=useState('');
 const [loading,setLoading]=useState(true),[search,setSearch]=useState(''),[team,setTeam]=useState('All');
 const [selected,setSelected]=useState<JsonRow|null>(null),[detail,setDetail]=useState<JsonRow|null>(null);
 const [pbp,setPbp]=useState<JsonRow[]>([]),[detailError,setDetailError]=useState(''),[detailLoading,setDetailLoading]=useState(false);
 const [order,setOrder]=useState<'newest'|'oldest'>('newest'),[page,setPage]=useState(0);
 const PAGE=60;
 useEffect(()=>{const controller=new AbortController();setLoading(true);setError('');
  getGameIndex(controller.signal).then(index=>{if(controller.signal.aborted)return;setGames(index);
   if(initialGame)setSelected(index.find(r=>[r.game_key,r.nba_game_id].some(x=>x===initialGame))??null);
  }).catch(e=>{if(!controller.signal.aborted)setError(String(e.message??e))})
   .finally(()=>{if(!controller.signal.aborted)setLoading(false)});
  return ()=>controller.abort();
 },[initialGame]);
 useEffect(()=>{if(!selected){setDetail(null);setPbp([]);return}
  const controller=new AbortController();setDetail(null);setPbp([]);setDetailError('');setDetailLoading(true);
  Promise.allSettled([getGameDetail(selected,controller.signal),getGamePlayByPlay(selected,controller.signal)])
   .then(results=>{
    if(controller.signal.aborted)return;
    if(results[0].status==='fulfilled')setDetail(results[0].value);
    else setDetailError(String(results[0].reason));
    if(results[1].status==='fulfilled')setPbp(results[1].value);
    else setDetailError(prev=>prev+' Play-by-play unavailable: '+String(results[1].reason));
   }).finally(()=>{if(!controller.signal.aborted)setDetailLoading(false)});
  return ()=>controller.abort();
 },[selected]);
 useEffect(()=>setPage(0),[season,segment,team,search,order]);
 const teams=useMemo(()=>['All',...new Set(games.filter(g=>str(g.season_id)===season).flatMap(g=>
  [str(g.home_team_abbreviation,''),str(g.away_team_abbreviation,'')]).filter(Boolean))].sort(),[games,season]);
 const filtered=useMemo(()=>selectPublishedGames(games,season,segment,team,search)
  .sort((a,b)=>(order==='newest'?-1:1)*str(a.game_date,'').localeCompare(str(b.game_date,''))),
 [games,season,segment,team,search,order]);
 const displayed=filtered.slice(page*PAGE,(page+1)*PAGE);
 const game=obj(detail?.game);const players=rows(detail?.players??detail?.player_box_scores);
 const sides=rows(detail?.teams??detail?.team_box_scores);
 const away=str(selected?.away_team_abbreviation),home=str(selected?.home_team_abbreviation);
 const cols=['player_name','team_abbreviation','minutes','pts','reb','ast','stl','blk','tov','fgm','fga','three_pm','three_pa','ftm','fta'] as const;
 return <section className="panel games-workspace" aria-label="Games workspace">
  <div className="panel-title"><div><p className="eyebrow">NBA / CANONICAL HISTORICAL GAME CATALOG</p>
   <h2>Games</h2><p className="subtle">Source-backed game search with scores, player and team game logs, and optional published play-by-play.</p></div></div>
  {loading&&<p role="status">Loading original historical game index…</p>}
  {error&&<p role="alert">{error}</p>}
  <div className="toolbar">
   <label>Find game<input aria-label="Find game" value={search} placeholder="Team, date, or game ID"
    onChange={e=>setSearch(e.target.value)}/></label>
   <label>Team<select aria-label="Game team" value={team} onChange={e=>setTeam(e.target.value)}>
    {teams.map(t=><option key={t}>{t}</option>)}</select></label>
   <label>Sort<select aria-label="Game date sort" value={order} onChange={e=>setOrder(e.target.value as typeof order)}>
    <option value="newest">Newest first</option><option value="oldest">Oldest first</option></select></label>
  </div>
  <p className="subtle">{filtered.length.toLocaleString()} games indexed for {season} {segment}. Showing {displayed.length} on this page.</p>
  <div className="table-scroll" role="region" aria-label="Published games" tabIndex={0}>
   <table className="stats-table"><thead><tr><th>Date</th><th>Away</th><th>Home</th><th>Score</th><th>Game ID</th><th>Detail</th></tr></thead>
   <tbody>{displayed.map((g,i)=><tr key={str(g.game_key,String(i))}>
    <td>{str(g.game_date)}</td><td><button className="sort-button" onClick={()=>onTeam(str(g.away_team_key,str(g.away_team_abbreviation,'')))}>{str(g.away_team_abbreviation)}</button></td>
    <td><button className="sort-button" onClick={()=>onTeam(str(g.home_team_key,str(g.home_team_abbreviation,'')))}>{str(g.home_team_abbreviation)}</button></td>
    <td>{str(g.away_score)}–{str(g.home_score)}</td><td>{str(g.nba_game_id,str(g.game_key))}</td>
    <td><button onClick={()=>setSelected(g)}>Inspect</button></td></tr>)}</tbody></table>
  </div>
  <div className="row-wrap"><button disabled={page===0} onClick={()=>setPage(x=>x-1)}>Previous</button>
   <span>Page {page+1} of {Math.max(1,Math.ceil(filtered.length/PAGE))}</span>
   <button disabled={(page+1)*PAGE>=filtered.length} onClick={()=>setPage(x=>x+1)}>Next</button></div>
  {selected&&<div className="games-inspector" aria-label="Game details">
   <div className="row-wrap"><h3>{away} at {home} · {str(selected.game_date)}</h3>
    <button onClick={()=>setSelected(null)}>Close game</button></div>
   <p>{str(selected.away_score)} – {str(selected.home_score)} · {str(selected.nba_game_id,str(selected.game_key))}</p>
   {detailLoading&&<p role="status">Loading published game details…</p>}
   {detailError&&<p role="alert">{detailError}</p>}
   {!!Object.keys(game).length&&<p className="subtle">{str(game.arena,str(game.venue,''))} · {str(game.season_id)}</p>}
   <h3>Team box score</h3>
   {sides.length?<div className="table-scroll" role="region" aria-label="Game team statistics" tabIndex={0}>
    <table className="stats-table"><thead><tr><th>Team</th><th>PTS</th><th>REB</th><th>AST</th><th>FGM</th><th>FGA</th></tr></thead>
    <tbody>{sides.map((r,i)=><tr key={i}><td>{str(r.team_abbreviation,str(r.team_name))}</td>
     {['pts','reb','ast','fgm','fga'].map(k=><td key={k}>{str(r[k])}</td>)}</tr>)}</tbody></table>
   </div>:<p className="empty">No team box-score rows published for this game.</p>}
   <h3>Player box score</h3>
   {players.length?<div className="table-scroll" role="region" aria-label="Game player statistics" tabIndex={0}>
    <table className="stats-table"><thead><tr>{cols.map(k=><th key={k}>{k.toUpperCase()}</th>)}</tr></thead>
    <tbody>{players.map((r,i)=><tr key={i}>{cols.map(k=><td key={k}>{k==='player_name'&&typeof r.player_key==='string'?
     <button className="sort-button" onClick={()=>onPlayer(String(r.player_key))}>{str(r[k])}</button>:str(r[k])}</td>)}</tr>)}</tbody>
   </table></div>:<p className="empty">Player box-score rows have not been materialized for this game.</p>}
   <h3>Play-by-play</h3>
   {pbp.length?<div className="games-pbp" role="region" tabIndex={0} aria-label="Published play-by-play">
    {pbp.slice(0,300).map((r,i)=><p key={i}>{str(r.period,'')} {str(r.clock,str(r.game_clock,''))} · {str(r.description,str(r.event_description))}</p>)}
    {pbp.length>300&&<p className="subtle">Showing first 300 of {pbp.length.toLocaleString()} source events.</p>}
   </div>:<p className="empty">Play-by-play has not been materialized for this game; no events are inferred.</p>}
  </div>}
  <p className="table-note">The original Flutter Games workspace has an asset activation plan; its Game Finder separately offers a static catalog and game-page inspector. This React route implements the latter using the original static source contract only.</p>
 </section>;
}
