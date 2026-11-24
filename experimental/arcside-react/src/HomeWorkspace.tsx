
import {useEffect,useState} from 'react';
import {getJson} from './data';
import type {JsonRow} from './data';
const asRows=(value:unknown):JsonRow[]=>Array.isArray(value)?value.filter((r):r is JsonRow=>!!r&&typeof r==='object'&&!Array.isArray(r)):[];
const obj=(value:unknown):JsonRow=>value&&typeof value==='object'&&!Array.isArray(value)?value as JsonRow:{};
const value=(r:JsonRow,...keys:string[])=>keys.map(k=>r[k]).find(x=>x!==null&&x!==undefined&&x!=='');
const text=(r:JsonRow,...keys:string[])=>String(value(r,...keys)??'—');
const numeric=(v:unknown)=>typeof v==='number'&&Number.isFinite(v)?v.toFixed(1):'—';
const metrics=[['points','Scoring','PPG'],['rebounds','Rebounding','RPG'],['assists','Assists','APG'],['steals','Steals','SPG'],['blocks','Blocks','BPG'],['deflections','Deflections','DEF/G'],['personal_fouls','Personal fouls','PF/G'],['turnovers','Turnovers','TOV/G'],['three_pointers_made','Three-pointers made','3PM/G'],['field_goals_made','Field goals made','FGM/G'],['free_throws_made','Free throws made','FTM/G']];
export function HomeWorkspace({season,onNavigate}:{season:string;onNavigate:(path:string)=>void}){
 const [loaded,setLoaded]=useState<{season:string;data:JsonRow}|null>(null),[error,setError]=useState(''),[retry,setRetry]=useState(0);
 const data=loaded?.season===season?loaded.data:null;
 useEffect(()=>{
  if(!season)return;const c=new AbortController();setError('');
  getJson('dashboard/'+season+'.json',c.signal).then(raw=>{
   if(!c.signal.aborted){const d=obj(raw);if(!Object.keys(d).length)throw Error('Invalid published dashboard');setLoaded({season,data:d})}
  }).catch(e=>{if(!c.signal.aborted)setError(String(e.message??e))});
  return ()=>c.abort();
 },[season,retry]);
 const navigate=(kind:string,key:unknown)=>{if(typeof key==='string'&&key)onNavigate('/'+kind+'/'+encodeURIComponent(key))};
 return <section className="home-workspace" aria-label="NBA Home">
  <div className="panel home-intro"><div className="panel-title"><div><p className="eyebrow">ARCSIDE / NBA RESEARCH</p><h2>NBA Dashboard</h2><p className="subtle">Published regular-season leaders, teams and historical game results · {season}</p></div></div>
   <div className="home-shortcuts">{[['/stats','Stats'],['/advanced','Advanced Stats'],['/visualizations','Visualization Studio'],['/trade','Trade Machine'],['/box-scores','Box Scores']].map(([route,label])=><button key={route} onClick={()=>onNavigate(route)}>{label} →</button>)}</div></div>
  {error?<div role="alert" className="panel home-error">{error} <button onClick={()=>setRetry(x=>x+1)}>Retry dashboard</button></div>:!data?<p role="status">Loading published season dashboard…</p>:<>
   {['player','team'].map(kind=><div key={kind}><h3>{kind==='player'?'Player':'Team'} leaders · Top 10</h3><div className="home-leaders">{metrics.map(([key,label,suffix])=>{
    const rows=asRows(obj(data[kind==='player'?'leaders':'team_leaders'])[key]).slice(0,10);
    return <section className="panel home-leader-card" key={key}><h4>{label} <small>{suffix}</small></h4>{rows.length?rows.map((r,i)=>{
     const id=value(r,kind==='player'?'player_id':'team_key',kind==='player'?'player_key':'team_id'),name=text(r,kind==='player'?'player_name':'team_name','team');
     return <div className="home-leader-row" key={String(id??i)}><small>{r.rank==null?i+1:String(r.rank)}</small><button className="text-button" disabled={typeof id!=='string'} onClick={()=>navigate(kind,id)}>{name}</button><strong>{numeric(r.value)}</strong></div>
    }):<p className="subtle">No published leaders.</p>}</section>
   })}</div></div>)}
   <h3>Teams</h3><div className="home-teams">{asRows(data.teams).map((r,i)=>{const key=value(r,'team_key','team_id');return <button disabled={typeof key!=='string'} key={String(key??i)} onClick={()=>navigate('team',key)}><strong>{text(r,'team_name','canonical_name','name','team')}</strong><small>{text(r,'abbreviation','team_abbreviation')}</small></button>})}</div>
   <h3>Recent published results</h3><div className="home-teams">{asRows(data.recent_games).map((g,i)=>{const key=value(g,'game_key','game_id');return <button key={String(key??i)} disabled={typeof key!=='string'} onClick={()=>navigate('game',key)}><small>{text(g,'game_date').split(/[T ]/)[0]}</small><strong>{text(g,'away_team_name','away_team_abbreviation','away_team')} {text(g,'away_score')} @ {text(g,'home_team_name','home_team_abbreviation','home_team')} {text(g,'home_score')}</strong></button>})}</div>
   {!asRows(data.recent_games).length&&<p className="subtle">No published game results for this dashboard.</p>}
  </>}
 </section>;
}
