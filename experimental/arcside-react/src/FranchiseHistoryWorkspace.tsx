import {useEffect,useMemo,useState} from 'react';
import type {JsonRow} from './data';
import {getTeamIndex} from './data';
const text=(v:unknown,empty='—')=>v===undefined||v===null||String(v).trim()===''?empty:String(v);
export const originalFlutterPlan=[
 {area:'Current franchise identity',priority:'P0',status:'Started',description:'Current team names, abbreviations, cities, conferences, and divisions.',examples:'Boston Celtics, LAL, Western Conference, Pacific Division'},
 {area:'Historical names and relocations',priority:'P1',status:'Planned',description:'Team name changes, city moves, predecessor clubs, and official franchise continuity.',examples:'Seattle SuperSonics to Oklahoma City Thunder, Minneapolis Lakers to Los Angeles Lakers'},
 {area:'Expansion and contraction context',priority:'P1',status:'Planned',description:'Expansion years, expansion drafts, folded franchises, and league-size changes.',examples:'Charlotte expansion, Toronto and Vancouver expansion, ABA merger additions'},
 {area:'Arenas and geography',priority:'P2',status:'Future',description:'Historical home arenas, market geography, attendance context, and city-specific franchise history.',examples:'Madison Square Garden, Crypto.com Arena, TD Garden, United Center'},
 {area:'Ownership and front office',priority:'P3',status:'Future',description:'Ownership groups, governors, presidents, general managers, coaching leadership, and front-office eras.',examples:'Ownership changes, GM tenure, coach tenure, president of basketball operations'},
 {area:'G League affiliates',priority:'P3',status:'Future',description:'Current and historical G League affiliate relationships with NBA clubs.',examples:'NBA parent club to G League affiliate mapping and historical affiliate changes'},
] as const;
export function FranchiseHistoryWorkspace({onTeam}:{onTeam:(id:string)=>void}){
 const [teams,setTeams]=useState<JsonRow[]>([]),[error,setError]=useState('');
 const [query,setQuery]=useState(''),[selected,setSelected]=useState('');
 useEffect(()=>{const controller=new AbortController();getTeamIndex(controller.signal)
  .then(setTeams).catch(e=>{if(!controller.signal.aborted)setError(String(e.message??e))});
  return ()=>controller.abort();
 },[]);
 const filtered=useMemo(()=>teams.filter(t=>[t.canonical_name,t.abbreviation,t.franchise_key,t.team_key].some(v=>
  text(v,'').toLowerCase().includes(query.trim().toLowerCase()))),[teams,query]);
 const current=teams.find(t=>t.team_key===selected)??null;
 return <section className="panel franchise-workspace" aria-label="Franchise history">
  <div className="panel-title"><div><p className="eyebrow">NBA / CURRENT IDENTITY AND HISTORICAL ROADMAP</p>
   <h2>Franchise History</h2>
   <p className="subtle">The original Flutter screen marks historical relocations and continuity as planned, not a complete verified historical franchise graph.</p></div></div>
  {error&&<p role="alert">{error}</p>}
  <div className="profile-summary">
   <div><span>PLANNED COVERAGE AREAS</span><strong>{originalFlutterPlan.length}</strong></div>
   <div><span>PUBLISHED TEAM IDENTITIES</span><strong>{teams.length}</strong></div>
   <div><span>UNFINISHED ROADMAP AREAS</span><strong>{originalFlutterPlan.filter(x=>x.status!=='Started').length}</strong></div>
  </div>
  <h3>Current and indexed team identity</h3>
  <label>Find a franchise<input aria-label="Find franchise" placeholder="Team, abbreviation, franchise key"
   value={query} onChange={e=>setQuery(e.target.value)}/></label>
  <div className="franchise-layout"><div className="franchise-list" role="region" aria-label="Published franchise identity records" tabIndex={0}>
   {filtered.slice(0,100).map((team,i)=><button key={String(team.team_key??i)}
    className={selected===team.team_key?'selected':''} onClick={()=>setSelected(String(team.team_key??''))}>
    {text(team.canonical_name)} · {text(team.abbreviation)}</button>)}
   {filtered.length>100&&<p className="subtle">Showing first 100 of {filtered.length} matching indexed team identities.</p>}
  </div><div className="franchise-inspector" aria-label="Franchise identity details">
   {!current?<p className="empty">Select an original indexed team to inspect source-recorded identity fields.</p>:<>
    <h3>{text(current.canonical_name)}</h3><dl className="financial-facts">
     {(['abbreviation','team_key','franchise_key','city','conference','division','active_from','active_to'] as const)
      .map(k=><div key={k}><dt>{k.replaceAll('_',' ')}</dt><dd>{text(current[k])}</dd></div>)}
    </dl>
    <button onClick={()=>onTeam(text(current.team_key,''))}>Open team detail</button>
    <p className="subtle">The indexed franchise key is a source identifier; it does not independently certify a complete relocation or predecessor relationship.</p>
   </>}
  </div></div>
  <h3>Original Flutter franchise-history build plan</h3>
  <div className="table-scroll" role="region" tabIndex={0} aria-label="Franchise history build plan">
   <table className="stats-table"><thead><tr><th>Priority</th><th>Area</th><th>Status</th><th>Description</th><th>Examples</th></tr></thead>
    <tbody>{originalFlutterPlan.map(item=><tr key={item.area}><td>{item.priority}</td><td>{item.area}</td>
     <td>{item.status}</td><td>{item.description}</td><td>{item.examples}</td></tr>)}</tbody></table>
  </div>
  <p className="table-note">This reproduces the original planning-stage module and adds searchable identities from the canonical static team index. Verified franchise-continuity histories, arena eras and ownership records require new source-backed data before they can be considered implemented.</p>
 </section>;
}
