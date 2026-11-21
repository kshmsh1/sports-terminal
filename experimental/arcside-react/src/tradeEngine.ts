// Independent TypeScript port of lib/services/trade_machine_engine.dart.
// CBA results are modeling outputs, not legal or contract execution approval.
export type AssetType='player'|'draftPick'|'draftRights'|'cash'|'freeAgentRights'|'tradeException'|'signingException';
export type Severity='info'|'warning'|'error';
export interface TradeAsset {id:string;type:AssetType;label:string;originTeam:string;salary:number;metadata?:Record<string,unknown>}
export interface TradeAssignment {asset:TradeAsset;destinationTeam:string}
export interface TeamCapContext {
 team:string;teamSalary:number;salaryCap:number;taxLine:number;firstApron:number;secondApron:number;
 hardCappedAt?:number|null;standardRosterPlayers?:number;minimumStandardRosterPlayers?:number;
 cashSentThisSeason?:number;cashLimitThisSeason?:number;
}
export interface TradeScenario {id:string;name:string;operatingSeason:string;teams:string[];
 assignments:TradeAssignment[];capContexts:Record<string,TeamCapContext>;asOfDateIso?:string}
export interface TradeFinding {code:string;message:string;severity:Severity;team?:string|null;assetId?:string|null}
export interface TeamTradeSummary {
 team:string;outgoingSalary:number;incomingSalary:number;postTradeSalary:number;
 outgoingAssets:number;incomingAssets:number;maximumIncomingSalary:number;projectedRosterPlayers:number;
 cashSent:number;apronStatus:string
}
export interface TradeReport {isValid:boolean;errorCount:number;warningCount:number;findings:TradeFinding[];
 teamSummaries:Record<string,TeamTradeSummary>}
const num=(v:unknown):number|null=>{
 if(typeof v==='number')return Number.isNaN(v)?null:v;
 if(typeof v==='string'&&v.trim()!==''){
  const n=Number(v.trim());return Number.isNaN(n)?null:n;
 }
 return null;
};
const date=(v:unknown):number|null=>{
 if(typeof v!=='string'||!v.trim())return null;
 const t=Date.parse(v);return Number.isFinite(t)?t:null;
};
const firstDate=(m:Record<string,unknown>,keys:string[])=>keys.map(k=>date(m[k])).find(v=>v!==null)??null;
const dateString=(value:number)=>new Date(value).toISOString().slice(0,10);
const fixed=(v:number,places:number)=>v.toFixed(places);
const money=(v:number)=>v>=1e6?'$'+fixed(v/1e6,2)+'M':v>=1e3?'$'+fixed(v/1e3,0)+'K':'$'+fixed(v,0);
const metadata=(a:TradeAsset)=>a.metadata??{};
const cashAmount=(a:TradeAsset)=>num(metadata(a).amount)??a.salary;
const matchingSalary=(a:TradeAsset,direction:'outgoing'|'incoming')=>{
 if(a.type!=='player'||metadata(a).two_way===true)return 0;
 const fields=direction==='outgoing'?['outgoing_matching_salary','byc_outgoing_salary']:
  ['incoming_matching_salary','poison_pill_incoming_salary'];
 for(const key of fields){const n=num(metadata(a)[key]);if(n!==null)return n}
 return a.salary;
};
const teamSalaryCharge=(a:TradeAsset)=>a.type==='player'&&metadata(a).two_way!==true?
 num(metadata(a).team_salary_charge)??a.salary:0;
