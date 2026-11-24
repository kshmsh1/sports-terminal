
import type {TradeAsset} from './tradeEngine';
import type {OriginalTradeException} from './data';
import {canonicalTeam,nbaTeams,sameTeam,signAndTradeAsset} from './TradeWorkspaceModel';
import type {TradeContext} from './TradeWorkspaceModel';
type LegacySnapshot={id:string;savedAt:string;teams:string[];date:string;mode:'on'|'off'|'deadline';routes:{id:string;origin:string;destination:string;salary:number}[];tpes:Record<string,string>;renounced:string[]};
const obj=(v:unknown):Record<string,unknown>=>v&&typeof v==='object'&&!Array.isArray(v)?v as Record<string,unknown>:{};
const str=(v:unknown)=>typeof v==='string'?v:'';
const amount=(v:unknown)=>typeof v==='number'&&Number.isFinite(v)?v:NaN;
export function convertLegacyTrades(raw:unknown[],library:TradeAsset[],ctx:TradeContext,exceptions:OriginalTradeException[]){
 const trades:LegacySnapshot[]=[],rejected:string[]=[];
 for(const [i,item] of raw.entries()){
  try{
   const s=obj(item),id=str(s.id),savedAt=str(s.saved_at_iso);
   if(!id||!savedAt||!Number.isFinite(Date.parse(savedAt))||!Array.isArray(s.teams)||!s.teams.every(t=>typeof t==='string'))throw Error('Invalid identity or teams');
   const teams=(s.teams as string[]).map(canonicalTeam);
   if(teams.length<2||teams.length>5||new Set(teams).size!==teams.length||teams.some(t=>!nbaTeams.some(x=>x[0]===t)))throw Error('Invalid participating teams');
   const mode=s.restriction_mode==='off'?'off':s.restriction_mode==='deadline'?'deadline':'on';
   const routes:LegacySnapshot['routes']=[],tpes:Record<string,string>={};
   const add=(asset:TradeAsset|undefined,dest:unknown)=>{
    const destination=canonicalTeam(str(dest));
    if(!asset||!teams.includes(asset.originTeam)||!teams.includes(destination)||asset.originTeam===destination||routes.some(r=>r.id===asset.id))throw Error('Unresolved, duplicate or invalid asset route');
    routes.push({id:asset.id,origin:asset.originTeam,destination,salary:asset.salary});
   };
   for(const [asset,dest] of Object.entries(obj(s.routes))){
    // Original IDs are authoritative. Normalize only the known team alias prefix.
    const candidates=library.filter(a=>a.id===asset);
    if(candidates.length!==1)throw Error('Unresolved source asset '+asset);
    add(candidates[0],dest);
   }
   for(const [team,value] of Object.entries(obj(s.cash_amounts))){
    const salary=amount(value);if(salary===0)continue;
    const origin=canonicalTeam(team),cash=ctx.cash.find(x=>sameTeam(x.team,origin));
    if(!cash||!Number.isFinite(salary)||salary<=0||salary>cash.availableToSend)throw Error('Invalid dated cash amount');
    add({id:'cash:'+origin,originTeam:origin,type:'cash',label:'Cash considerations',salary},obj(s.cash_destinations)[team]);
   }
   for(const [asset,dest] of Object.entries(obj(s.sign_and_trade_destinations))){
    const right=ctx.freeAgents.find(x=>x.id===asset),salary=amount(obj(s.sign_and_trade_salaries)[asset]);
    add(right?signAndTradeAsset(right,salary)??undefined:undefined,dest);
   }
   for(const [asset,value] of Object.entries(obj(s.acquisition_mechanisms))){
    const selected=str(value);if(!selected||selected==='match')continue;
    if(!selected.startsWith('tpe:'))throw Error('Unsupported acquisition mechanism');
    const id=selected.slice(4),route=routes.find(x=>x.id===asset);
    if(!route||!exceptions.some(x=>x.id===id&&sameTeam(x.team,route.destination)))throw Error('Unresolved receiving exception');
    tpes[asset]=id;
   }
   const renounced=Array.isArray(s.renounced_free_agent_rights)?s.renounced_free_agent_rights:[];
   if(renounced.some(id=>typeof id!=='string'||!ctx.freeAgents.some(x=>x.id===id&&teams.includes(canonicalTeam(x.team)))||routes.some(x=>x.id===id)))throw Error('Unresolved renounced right');
   if(!routes.length)throw Error('Empty snapshot');
   // Flutter stored a mode rather than a date. Preserve the actual video screen date.
   trades.push({id:'flutter:'+id,savedAt,teams,date:'2026-09-30',mode,routes,tpes,renounced:renounced as string[]});
  }catch(e){rejected.push('Snapshot '+(i+1)+': '+String(e instanceof Error?e.message:e)+'.')}
 }
 return {trades,rejected};
}
