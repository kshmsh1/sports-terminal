import type {JsonRow,DatedContractSnapshot} from './data';
import {profileHonors} from './profileHonors';
type Row=JsonRow;
const rows=(x:unknown):Row[]=>Array.isArray(x)?x.filter((v):v is Row=>v!==null&&typeof v==='object'&&!Array.isArray(v)):[];
const fmt=(x:unknown)=>x===null||x===undefined||String(x).trim()===''?'—':String(x);
const money=(v:unknown)=>{
 const n=Number(v);if(!Number.isFinite(n)||v==null||v==='')return '—';
 return '$'+Math.round(n).toLocaleString('en-US');
};
const groupHonors=(dossier:Row)=>({
 awards:profileHonors(rows(dossier.awards),rows(dossier.all_star)),
 draft:rows(dossier.draft)
});
const countYears=(data:Row[])=>new Set(data.map(r=>r.season_id).filter(Boolean)).size;
export function ProfileSummary({dossier}: {dossier:Row}){
 const regular=rows(dossier.regular_seasons),playoffs=rows(dossier.playoff_seasons);
 const stars=rows(dossier.all_star);
 const starYears=new Set(stars.map(r=>r.season_id??r.season??r.year).filter(Boolean)).size;
 return <div className="profile-summary" aria-label="Player career summary">
  <div><span>NBA SEASONS</span><strong>{countYears(regular)}</strong></div>
  <div><span>PLAYOFF SEASONS</span><strong>{countYears(playoffs)}</strong></div>
  <div><span>ALL-STAR</span><strong>{starYears}</strong></div>
 </div>;
}
const normalizedName=(v:string)=>v.toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();
export function ProfileContracts({dossier,dated,registry,playerKey,playerName,loading=false}:{
 dossier:Row;dated:DatedContractSnapshot|null;registry:Row[];
 playerKey:string;playerName:string;loading?:boolean;
}){
 // Mirror original Flutter profile priority: dated authoritative snapshot
 // first, then the published front-office contract registry.
 const matchingDated=dated?.records.filter(item=>
  normalizedName(item.player)===normalizedName(playerName)&&
  Number(item.salaries['2026-27']??0)>0)??[];
 const matches=registry.flatMap(wrapper=>{
  const record=wrapper.record;
  if(!record||Array.isArray(record)||typeof record!=='object')return [];
  const row=record as Row;
  if(String(row.player_id??'')===playerKey||
     String(row.player_name??'').trim().toLowerCase()===playerName.toLowerCase())return [row];
  return [];
 });
 const dossierContracts=rows(dossier.contracts);
 return <section className="panel profile-contract-panel" aria-label="Player contract">
  <div className="panel-title"><div><p className="eyebrow">ORIGINAL SOURCE CONTEXT</p><h2>Contract</h2></div></div>
  {loading&&<p className="subtle" role="status">Checking original published salary records...</p>}
  {matchingDated.length>0?<>
   <h3>2026–27 · Current salary record</h3>
   {matchingDated.map(item=><p key={item.id}>{item.team} · {money(item.salaries['2026-27'])} salary
    {item.guaranteed!==null?' · '+money(item.guaranteed)+' source-reported guarantee':''}</p>)}
   <p className="subtle">Source: {matchingDated[0].sourceLabel} · as of {dated?.asOf}. This is a dated salary snapshot, not a verified live contract feed.</p>
  </>:matches.length>0?<div className="contract-list">
   {matches.map((row,i)=><div key={i} className="contract-entry">
    <strong>{fmt(row.team_id)} · {fmt(row.season)}</strong>
    {rows(row.years).map((year,j)=><p key={j}>{fmt(year.season)} · {money(year.salary)} · {money(year.guaranteed_amount)} guaranteed</p>)}
   </div>)}
  </div>:dossierContracts.length>0?<div className="contract-list">
   <p className="subtle">Historical dossier contract rows (not the original front-office registry)</p>
   {dossierContracts.map((row,i)=><div key={i} className="contract-entry">
    <strong>{fmt(row.team_id)} · {fmt(row.season)}</strong>
    {rows(row.years).map((year,j)=><p key={j}>{fmt(year.season)} · {money(year.salary)} · {money(year.guaranteed_amount)} guaranteed</p>)}
   </div>)}
  </div>:<p className="empty">No registered contract record is currently available for this player. Historical statistics remain independent of contract-data availability.</p>}
 </section>;
}
export function ProfileHonors({dossier}: {dossier:Row}){
 const {awards,draft}=groupHonors(dossier),record=draft[0];
 return <section className="panel profile-honors-panel" aria-label="Player awards and context">
  <div className="panel-title"><div><p className="eyebrow">ORIGINAL PUBLISHED DOSSIER</p><h2>Awards & context</h2></div></div>
  {record&&<p className="subtle">Draft · {fmt(record.draft_year)} · Round {fmt(record.round_text)} · Pick {fmt(record.pick_number)} · {fmt(record.drafting_team_text)}</p>}
  {!awards.length&&!record?<p className="empty">No confirmed source-backed award or draft data is available.</p>:
   <div className="profile-award-grid">{awards.map(a=><div key={a.title}><strong>{a.title}</strong>
    <p>{a.years.length}x: {a.years.length?a.years.join(', '):'Source did not include seasons'}</p></div>)}</div>}
 </section>;
}
export function profileContextCounts(dossier:Row){
 const a=groupHonors(dossier);
 return {nbaSeasons:countYears(rows(dossier.regular_seasons)),
  playoffSeasons:countYears(rows(dossier.playoff_seasons)),
  allStarYears:new Set(rows(dossier.all_star).map(r=>r.season_id??r.season??r.year).filter(Boolean)).size,
  honors:a.awards.length,draftEntries:a.draft.length};
}
