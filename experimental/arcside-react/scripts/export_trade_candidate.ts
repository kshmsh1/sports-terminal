import {writeFile,mkdir,readFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {originalCbaFixtureCandidate} from './trade_fixtures.ts';
const here=path.dirname(fileURLToPath(import.meta.url));
const out=path.resolve(here,'../evidence/trade/react-trade-candidate.json');
await mkdir(path.dirname(out),{recursive:true});
const report=originalCbaFixtureCandidate();
await writeFile(out,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({path:out,implementationSource:report.implementationSource,
 kind:report.kind,cases:Object.keys(report.cases)},null,2));
import {validateTrade,jsonTradeReport} from '../src/tradeEngine.ts';
import type {TradeScenario} from '../src/tradeEngine.ts';
const sourceFile=path.resolve(here,'../evidence/trade/dart-source-trade-reference.json');
const source=JSON.parse(await readFile(sourceFile,'utf8')) as {kind:string;teamCount:number;cases:Record<string,{input:TradeScenario;reference:ReturnType<typeof jsonTradeReport>}>};
if(source.kind!=='ARCSIDE_DATED_DART_TRADE_REFERENCE_V1'||source.teamCount!==30||
 Object.keys(source.cases).filter(k=>k.startsWith('pair-')).length!==435)throw Error('Missing dated original Dart source trade report; run the updated Dart exporter.');
const sourceResults:Record<string,ReturnType<typeof jsonTradeReport>>={},mismatches:string[]=[];
const findingsKey=(r:ReturnType<typeof jsonTradeReport>)=>JSON.stringify(r.findings.map(f=>[f.code,f.severity,f.team??null,f.assetId??null]));
for(const [id,{input,reference}] of Object.entries(source.cases)){
 // Reference output is never used as an input to the independent TypeScript engine.
 const actual=jsonTradeReport(validateTrade(input));sourceResults[id]=actual;
 for(const key of ['isValid','errorCount','warningCount'] as const)if(actual[key]!==reference[key])mismatches.push(id+'.'+key);
 if(findingsKey(actual)!==findingsKey(reference))mismatches.push(id+'.findings');
 if(Object.keys(actual.teamSummaries).length!==Object.keys(reference.teamSummaries).length)mismatches.push(id+'.teamCount');
 for(const [team,ref] of Object.entries(reference.teamSummaries)){
  const candidate=actual.teamSummaries[team];
  if(!candidate){mismatches.push(id+'.'+team);continue}
  for(const [field,value] of Object.entries(ref)){
   const v=candidate[field as keyof typeof candidate];
   if(typeof value==='number'&&typeof v==='number'?Math.abs(value-v)>.01:v!==value)mismatches.push(id+'.'+team+'.'+field);
  }
 }
}
const sourceOutput=path.resolve(here,'../evidence/trade/react-source-trade-candidate.json');
await writeFile(sourceOutput,JSON.stringify({kind:'ARCSIDE_DATED_REACT_TRADE_CANDIDATE_V1',implementation:'src/tradeEngine.ts',cases:sourceResults,mismatches},null,2)+'\n');
if(mismatches.length)throw Error('Dated original-source trade parity failed: '+mismatches.slice(0,40).join(', '));
console.log('Dated original-source engine semantic parity: '+Object.keys(sourceResults).length+' scenarios, zero mismatches. No claim of exhaustive CBA or product-layer parity.');