export const nba2026Cap=(team:string,teamSalary:number,override:Partial<TeamCapContext>={}):TeamCapContext=>({
 team,teamSalary,salaryCap:164961000,taxLine:200428000,firstApron:209015000,
 secondApron:221686000,standardRosterPlayers:14,minimumStandardRosterPlayers:14,
 cashSentThisSeason:0,cashLimitThisSeason:Infinity,...override
});
const maxIncoming=(context:TeamCapContext,outgoing:number,post:number)=>{
 if(context.teamSalary<context.salaryCap)return outgoing+Math.max(0,context.salaryCap-context.teamSalary)+250000;
 if(post>context.firstApron)return outgoing;
 if(outgoing<=0)return 0;
 const scaled=7500000*(context.salaryCap/136021000);
 return Math.max(Math.min(2*outgoing+250000,outgoing+scaled),1.25*outgoing+250000);
};
export function validateTrade(s:TradeScenario):TradeReport{
 const findings:TradeFinding[]=[],teamSummaries:Record<string,TeamTradeSummary>={};
 const add=(code:string,message:string,severity:Severity,team?:string,assetId?:string)=>
  findings.push({code,message,severity,team:team??null,assetId:assetId??null});
 const asOf=date(s.asOfDateIso);
 if(s.teams.length<2)add('MIN_TEAMS','A trade requires at least two teams.','error');
 if(s.teams.length>5)add('MAX_TEAMS','This product supports up to five participating teams per transaction.','error');
 if(new Set(s.teams).size!==s.teams.length)add('DUPLICATE_TEAM','A participating team is listed more than once.','error');
 const seen=new Set<string>(),duplicates=new Set<string>();
 for(const {asset:a,destinationTeam:dest} of s.assignments){
  if(seen.has(a.id))duplicates.add(a.id);seen.add(a.id);
  if(!s.teams.includes(a.originTeam)||!s.teams.includes(dest))
   add('TEAM_SCOPE',`${a.label} references a team outside this scenario.`,'error',undefined,a.id);
  if(a.originTeam===dest)
   add('SAME_TEAM',`${a.label} cannot be routed back to its origin team.`,'error',a.originTeam,a.id);
  const m=metadata(a),team=a.originTeam;
  if(a.type==='player'){
   const restricted=firstDate(m,['trade_restricted_until','recently_signed_until','recently_acquired_until']);
   if(restricted!==null){
    if(asOf===null)add('DATED_TRADE_RESTRICTION_REVIEW',
     `${a.label} has a trade-restriction date through ${dateString(restricted)}, but this scenario has no as-of date. Add an as-of date before treating the player as trade-eligible.`,'warning',team,a.id);
    else if(asOf<restricted)add('DATED_TRADE_RESTRICTION',
     `${a.label} is marked ineligible to be traded until ${dateString(restricted)}.`,'error',team,a.id);
   }
   if(m.base_year_compensation===true){
    const value=num(m.outgoing_matching_salary)??num(m.byc_outgoing_salary);
    add(value===null?'BYC_VALUE_REQUIRED':'BYC_APPLIED',value===null?
     `${a.label} is marked Base Year Compensation but has no authoritative outgoing matching-salary value. The scenario cannot rely on nominal salary.`:
     `${a.label} uses a BYC outgoing matching salary of ${money(value)} rather than nominal salary.`,
     value===null?'error':'info',team,a.id);
   }
   if(m.poison_pill===true){
    const value=num(m.incoming_matching_salary)??num(m.poison_pill_incoming_salary);
    add(value===null?'POISON_PILL_VALUE_REQUIRED':'POISON_PILL_APPLIED',value===null?
     `${a.label} is marked poison-pill but has no authoritative receiving-team matching salary. Add that value before validating the trade.`:
     `${a.label} uses a poison-pill receiving-team matching salary of ${money(value)}.`,
     value===null?'error':'info',dest,a.id);
   }
   if(m.two_way===true)add('TWO_WAY_CONTRACT',
    `${a.label} is marked as a two-way contract. It is excluded from standard-roster and salary-matching calculations and requires two-way eligibility validation.`,'warning',team,a.id);
   if(m.sign_and_trade===true&&dest===team)
    add('SIGN_AND_TRADE_DESTINATION',`${a.label} is marked sign-and-trade but is not changing teams.`,'error',team,a.id);
  }
  if(a.type==='draftPick'){
   if(m.stepien_conflict===true)add('STEPIEN_CONFLICT',
    `${a.label} is marked as creating a prohibited future first-round-pick continuity gap. The pick cannot be traded in this structure.`,'error',team,a.id);
   if(m.frozen===true||m.trade_frozen===true)add('FROZEN_PICK',
    `${a.label} is marked frozen/unavailable for trade under the team’s current draft-asset restrictions.`,'error',team,a.id);
   if(String(m.protection??'').trim())add('PICK_PROTECTION',
    `${a.label} carries ${m.protection} protection. Conveyance, rollover and downstream obligations must be modeled before final approval.`,'info',team,a.id);
   if(m.swap_right===true)add('PICK_SWAP',
    `${a.label} is a swap right. The underlying pick ownership, better/worse convention and competing swap obligations remain attached to the asset.`,'info',team,a.id);
   if(m.conveyance_uncertain===true)add('PICK_CONVEYANCE_UNCERTAIN',
    `${a.label} has uncertain conveyance. This scenario requires the complete protection/rollover tree before execution.`,'warning',team,a.id);
   const years=num(m.years_out);
   if(years!==null&&Math.trunc(years)>7)add('PICK_TOO_DISTANT',
    `${a.label} is ${Math.trunc(years)} seasons out, beyond the modeled seven-season first-round trade horizon.`,'error',team,a.id);
  }
  if(a.type==='cash'&&cashAmount(a)<=0)add('CASH_AMOUNT_REQUIRED',
   `${a.label} needs a positive cash amount.`,'error',team,a.id);
  if(a.type==='tradeException'||a.type==='signingException'){
   const expires=date(m.expires_at);
   if(expires!==null&&asOf!==null&&asOf>expires)add('EXPIRED_EXCEPTION',
    `${a.label} expired on ${dateString(expires)}.`,'error',team,a.id);
   if((num(m.amount)??a.salary)<=0)add('EXCEPTION_AMOUNT_REQUIRED',
    `${a.label} requires an authoritative available exception amount.`,'error',team,a.id);
  }
 }
 for(const id of duplicates)add('DUPLICATE_ASSET',`Asset ${id} is assigned more than once.`,'error',undefined,id);
 for(const team of s.teams){
  const outgoing=s.assignments.filter(a=>a.asset.originTeam===team);
  const incoming=s.assignments.filter(a=>a.destinationTeam===team);
  const outPlayers=outgoing.filter(a=>a.asset.type==='player'&&metadata(a.asset).two_way!==true);
  const inPlayers=incoming.filter(a=>a.asset.type==='player'&&metadata(a.asset).two_way!==true);
  const outgoingSalary=outgoing.reduce((n,a)=>n+matchingSalary(a.asset,'outgoing'),0);
  const incomingSalary=incoming.reduce((n,a)=>n+matchingSalary(a.asset,'incoming'),0);
  const ctx=s.capContexts[team];
  const post=(ctx?.teamSalary??0)-outgoing.reduce((n,a)=>n+teamSalaryCharge(a.asset),0)+
   incoming.reduce((n,a)=>n+teamSalaryCharge(a.asset),0);
  const roster=(ctx?.standardRosterPlayers??14)-outPlayers.length+inPlayers.length;
  const max=ctx?maxIncoming(ctx,outgoingSalary,post):Infinity;
  const cash=outgoing.filter(a=>a.asset.type==='cash').reduce((n,a)=>n+cashAmount(a.asset),0);
  const apron=!ctx?'unknown':post>ctx.secondApron?'above-second-apron':
   post>ctx.firstApron?'above-first-apron':post>ctx.taxLine?'tax':post>ctx.salaryCap?'over-cap':'cap-room';
  teamSummaries[team]={team,outgoingSalary,incomingSalary,postTradeSalary:post,
   outgoingAssets:outgoing.length,incomingAssets:incoming.length,maximumIncomingSalary:max,
   projectedRosterPlayers:roster,cashSent:cash,apronStatus:apron};
  if(!outgoing.length&&!incoming.length)add('NO_ACTIVITY',`${team} has no incoming or outgoing assets.`,'warning',team);
  if(!ctx){add('MISSING_CAP_CONTEXT',`${team} needs salary-cap context before legal validation can be completed.`,'warning',team);continue}
  if(roster>15)add('ROSTER_MAX',
   `${team} projects to ${roster} standard-contract players; the transaction requires a roster-compliance move.`,'warning',team);
  if(roster<(ctx.minimumStandardRosterPlayers??14))add('ROSTER_MIN',
   `${team} projects to ${roster} standard-contract players, below the modeled minimum of ${ctx.minimumStandardRosterPlayers??14}; subsequent signings or roster actions are required.`,'warning',team);
  if(ctx.hardCappedAt!=null&&post>ctx.hardCappedAt)add('HARD_CAP',
   `${team} exceeds its modeled hard cap after the trade.`,'error',team);
  if(incomingSalary>max+.01)add('SALARY_MATCH',
   `${team} receives ${money(incomingSalary)}, above the modeled incoming-salary limit of ${money(max)} for this cap position.`,'error',team);
  const usesException=incoming.some(a=>a.asset.type==='tradeException'||a.asset.type==='signingException');
  const hasSignAndTrade=incoming.some(a=>metadata(a.asset).sign_and_trade===true);
  const aggregates=outPlayers.length>1;
  if(cash>0&&Number.isFinite(ctx.cashLimitThisSeason??Infinity)){
   const remaining=Math.max(0,(ctx.cashLimitThisSeason??Infinity)-(ctx.cashSentThisSeason??0));
   if(cash>remaining+.01)add('CASH_LIMIT',
    `${team} sends ${money(cash)} in cash but has only ${money(remaining)} of the modeled annual cash limit remaining.`,'error',team);
  }
  if(ctx.teamSalary>ctx.secondApron||post>ctx.secondApron){
   if(aggregates&&inPlayers.length)add('SECOND_APRON_AGGREGATION',
    `${team} is above the second apron and is aggregating multiple outgoing player salaries; this structure is blocked by the modeled second-apron transaction rules.`,'error',team);
   if(cash>0)add('SECOND_APRON_CASH',
    `${team} is above the second apron and is sending cash; the modeled second-apron transaction rules prohibit this structure.`,'error',team);
   if(usesException)add('SECOND_APRON_EXCEPTION',
    `${team} is above the second apron and is using a trade/signing exception. This scenario is blocked conservatively pending the authoritative exception record.`,'error',team);
   if(hasSignAndTrade)add('SECOND_APRON_SIGN_AND_TRADE',
    `${team} cannot complete the modeled sign-and-trade while ending above the second apron; the transaction also requires first-apron hard-cap validation.`,'error',team);
  }else if(post>ctx.firstApron)add('FIRST_APRON',
   `${team} projects above the first apron. The modeled $250,000 traded-player-exception allowance is removed and hard-cap-triggering transaction types require review.`,'warning',team);
  if(hasSignAndTrade){
   if(post>ctx.firstApron)add('SIGN_AND_TRADE_FIRST_APRON',
    `${team} acquires a sign-and-trade player and projects above the first apron. The modeled hard-cap consequence makes this transaction invalid.`,'error',team);
   else add('SIGN_AND_TRADE_HARD_CAP',
    `${team} acquires a sign-and-trade player; treat the first apron as a hard transaction ceiling and verify all related signing requirements.`,'warning',team);
  }
  for(const {asset:a} of outgoing.filter(x=>x.asset.type==='player')){
   const m=metadata(a);
   if(m.no_trade===true)add('NO_TRADE_CLAUSE',`${a.label} is marked with trade-consent rights and requires player approval.`,'warning',team,a.id);
   if(m.trade_restricted===true)add('TRADE_RESTRICTED',
    `${a.label} is currently marked trade-restricted by contract/timing metadata.`,'error',team,a.id);
   if(m.cannot_aggregate===true&&aggregates)add('PLAYER_AGGREGATION_RESTRICTED',
    `${a.label} is marked as ineligible to aggregate with another outgoing player salary.`,'error',team,a.id);
   if(typeof m.trade_bonus==='number'||typeof m.trade_kicker==='number')add('TRADE_BONUS',
    `${a.label} has a modeled trade bonus/kicker; matching salary and team salary must reflect its authoritative allocation.`,'warning',team,a.id);
  }
  if(usesException)add('EXCEPTION_REVIEW',
   `${team} uses an exception. Amount, expiration, aggregation, apron and hard-cap consequences must match the authoritative exception record.`,'warning',team);
 }
 for(const team of s.teams){
  const picks=s.assignments.filter(a=>a.asset.originTeam===team&&a.asset.type==='draftPick'&&
   String(metadata(a.asset).round??'')==='1');
  const byYear=new Map<number,TradeAsset[]>();
  for(const {asset} of picks){
   const year=num(metadata(asset).draft_year);
   if(year===null)continue;
   const n=Math.trunc(year);
   byYear.set(n,[...(byYear.get(n)??[]),asset]);
  }
  const years=[...byYear.keys()].sort((a,b)=>a-b);
  for(let i=0;i+1<years.length;i++){
   if(years[i+1]!==years[i]+1)continue;
   const both=[...(byYear.get(years[i])??[]),...(byYear.get(years[i+1])??[])];
   if(!both.every(a=>metadata(a).stepien_safe===true||metadata(a).swap_right===true))
    add('STEPIEN_REVIEW',
     `${team} sends first-round interests in consecutive draft years ${years[i]} and ${years[i+1]}. Validate retained first-round control, protections and swaps before approval.`,'warning',team);
  }
 }
 if(!s.assignments.length)add('EMPTY_SCENARIO',
  'Add at least one player, pick, right, cash item or exception.','error');
 return {isValid:!findings.some(f=>f.severity==='error'),
  errorCount:findings.filter(f=>f.severity==='error').length,
  warningCount:findings.filter(f=>f.severity==='warning').length,findings,teamSummaries};
}
export function jsonTradeReport(r:TradeReport){
 return {...r,teamSummaries:Object.fromEntries(Object.entries(r.teamSummaries).map(([k,v])=>[k,{
  ...v,maximumIncomingSalary:Number.isFinite(v.maximumIncomingSalary)?v.maximumIncomingSalary:'INFINITY'
 }]))};
}
