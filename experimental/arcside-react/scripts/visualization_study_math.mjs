// Explicit nearest-rank percentiles, separate cold/warm and paired diagnostics.
const q=(values,fraction)=>{
 if(!values.length)return null;
 const sorted=[...values].sort((a,b)=>a-b);
 return sorted[Math.max(0,Math.ceil(sorted.length*fraction)-1)];
};
export function evaluateVisualizationStudy(report){
 const problems=[],by={},pairs=[];
 if(report?.kind!=='ARCSIDE_VISUALIZATION_MATCHED_TASKS_V2'||
    report?.protocol!=='VISUALIZATION_CHART_V2_MATCHED_2_COLD_10_WARM'||
    report?.source!=='ACTUAL_LOCAL_V5_CORPUS'||!report?.operatorConfirmed)
  problems.push('Original v2 study identity, real source, or operator preflight missing');
 const rows=report?.raw??[];
 if(!Array.isArray(rows)||rows.length!==24)problems.push('Expected exactly 24 raw observations');
 for(const app of ['Flutter','React']){
  const entries=Array.isArray(rows)?rows.filter(x=>x.app===app):[];
  const seen=new Set(entries.map(x=>x.trial));
  if(entries.length!==12||seen.size!==12||!Array.from({length:12},(_,i)=>i+1).every(i=>seen.has(i)))
   problems.push(app+' did not contain exactly one observation per trial');
  if(entries.some(x=>x.cold!==(x.trial<=2)||x.passed!==true||
   x.operatorVerified!==true||!Number.isFinite(x.ms)||x.ms<=0))
   problems.push(app+' has invalid or unqualified recorded attempts');
  const cold=entries.filter(x=>x.cold).map(x=>x.ms);
  const warm=entries.filter(x=>!x.cold).map(x=>x.ms);
  const all=entries.map(x=>x.ms);
  const r={trials:entries.length,coldTrials:cold.length,warmTrials:warm.length,
   coldMedianMs:q(cold,.5),warmMedianMs:q(warm,.5),
   allTrialMedianMs:q(all,.5),warmP95Ms:q(warm,.95),
   allTrialP95Ms:q(all,.95),maxMs:q(all,1),warmMaxMs:q(warm,1),
   warmSortedMs:[...warm].sort((a,b)=>a-b)};
  by[app]=r;
  if(warm.length!==10||cold.length!==2)problems.push(app+' did not have 2 cold/10 warm');
  const stored=report.by?.[app]??{};
  for(const [name,actual] of [['medianMs',r.warmMedianMs],['p95Ms',r.warmP95Ms]]){
   if(!Number.isFinite(stored[name])||Math.abs(stored[name]-actual)>1e-6)
    problems.push('Original '+app+' '+name+' does not match nearest-rank WARM-only calculation');
  }
 }
 if(Array.isArray(rows)){
  for(let trial=1;trial<=12;trial++){
   const flutter=rows.find(x=>x.app==='Flutter'&&x.trial===trial);
   const react=rows.find(x=>x.app==='React'&&x.trial===trial);
   if(flutter&&react)pairs.push({trial,cold:trial<=2,flutterMs:flutter.ms,
    reactMs:react.ms,reactOverFlutter:react.ms/flutter.ms,
    deltaMs:react.ms-flutter.ms,
    flutterFrameGapP95: flutter.frameProbe?.p95GapMs??null,
    reactFrameGapP95:react.frameProbe?.p95GapMs??null,
    reactFramesOver50Ms:react.frameProbe?.gapsOver50Ms??null});
  }
 }
 const warmPairs=pairs.filter(x=>!x.cold);
 const medianRatio=q(warmPairs.map(x=>x.reactOverFlutter),.5);
 const suspectPairs=warmPairs.filter(x=>x.reactOverFlutter>1.5&&
   x.reactOverFlutter>1.5*(medianRatio??1));
 const ratio=by.Flutter?.warmP95Ms>0?by.React.warmP95Ms/by.Flutter.warmP95Ms:null;
 if(Number.isFinite(report?.p95ReactOverFlutter)&&ratio!==null&&
   Math.abs(report.p95ReactOverFlutter-ratio)>1e-6)
  problems.push('Stored composite p95 ratio differs from original raw data');
 return {kind:'ARCSIDE_V2_DIAGNOSTIC_AUDIT_V1',
  status:problems.length?'INVALID_STUDY':ratio<=1.10?'BENCHMARK_PASSED':'BENCHMARK_FAILED_REQUIRES_INVESTIGATION',
  calculationErrors:problems,by,warmP95ReactOverFlutter:ratio,
  warmP95Within110Pct:ratio!==null&&ratio<=1.10,
  suspectPairs,pairedTrials:pairs,
  note:'The registered p95 is nearest-rank on 10 WARM trials, not 12 total; n=10 p95 equals the largest warm observation. Outliers are retained. A smooth rAF sequence cannot prove absence of input, compositor or async latency. This audit is not a new performance result and never overrides the original failure.'};
}
