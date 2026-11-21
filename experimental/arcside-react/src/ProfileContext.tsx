import type {JsonRow} from './data';
type Row=JsonRow;
const rows=(x:unknown):Row[]=>Array.isArray(x)?x.filter((v):v is Row=>v!==null&&typeof v==='object'&&!Array.isArray(v)):[];
const fmt=(x:unknown)=>x===null||x===undefined||String(x).trim()===''?'—':String(x);
const year=(x:unknown)=>Number.isFinite(Number(x))?Number(x):null;
const money=(v:unknown)=>{
 const n=Number(v);if(!Number.isFinite(n)||v==null||v==='')return '—';
 return '$'+Math.round(n).toLocaleString('en-US');
};
const groupHonors=(dossier:Row)=>{
 const awards=rows(dossier.awards),stars=rows(dossier.all_star),draft=rows(dossier.draft);
 const honors=new Map<string,Set<string>>();
 for(const row of awards){
  const label=String(row.award??row.award_name??row.award_type??row.description??'').trim();
  const season=String(row.season_id??row.season??row.year??'').trim();
  if(!label)continue;
  if(!honors.has(label))honors.set(label,new Set());
  if(season)honors.get(label)?.add(season);
 }
 if(stars.length){
  const seasons=new Set(stars.map(r=>String(r.season_id??r.season??r.year??'').trim()).filter(Boolean));
  honors.set('All-Star',seasons);
 }
 return {awards:[...honors].map(([title,seasons])=>({title,seasons:[...seasons].sort()})),draft};
};
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
export function ProfileContracts({dossier}: {dossier:Row}){
 const contracts=rows(dossier.contracts);
 return <section className="panel profile-contract-panel" aria-label="Player contract">
  <div className="panel-title"><div><p className="eyebrow">ORIGINAL SOURCE CONTEXT</p><h2>Contract</h2></div></div>
  {!contracts.length?<p className="empty">No registered contract record is available in this player dossier. The original Flutter profile may additionally resolve a separately maintained front-office registry and dated 2026–27 trade-contract snapshot; those feeds are not yet joined to React.</p>:
   <div className="contract-list">{contracts.map((r,i)=><div key={i} className="contract-entry">
    <strong>{fmt(r.team_id)} · {fmt(r.season)}</strong>
    <div>{rows(r.years).map((item,j)=><p key={j}>{fmt(item.season)} · {money(item.salary)} · {money(item.guaranteed_amount)} guaranteed</p>)}</div>
   </div>)}</div>}
 </section>;
}
export function ProfileHonors({dossier}: {dossier:Row}){
 const {awards,draft}=groupHonors(dossier),record=draft[0];
 return <section className="panel profile-honors-panel" aria-label="Player awards and context">
  <div className="panel-title"><div><p className="eyebrow">ORIGINAL PUBLISHED DOSSIER</p><h2>Awards & context</h2></div></div>
  {record&&<p className="subtle">Draft · {fmt(record.draft_year)} · Round {fmt(record.round_text)} · Pick {fmt(record.pick_number)} · {fmt(record.drafting_team_text)}</p>}
  {!awards.length&&!record?<p className="empty">No confirmed source-backed award or draft data is available.</p>:
   <div className="profile-award-grid">{awards.map(a=><div key={a.title}><strong>{a.title}</strong>
    <p>{a.seasons.length}x: {a.seasons.length?a.seasons.join(', '):'Source did not include seasons'}</p></div>)}</div>}
 </section>;
}
export function profileContextCounts(dossier:Row){
 const a=groupHonors(dossier);
 return {nbaSeasons:countYears(rows(dossier.regular_seasons)),
  playoffSeasons:countYears(rows(dossier.playoff_seasons)),
  allStarYears:new Set(rows(dossier.all_star).map(r=>r.season_id??r.season??r.year).filter(Boolean)).size,
  honors:a.awards.length,draftEntries:a.draft.length};
}
