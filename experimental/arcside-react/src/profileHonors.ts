// Original Flutter helper reference: lib/services/nba_player_profile_format.dart.
// Selection years refer to season END year. Source ballots alone are not wins.
import type {JsonRow} from './data';
export interface Honor {title:string;years:number[]}
export function orderedPositions(raw:string){
 const allowed=['PG','SG','SF','PF','C'];
 const words=new Set((raw.toUpperCase().match(/(?<![A-Z])(?:PG|SG|SF|PF|C)(?![A-Z])/g)??[]));
 return allowed.filter(pos=>words.has(pos)).join(', ');
}
function awardYear(row:JsonRow){
 const season=String(row.season_id??row.year??'');
 const matched=season.match(/^(?:19|20)\d{2}/);
 if(!matched)return null;
 const start=Number(matched[0]);return season.includes('-')?start+1:start;
}
function honorName(raw:string):string|null{
 const name=raw.toLowerCase().trim().replace(/[_-]+/g,' ').replace(/\s+/g,' ');
 if(!name)return null;
 if(name.includes('finals')&&name.includes('mvp'))return 'Finals Most Valuable Player (Finals MVP)';
 if(name==='mvp'||name==='nba mvp'||name.includes('most valuable player'))return 'Most Valuable Player (MVP)';
 if(name==='nba roy'||name==='roy'||name.includes('rookie of the year'))return 'Rookie of the Year (ROY)';
 if(name==='nba dpoy'||name==='dpoy'||name.includes('defensive player of the year'))return 'Defensive Player of the Year (DPOY)';
 if(name==='nba mip'||name==='mip'||name.includes('most improved'))return 'Most Improved Player (MIP)';
 if(name.includes('sixth man')||name==='6moy')return 'Sixth Man of the Year (6MOY)';
 if(name.includes('all nba'))return 'All-NBA Team';
 if(name.includes('all defense')||name.includes('all defensive'))return 'All-Defensive Team';
 if(name.includes('all rookie'))return 'All-Rookie Team';
 if(name.includes('scoring champion'))return 'Scoring Champion';
 if(name.includes('assist champion'))return 'Assists Leader';
 if(name.includes('rebound champion'))return 'Rebounds Leader';
 if(name.includes('steals leader'))return 'Steals Leader';
 if(name.includes('blocks leader'))return 'Blocks Leader';
 if(name==='all star'||name==='allstar')return 'NBA All-Star';
 return raw.replaceAll('_',' ').split(' ').filter(Boolean).map(part=>
  part.length<=3&&part===part.toUpperCase()?part:part[0].toUpperCase()+part.slice(1).toLowerCase()).join(' ');
}
export function profileHonors(awards:JsonRow[],allStar:JsonRow[]=[]):Honor[]{
 const years=new Map<string,Set<number>>();
 const include=(title:string,year:number)=>{
  if(!years.has(title))years.set(title,new Set());
  years.get(title)?.add(year);
 };
 for(const row of awards){
  const title=honorName(String(row.award??row.award_name??''));
  const year=awardYear(row);
  if(title===null||year===null)continue;
  const won=row.winner===true||row.winner===1||String(row.winner).toLowerCase()==='true';
  if(!won&&!title.startsWith('All-')&&title!=='NBA All-Star')continue;
  include(title,year);
 }
 for(const row of allStar){
  const year=awardYear(row);
  if(year!==null)include('NBA All-Star',year);
 }
 return [...years].map(([title,ys])=>({title,years:[...ys].sort((a,b)=>a-b)}))
  .sort((a,b)=>b.years.length-a.years.length||a.title.localeCompare(b.title));
}
