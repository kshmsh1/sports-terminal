import {useEffect,useMemo,useState} from 'react';
import type {JsonRow} from './data';
import {getGameDetail,getGameIndex} from './data';
const asRows=(v:unknown):JsonRow[]=>Array.isArray(v)?v.filter((r):r is JsonRow=>r!==null&&typeof r==='object'&&!Array.isArray(r)):[];
const val=(r:JsonRow,k:string,fallback='—')=>r[k]===null||r[k]===undefined||String(r[k]).trim()===''?fallback:String(r[k]);
const num=(r:JsonRow,k:string):number|null=>{
 const v=r[k];if(typeof v==='number'&&Number.isFinite(v))return v;
 return typeof v==='string'&&v.trim()!==''&&Number.isFinite(Number(v))?Number(v):null;
};
const team=(r:JsonRow,away:boolean)=>val(r,away?'away_team_abbreviation':'home_team_abbreviation',
 val(r,away?'away_team':'home_team','—'));
const segment=(r:JsonRow)=>{
 const text=String(r.season_type??r.seasonType??r.segment??'').toLowerCase();
 return text.includes('play')||text.includes('post')?'playoffs':'regular';
};
const columns=['minutes','pts','reb','ast','stl','blk','tov','fgm','fga','three_pm','three_pa','ftm','fta'] as const;
export function BoxScoresWorkspace({onPlayer}:{onPlayer?:(id:string)=>void}){
 const [games,setGames]=useState<JsonRow[]>([]);
 const [loading,setLoading]=useState(true);
 const [error,setError]=useState('');
 const [year,setYear]=useState('All'),[type,setType]=useState('All'),[query,setQuery]=useState('');
 const [selected,setSelected]=useState<JsonRow|null>(null);
 const [page,setPage]=useState(0);
 const pageSize=50;
 const [detail,setDetail]=useState<JsonRow|null>(null),[detailLoading,setDetailLoading]=useState(false);
 const [detailError,setDetailError]=useState('');
 const [selectedTeam,setSelectedTeam]=useState<string>('');
 const [player,setPlayer]=useState<JsonRow|null>(null);
 useEffect(()=>{const controller=new AbortController();setLoading(true);
  getGameIndex(controller.signal).then(rows=>setGames(rows.sort((a,b)=>val(b,'game_date','').localeCompare(val(a,'game_date','')))))
   .catch(e=>{if(!controller.signal.aborted)setError(String(e.message??e))})
   .finally(()=>{if(!controller.signal.aborted)setLoading(false)});
  return ()=>controller.abort();
 },[]);
 useEffect(()=>{if(!selected){setDetail(null);return}
  const controller=new AbortController();setDetail(null);setDetailError('');setDetailLoading(true);
  getGameDetail(selected,controller.signal).then(value=>{if(!controller.signal.aborted)setDetail(value)}).catch(e=>{
   if(!controller.signal.aborted)setDetailError(String(e.message??e))
  }).finally(()=>{if(!controller.signal.aborted)setDetailLoading(false)});
  return ()=>controller.abort();
 },[selected]);
 const seasons=useMemo(()=>[...new Set(games.map(g=>val(g,'season_id','')).filter(Boolean))].sort().reverse(),[games]);
 const filtered=useMemo(()=>games.filter(g=>(year==='All'||val(g,'season_id')===year)&&
  (type==='All'||segment(g)===type)&&
  [val(g,'game_date'),team(g,true),team(g,false),val(g,'game_key')].join(' ').toLowerCase().includes(query.trim().toLowerCase())),
 [games,year,type,query]);
 const pages=Math.max(1,Math.ceil(filtered.length/pageSize));
 const currentPage=Math.min(page,pages-1);
 useEffect(()=>{setPage(0);setSelected(null);setPlayer(null)},[year,type,query]);
 const away=selected?team(selected,true):'',home=selected?team(selected,false):'';
 const side=selectedTeam===home?home:away;
 const rawPlayers=asRows(detail?.player_box_scores);
 const playerRows=rawPlayers.filter(p=>val(p,'team_abbreviation')===side)
  .sort((a,b)=>(num(b,'pts')??-1)-(num(a,'pts')??-1));
 return <section className="panel box-workspace" aria-label="Historical NBA box scores">
  <div className="panel-title"><div><p className="eyebrow">NBA / ORIGINAL HISTORICAL ARCHIVE</p><h2>Box Scores</h2>
   <p className="subtle">Select games by date and open published box-score files. Absent player statistics are not inferred.</p></div></div>
  <div className="toolbar"><label>Season<select aria-label="Box score season" value={year} onChange={e=>setYear(e.target.value)}><option>All</option>{seasons.map(s=><option key={s}>{s}</option>)}</select></label>
   <label>Season type<select aria-label="Box score segment" value={type} onChange={e=>setType(e.target.value)}><option>All</option><option value="regular">Regular season</option><option value="playoffs">Playoffs</option></select></label>
   <label>Search games<input aria-label="Search historical games" placeholder="Team, date, game ID" value={query} onChange={e=>setQuery(e.target.value)}/></label></div>
  {error&&<p role="alert">{error}</p>}{loading&&<p role="status">Loading published game index…</p>}
  <div className="box-layout"><div className="box-index" role="region" aria-label="Historical games" tabIndex={0}>
   <p className="subtle">{filtered.length.toLocaleString()} published games</p>
   {filtered.slice(currentPage*pageSize,(currentPage+1)*pageSize).map((g,i)=>{const key=val(g,'game_key',String(i));
    return <button className={selected===g?'box-game selected':''} aria-pressed={selected===g}
     key={key+':'+i} onClick={()=>{setSelected(g);setSelectedTeam(team(g,true));setPlayer(null)}}>
     <small>{val(g,'game_date').split(/[T ]/)[0]} · {segment(g)==='playoffs'?'Playoffs':'Regular season'}</small>
     <strong>{team(g,true)} {val(g,'away_score')} @ {team(g,false)} {val(g,'home_score')}</strong>
     <small>{g.box_score_available===true?'Box score published':'Box score may be unavailable'}</small>
    </button>;
   })}
   {!filtered.length&&<p className="subtle">No matching published games.</p>}
  </div>
  <div className="box-inspector" aria-label="Game box-score inspector">
   {!selected?<p className="empty">Choose a historical game to inspect its published box score.</p>:<>
    <div className="row-wrap"><h3>{away} @ {home}</h3><button onClick={()=>{setSelected(null);setPlayer(null)}}>Close game</button></div>
    <p className="subtle">{val(selected,'game_date')} · {val(selected,'season_id')} · {segment(selected)}</p>
    <div className="box-score-strip"><strong>{away} · {val(selected,'away_score')}</strong><strong>{home} · {val(selected,'home_score')}</strong></div>
    {detailLoading&&<p role="status">Loading published individual box score…</p>}
    {detailError&&<p role="alert">Individual box scores unavailable: {detailError}</p>}
    {!detailLoading&&!detailError&&rawPlayers.length===0&&<p className="empty">Individual box scores are not available for this game in the local static archive.</p>}
    {!!rawPlayers.length&&<>
     <h3>Team box scores</h3><div className="row-wrap" role="group" aria-label="Box score team">
      {[away,home].map(t=><button key={t} aria-pressed={side===t} className={side===t?'selected':''} onClick={()=>{setSelectedTeam(t);setPlayer(null)}}>{t}</button>)}</div>
     {asRows(detail?.team_box_scores).filter(r=>val(r,'team_abbreviation')===side).map((r,i)=>
      <p key={i} className="subtle">{side} · {val(r,'pts')} PTS · {val(r,'reb')} REB · {val(r,'ast')} AST</p>)}
     <div className="table-scroll" role="region" tabIndex={0} aria-label="Individual game box score">
      <table className="stats-table"><thead><tr><th scope="col">Player</th>{columns.map(c=><th scope="col" key={c}>{c.toUpperCase()}</th>)}</tr></thead>
       <tbody>{playerRows.map((r,i)=><tr key={String(r.player_id??i)}>
        <td className="box-player-cell"><button className="box-player-button" onClick={()=>setPlayer(r)}>{val(r,'player_name','Player')}</button></td>
        {columns.map(c=><td className="numeric" key={c}>{val(r,c)}</td>)}</tr>)}</tbody>
      </table></div>
     {player&&<div className="box-spotlight"><strong>{val(player,'player_name')}</strong>
      <p>{columns.map(c=>c.toUpperCase()+': '+val(player,c)).join(' · ')}</p>
      {onPlayer&&typeof player.player_id==='string'&&<button onClick={()=>onPlayer(player.player_id as string)}>Open player profile</button>}
     </div>}
    </>}
   </>}
  </div></div>
  <div className="box-pagination" aria-label="Historical game pages"><button disabled={currentPage===0} onClick={()=>setPage(currentPage-1)}>Previous page</button><span>{filtered.length?currentPage*pageSize+1:0}–{Math.min((currentPage+1)*pageSize,filtered.length)} of {filtered.length.toLocaleString()} · Page {currentPage+1} of {pages}</span><button disabled={currentPage>=pages-1} onClick={()=>setPage(currentPage+1)}>Next page</button></div>
  <p className="table-note">All displayed games and player lines are read from the original immutable NBA v5 index and per-game detail files. No synthetic game scores are used.</p>
 </section>;
}
