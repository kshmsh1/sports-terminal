
import {useEffect,useMemo,useState} from 'react';
import {getPlayerIndex,getTeamIndex} from './data';
import type {JsonRow} from './data';
const val=(r:JsonRow,keys:string[])=>keys.map(k=>r[k]).find(v=>typeof v==='string'&&v.trim()) as string|undefined;
const normalized=(s:string)=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim();
type Match={key:string;name:string;kind:'player'|'team';detail:string;search:string};
export function GlobalSearch({onNavigate}:{onNavigate:(path:string)=>void}){
 const [open,setOpen]=useState(false),[query,setQuery]=useState(''),[items,setItems]=useState<Match[]|null>(null),[error,setError]=useState('');
 useEffect(()=>{
  if(!open||items)return;
  const c=new AbortController();setError('');
  Promise.all([getPlayerIndex(c.signal),getTeamIndex(c.signal)]).then(([players,teams])=>{
   if(c.signal.aborted)return;
   const convert=(rows:JsonRow[],kind:'player'|'team'):Match[]=>rows.flatMap(row=>{
    const key=val(row,kind==='player'?['player_key','player_id']:['team_key','team_id']);
    const name=val(row,['canonical_name',kind==='player'?'player_name':'team_name','name']);
    if(!key||!name)return [];
    const detail=[val(row,kind==='player'?['primary_position','position']:['abbreviation']),val(row,['active_from']),val(row,['active_to'])].filter(Boolean).join(' · ');
    return [{key,name,kind,detail,search:normalized(name+' '+key+' '+detail)}];
   });
   setItems([...convert(players,'player'),...convert(teams,'team')]);
  }).catch(e=>{if(!c.signal.aborted)setError(String(e.message??e))});
  return ()=>c.abort();
 },[open,items]);
 const matches=useMemo(()=>{const q=normalized(query);if(!items||!q)return [];
  return items.filter(x=>x.search.includes(q)).sort((a,b)=>Number(normalized(b.name).startsWith(q))-Number(normalized(a.name).startsWith(q))||a.name.localeCompare(b.name)).slice(0,16);
 },[items,query]);
 function close(){setOpen(false);setQuery('')}
 return <div className="global-search" onKeyDown={e=>{if(e.key==='Escape'){e.preventDefault();close()}}}>
  <input aria-label="Search players and teams" aria-expanded={open} aria-controls="arcside-global-results" placeholder="Search players & teams" value={query} onFocus={()=>setOpen(true)} onChange={e=>{setQuery(e.target.value);setOpen(true)}}/>
  {open&&<div className="global-search-results" id="arcside-global-results" role="region" aria-label="Global search results">
   <div className="row-wrap global-search-heading"><strong>NBA historical index</strong><button aria-label="Close search" onClick={close}>×</button></div>
   {error?<p role="alert">{error}</p>:!items?<p role="status">Loading published player and team index…</p>:!query.trim()?<p className="subtle">Search across all published historical player and team identities.</p>:!matches.length?<p className="subtle">No matching records.</p>:matches.map(m=><button key={m.kind+':'+m.key} onClick={()=>{onNavigate('/'+m.kind+'/'+encodeURIComponent(m.key));close()}}><span>{m.name}</span><small>{m.kind} · {m.detail}</small></button>)}
  </div>}
 </div>;
}
