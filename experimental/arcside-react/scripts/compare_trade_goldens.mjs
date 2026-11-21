// A comparison is meaningful only AFTER a human has reviewed the original Dart baseline
// and a candidate rules service or TS port produces its own report in the same shape.
// Usage: node scripts/compare_trade_goldens.mjs reference.json candidate.json
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
const [baseline,candidate]=process.argv.slice(2);
if(!baseline||!candidate){console.error('Usage: node scripts/compare_trade_goldens.mjs original_dart.json candidate.json');process.exit(2);}
if(resolve(baseline)===resolve(candidate)){
 console.error('CBA golden parity FAIL: a Dart reference file cannot serve as its own independent candidate.');
 process.exit(1);
}
const a=JSON.parse(readFileSync(baseline,'utf8')),b=JSON.parse(readFileSync(candidate,'utf8'));
if(a.kind!=='ARCSIDE_ORIGINAL_DART_CBA_GOLDENS_V1'||
 b.kind!=='ARCSIDE_INDEPENDENT_REACT_CBA_CANDIDATE_V1'||
 b.candidateEquivalentImplemented!==true||
 typeof b.implementationSource!=='string'||!b.implementationSource.trim()){
 console.error('CBA golden parity FAIL: requires original Dart exporter and independently implemented React candidate with explicit implementationSource. An exporter, snapshot, or copied reference is NOT a candidate.');
 process.exit(1);
}
const keys=Object.keys(a.cases??{}),fail=[];
for(const key of keys){
 const original=a.cases[key],next=b.cases?.[key];
 if(!next){fail.push(key+': candidate is absent');continue;}
 const metricFields=['isValid','errorCount','warningCount'];
 for(const k of metricFields)if(original[k]!==next[k])fail.push(key+'.'+k);
 const fa=original.findings??[],fb=next.findings??[];
 if(JSON.stringify(fa)!==JSON.stringify(fb))fail.push(key+'.findings severity/codes/messages');
 const sa=original.teamSummaries??{},sb=next.teamSummaries??{};
 if(JSON.stringify(sa)!==JSON.stringify(sb))fail.push(key+'.teamSummaries salary/roster/apron');
}
if(Object.keys(b.cases??{}).length!==keys.length)fail.push('scenario coverage differs');
if(fail.length){console.error('CBA golden parity FAIL:\n'+fail.join('\n'));process.exit(1);}
console.log('Exact reported CBA contract match on '+keys.length+' reviewed scenarios from '+b.implementationSource+'; NOT full CBA parity.');
