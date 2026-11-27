
import type {DatedContractRecord,OriginalDraftAsset,TeamCapLedgerRecord,OriginalTradeException} from './data';
import type {TeamFinancialRecord} from './FinancialsWorkspace';
import type {TradeAsset,TradeAssignment,TradeScenario,TradeReport} from './tradeEngine';
import {nba2026Cap,validateTrade} from './tradeEngine';


export const nbaTeams=[
 ['ATL','Atlanta Hawks','East'],['BOS','Boston Celtics','East'],['BKN','Brooklyn Nets','East'],
 ['CHA','Charlotte Hornets','East'],['CHI','Chicago Bulls','East'],['CLE','Cleveland Cavaliers','East'],
 ['DAL','Dallas Mavericks','West'],['DEN','Denver Nuggets','West'],['DET','Detroit Pistons','East'],
 ['GSW','Golden State Warriors','West'],['HOU','Houston Rockets','West'],['IND','Indiana Pacers','East'],
 ['LAC','LA Clippers','West'],['LAL','Los Angeles Lakers','West'],['MEM','Memphis Grizzlies','West'],
 ['MIA','Miami Heat','East'],['MIL','Milwaukee Bucks','East'],['MIN','Minnesota Timberwolves','West'],
 ['NOP','New Orleans Pelicans','West'],['NYK','New York Knicks','East'],['OKC','Oklahoma City Thunder','West'],
 ['ORL','Orlando Magic','East'],['PHI','Philadelphia 76ers','East'],['PHX','Phoenix Suns','West'],
 ['POR','Portland Trail Blazers','West'],['SAC','Sacramento Kings','West'],['SAS','San Antonio Spurs','West'],
 ['TOR','Toronto Raptors','East'],['UTA','Utah Jazz','West'],['WAS','Washington Wizards','East']
] as const;
export const canonicalTeam=(team:string)=>({BRK:'BKN',CHO:'CHA',PHO:'PHX'} as Record<string,string>)[team]??team;
export const nameForTeam=(team:string)=>nbaTeams.find(x=>x[0]===team)?.[1]??team;
export const sameTeam=(a:string,b:string)=>canonicalTeam(a)===canonicalTeam(b);
export const person=(name:string)=>name.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]/g,'');
export interface TradeContext {
 kind:string;sourceNote:string;hashes:string[];
 restrictions:{player:string;team:string;eligibleDate:string;veto:boolean}[];
 tradeKickers:{player:string;team:string;percent:number;status:string}[];
 partial:{player:string;amount:number}[];
 cash:{team:string;availableToSend:number;availableToReceive:number;restricted:boolean}[];
 cashLimit:number;
 transactions:{date:string;summary:string;teams:string[]}[];
 twoWays:{player:string;team:string;position:string;signedDate:string}[];
 rights:{id:string;team:string;player:string;position:string;note:string}[];
 freeAgents:{id:string;team:string;player:string;position:string;capHold:number;rights:string;minimum:number|null;maximum:number|null}[];
 positions:Record<string,string>;
}
export function capTier(ledger:TeamCapLedgerRecord,fin?:TeamFinancialRecord){
 if(fin?.hardCap==='first')return '1st Apron (Hard-Cap)';
 if(fin?.hardCap==='second')return '2nd Apron (Hard-Cap)';
 if(fin)return fin.secondApronSpace<0?'2nd Apron':fin.firstApronSpace<0?'1st Apron':fin.taxSpace<0?'Luxury Tax':fin.capSpace<0?'Over The Cap':'Cap Space';
 if(ledger.hardCap==='first')return '1st Apron (Hard-Cap)';
 if(ledger.hardCap==='second')return '2nd Apron (Hard-Cap)';
 const c=nba2026Cap(ledger.team,ledger.salaryPosition);
 return c.teamSalary>c.secondApron?'2nd Apron':c.teamSalary>c.firstApron?'1st Apron':c.teamSalary>c.taxLine?'Luxury Tax':c.teamSalary>c.salaryCap?'Over The Cap':'Cap Space';
}
export function playerFlags(player:DatedContractRecord,ctx:TradeContext){
 const match=(p:{player:string;team:string})=>sameTeam(p.team,player.team)&&person(p.player)===person(player.player);
 return {restriction:ctx.restrictions.find(match),kicker:ctx.tradeKickers.find(match),
  partial:ctx.partial.find(p=>person(p.player)===person(player.player)),twoWay:ctx.twoWays.find(match)};
}
export function playerAsset(player:DatedContractRecord,ctx:TradeContext):TradeAsset{
 const f=playerFlags(player,ctx);
 return {id:player.id,label:player.player,type:'player',originTeam:canonicalTeam(player.team),salary:player.salaries['2026-27'],
 metadata:{source:player.sourceLabel,guaranteed_amount:player.guaranteed,
  protected_amount:f.partial?.amount,trade_restricted_until:f.restriction?.eligibleDate,no_trade:f.restriction?.veto,
  trade_kicker:f.kicker?.status==='active'?f.kicker.percent:undefined,two_way:!!f.twoWay}};
}
export function twoWayAsset(p:TradeContext['twoWays'][number]):TradeAsset{
 return {id:'two-way:'+p.team+':'+p.player.toLowerCase().replace(/[^a-z0-9]+/g,'-'),label:p.player,originTeam:canonicalTeam(p.team),type:'player',salary:0,metadata:{two_way:true,position:p.position}};
}
export function rightAsset(p:TradeContext['rights'][number]):TradeAsset{
 return {id:p.id,label:p.player+' (draft rights)',originTeam:canonicalTeam(p.team),type:'draftRights',salary:0,metadata:{position:p.position,source:'User-supplied Trade Machine recording 2026-09-30'}};
}
export function signAndTradeAsset(p:TradeContext['freeAgents'][number],salary:number):TradeAsset|null{
 if(p.minimum===null||p.maximum===null||!Number.isFinite(salary)||salary<p.minimum||salary>p.maximum)return null;
 return {id:p.id,label:p.player+' (sign-and-trade)',originTeam:canonicalTeam(p.team),type:'player',salary,metadata:{sign_and_trade:true,free_agent_rights:p.rights,cap_hold:p.capHold}};
}
export function draftAsset(p:OriginalDraftAsset):TradeAsset{
 return {id:p.id,label:p.label,originTeam:canonicalTeam(p.team),type:'draftPick',salary:0,
 metadata:{draft_year:p.year,round:String(p.round),frozen:p.frozen||!p.tradable,stepien_safe:p.stepienSafe,swap_right:p.swapRight,
  protection:p.protection,conveyance_uncertain:p.conditional,source:p.source}};
}
export function buildSourceScenario(teams:string[],assignments:TradeAssignment[],date:string,
 ledgers:TeamCapLedgerRecord[],financials:TeamFinancialRecord[],ctx:TradeContext):TradeScenario|null{
 if(teams.length<2||teams.length>5||new Set(teams).size!==teams.length||!/^202[67]-\d{2}-\d{2}$/.test(date)||date<'2026-07-01'||date>'2027-06-30')return null;
 const parsedDate=new Date(date+'T00:00:00Z');if(!Number.isFinite(parsedDate.getTime())||parsedDate.toISOString().slice(0,10)!==date)return null;
 const capContexts:TradeScenario['capContexts']={};
 for(const team of teams){
  const l=ledgers.find(x=>sameTeam(x.team,team)),f=financials.find(x=>sameTeam(x.team,team)),cash=ctx.cash.find(x=>sameTeam(x.team,team));
  if(!l||!f||!cash)return null;
  const base=nba2026Cap(team,l.salaryPosition);
  // Match the original video workflow: cap allocation for room teams; first-apron allocation otherwise.
  const transactionSalary=f.capSpace>0?base.salaryCap-f.capSpace:base.firstApron-f.firstApronSpace;
  capContexts[team]=nba2026Cap(team,transactionSalary,{
   hardCappedAt:f.hardCap==='first'?base.firstApron:f.hardCap==='second'?base.secondApron:null,
   standardRosterPlayers:f.standardRoster,cashSentThisSeason:ctx.cashLimit-cash.availableToSend,cashLimitThisSeason:ctx.cashLimit});
 }
 return {id:'arcside-source-trade',name:'2026–27 trade',operatingSeason:'2026-27',teams,assignments,capContexts,asOfDateIso:date+'T00:00:00Z'};
}
export function evaluateSourceTrade(s:TradeScenario,ctx:TradeContext,selections:Record<string,string>,exceptions:OriginalTradeException[],date:string):TradeReport{
 const r=validateTrade(s);
 const findings=[...r.findings];
 for(const {asset,destinationTeam} of s.assignments){
  const meta=asset.metadata??{};
  if(typeof meta.protected_amount==='number')findings.push({code:'PARTIAL_GUARANTEE_REVIEW',severity:'warning',team:asset.originTeam,assetId:asset.id,message:asset.label+' has a source-reported partial guarantee. Current-season matching and guaranteed salary require contract-specific review; do not use this as definitive CBA approval.'});
  if(meta.sign_and_trade===true)findings.push({code:'SIGN_AND_TRADE_CONTRACT_REVIEW',severity:'warning',team:destinationTeam,assetId:asset.id,message:asset.label+' requires verification of contract term, guaranteed first year, BYC and free-agent eligibility; only the published salary range is modeled.'});
 }

 // Per-asset receiving mechanisms, matching the video-screen workflow. A whole
 // over-capacity exception group is invalid; never silently absorb only part.
 const grouped=new Map<string,TradeAssignment[]>();
 for(const assignment of s.assignments){
  const id=selections[assignment.asset.id];if(!id)continue;
  const tpe=exceptions.find(x=>x.id===id&&sameTeam(x.team,assignment.destinationTeam));
  const team=assignment.destinationTeam,context=s.capContexts[team],assetId=assignment.asset.id;
  const fail=(code:string,message:string)=>findings.push({code,message,severity:'error',team,assetId});
  if(assignment.asset.type!=='player'||assignment.asset.metadata?.two_way===true||assignment.asset.metadata?.sign_and_trade===true||!tpe||!context){fail('TPE_MISSING','No eligible receiving-team exception for this asset.');continue}
  if(tpe.available<=0||tpe.expires<date){fail('TPE_EXPIRED','Selected exception is expired or exhausted.');continue}
  if(context.teamSalary>context.secondApron||r.teamSummaries[team].postTradeSalary>context.secondApron){fail('TPE_APRON','Selected exception is blocked by the modeled second-apron restriction.');continue}
  grouped.set(id,[...(grouped.get(id)??[]),assignment]);
 }
 const absorbed:Record<string,number>={};
 for(const [id,group] of grouped){
  const tpe=exceptions.find(x=>x.id===id)!;
  const total=group.reduce((n,x)=>n+x.asset.salary,0),team=group[0].destinationTeam;
  if(total>tpe.available+100000){findings.push({code:'TPE_AMOUNT',message:'Grouped incoming salary exceeds available exception capacity plus modeled allowance.',severity:'error',team});continue}
  absorbed[team]=(absorbed[team]??0)+total;
  for(const a of group)findings.push({code:'TPE_OK',message:a.asset.label+' modeled via '+tpe.sourceTransaction,severity:'info',team,assetId:a.asset.id});
 }
 for(const [team,amount] of Object.entries(absorbed)){
  const summary=r.teamSummaries[team];
  if(Math.max(0,summary.incomingSalary-amount)<=summary.maximumIncomingSalary+.01){
   for(let i=findings.length-1;i>=0;i--)if(findings[i].team===team&&findings[i].code==='SALARY_MATCH')findings.splice(i,1);
  }
 }
 for(const team of s.teams){
  const cash=ctx.cash.find(x=>sameTeam(x.team,team));
  if(!cash)continue;
  const received=s.assignments.filter(x=>x.destinationTeam===team&&x.asset.type==='cash').reduce((n,x)=>n+(typeof x.asset.metadata?.amount==='number'?x.asset.metadata.amount:x.asset.salary),0);
  if(received>cash.availableToReceive)findings.push({code:'CASH_RECEIVE_LIMIT',message:team+' exceeds the dated cash-receipt availability.',severity:'error',team});
  if(cash.restricted&&r.teamSummaries[team]?.cashSent>0&&(s.capContexts[team].teamSalary>s.capContexts[team].secondApron||r.teamSummaries[team].postTradeSalary>s.capContexts[team].secondApron))findings.push({code:'SOURCE_CASH_RESTRICTED',message:team+' has a source-reported cash-sending restriction.',severity:'error',team});
 }
 return {...r,findings,errorCount:findings.filter(x=>x.severity==='error').length,warningCount:findings.filter(x=>x.severity==='warning').length,isValid:!findings.some(x=>x.severity==='error')};
}
