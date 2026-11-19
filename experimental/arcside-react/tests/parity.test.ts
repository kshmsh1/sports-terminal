import {describe,it,expect} from 'vitest';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {buildRows,formatMetric,stintRows} from '../src/engine';
import type {JsonRow,SeasonSnapshot,RateBasis} from '../src/data';

type RefRow={id:string;player:string;team:string;position:string;estimated:boolean;
  values:Record<string,number|null>;percentiles:Record<string,number>;
  formatted:Record<string,string>;stints:Array<{id:string;team:string;values:Record<string,number|null>}>};
type RefCase={season:string;segment:'regular'|'playoffs';basis:RateBasis;rows:RefRow[]};
type Reference={kind:string;dataSource:string;corpusRoot:string;referenceCases:RefCase[]};
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..');
const output=path.resolve(here,'../evidence/parity/parity-comparison.json');
const refPath=process.env.ARCSIDE_PARITY_REFERENCE ??
  path.resolve(here,'../evidence/parity/dart-reference.json');
const strict=process.env.ARCSIDE_PARITY_REPORT_ONLY!=='1';
function equal(a:unknown,b:unknown):boolean {
 if(typeof a==='number'&&typeof b==='number')
  return Number.isFinite(a)&&Number.isFinite(b)&&Math.abs(a-b)<=1e-8*Math.max(1,Math.abs(a),Math.abs(b));
 return a===b;
}
const cached=new Map<string,SeasonSnapshot>();
function snapshot(reference:Reference,s:RefCase):SeasonSnapshot{
 const key=s.season+'/'+s.segment;
 if(cached.has(key))return cached.get(key)!;
 const filename=reference.dataSource==='ACTUAL_LOCAL_V5_CORPUS'
  ?path.resolve(root,reference.corpusRoot,'seasons',s.season,s.segment+'.json')
  :path.resolve(here,'parity_fixture.json');
 const raw=JSON.parse(readFileSync(filename,'utf8')) as SeasonSnapshot;
 if(raw.season_id!==s.season||raw.season_type!==s.segment||!Array.isArray(raw.player_season_totals))
  throw Error('Source shard does not match Dart reference: '+filename);
 const tagged=raw.player_season_totals.map(original=>{
  const r={...original} as JsonRow;
  if(r.season_type===undefined&&r.seasonType===undefined&&r.segment===undefined)
   r.season_type=s.segment;
  return r;
 });
 const result={...raw,players:raw.players??[],player_season_totals:tagged};
 cached.set(key,result);return result;
}
describe('independent original Dart vs React statistical semantics',()=>{
 it('writes a complete, source-linked parity report (strict fixture gate, report-only real corpus)',()=>{
  const baseline=JSON.parse(readFileSync(refPath,'utf8')) as Reference;
  if(baseline.kind!=='ARCSIDE_DART_REFERENCE_OUTPUT'||!baseline.referenceCases?.length)
   throw Error('Missing/invalid ORIGINAL Dart reference: '+refPath);
  let comparisons=0,rowCount=0;
  const counts:Record<string,number>={};
  const mismatches:Array<Record<string,unknown>>=[];
  const representativeByCase:Record<string,Array<Record<string,unknown>>>={};
  const representativeByField:Record<string,Array<Record<string,unknown>>>={};
  const byCase:Record<string,{comparisons:number;mismatches:number;byField:Record<string,number>}>={};
  const byCategory:Record<string,number>={};
  const byDifference:Record<string,number>={};
  const missingIds:Array<Record<string,unknown>>=[];
  let activeCase='';
  const add=(caseKey:string,id:string,field:string,expected:unknown,actual:unknown)=>{
   counts[field]=(counts[field]??0)+1;
   const item={case:caseKey,id,field,dart:expected,react:actual};
   if(mismatches.length<150)mismatches.push(item);
   (representativeByCase[caseKey]??=[]);
   if(representativeByCase[caseKey].length<12)representativeByCase[caseKey].push(item);
   (representativeByField[field]??=[]);
   if(representativeByField[field].length<3)representativeByField[field].push(item);
   const entry=(byCase[caseKey]??={comparisons:0,mismatches:0,byField:{}});
   entry.mismatches++;
   entry.byField[field]=(entry.byField[field]??0)+1;
   const category=field.startsWith('percentile.')?'percentile':
     field.startsWith('display.')?'display':field.startsWith('value.')?'value':
     field.startsWith('stints.')?'team_stint':'identity_or_presence';
   byCategory[category]=(byCategory[category]??0)+1;
   const difference=expected===null&&actual!==null?'dart_missing_react_present':
     expected!==null&&actual===null?'dart_present_react_missing':
     typeof expected==='number'&&typeof actual==='number'?'numeric_delta':'other';
   byDifference[difference]=(byDifference[difference]??0)+1;
  };
  for(const sample of baseline.referenceCases){
   const candidate=buildRows(snapshot(baseline,sample),sample.basis);
   const actual=new Map(candidate.map(r=>[r.id,r]));
   const refIds=new Set<string>();
   const label=sample.season+'/'+sample.segment+'/'+sample.basis;
   activeCase=label;
   byCase[label]={comparisons:0,mismatches:0,byField:{}};
   rowCount+=sample.rows.length;
   for(const expected of sample.rows){
    refIds.add(expected.id);
    const row=actual.get(expected.id);
    if(!row){add(label,expected.id,'missing_react_player',true,false);missingIds.push({case:label,id:expected.id});continue;}
    for(const key of ['player','team','position','estimated'] as const){
     comparisons++;byCase[activeCase].comparisons++;if(!equal(expected[key],row[key]))add(label,expected.id,key,expected[key],row[key]);
    }
    for(const [k,v] of Object.entries(expected.values)){
     comparisons++;byCase[activeCase].comparisons++;const actualValue=(row.values as unknown as Record<string,number|null>)[k]??null;
     if(!equal(v,actualValue))add(label,expected.id,'value.'+k,v,actualValue);
    }
    for(const [k,v] of Object.entries(expected.percentiles)){
     comparisons++;const actualValue=(row.percentiles as Record<string,number>)[k]??null;
     if(!equal(v,actualValue))add(label,expected.id,'percentile.'+k,v,actualValue);
    }
    for(const [k,v] of Object.entries(expected.formatted)){
     comparisons++;const actualValue=formatMetric(k as Parameters<typeof formatMetric>[0],
      (row.values as unknown as Record<string,number|null>)[k]??null);
     if(v!==actualValue)add(label,expected.id,'display.'+k,v,actualValue);
    }
    const actualStints=stintRows(row,sample.basis);
    comparisons++;byCase[activeCase].comparisons++;if(expected.stints.length!==actualStints.length)
     add(label,expected.id,'stints.length',expected.stints.length,actualStints.length);
    for(let n=0;n<Math.min(expected.stints.length,actualStints.length);n++){
     const referenceStint=expected.stints[n], candidateStint=actualStints[n];
     if(referenceStint.team!==candidateStint.team)
      add(label,expected.id,'stints.'+n+'.team',referenceStint.team,candidateStint.team);
     for(const [k,v] of Object.entries(referenceStint.values)){
      comparisons++;byCase[activeCase].comparisons++;const actualValue=(candidateStint.values as unknown as Record<string,number|null>)[k]??null;
      if(!equal(v,actualValue))add(label,expected.id,'stints.'+n+'.'+k,v,actualValue);
     }
    }
   }
   for(const r of candidate)if(!refIds.has(r.id)){add(label,r.id,'missing_dart_player',false,true);missingIds.push({case:label,id:r.id});}
  }
  const failures=Object.values(counts).reduce((s,n)=>s+n,0);
  // Per-case comparisons are tracked over the same distinct checks used in
  // the overall count; missing/extra player rows remain mismatch diagnostics.
  // Correct per-case totals independently instead of assuming equal case sizes.
  const caseComparisons=Object.values(byCase).reduce((sum,entry)=>sum+entry.comparisons,0);
  if(caseComparisons!==comparisons)throw Error('Per-case comparison accounting mismatch');
  const report={kind:'ARCSIDE_CROSS_ENGINE_PARITY_REPORT',referenceEngine:baseline.kind,
   source:baseline.dataSource,caseCount:baseline.referenceCases.length,referenceRows:rowCount,
   comparisons,mismatchCount:failures,byField:counts,
   byCase,byCategory,byDifference,representativeByCase,representativeByField,
   first150Mismatches:mismatches, // Retained for existing readers
   missingIds,relativeNumericTolerance:1e-8,passed:failures===0,
   caveat:'Same mapped fields only. Not Trade Machine, full Stats/Advanced profile/catalog or UI/UX parity.',
   createdAt:new Date().toISOString()};
  mkdirSync(path.dirname(output),{recursive:true});
  writeFileSync(output,JSON.stringify(report,null,2)+'\n');
  console.log('ARCSIDE_PARITY_REPORT '+JSON.stringify({source:report.source,cases:report.caseCount,
    compared:comparisons,mismatches:failures,fields:counts,output}));
  if(strict)expect(failures,'Dart vs React parity mismatches; inspect '+output).toBe(0);
  else expect(comparisons).toBeGreaterThan(0);
 },120000);
});
