import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const script=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../scripts/compare_trade_goldens.mjs');
const dart={kind:'ARCSIDE_ORIGINAL_DART_CBA_GOLDENS_V1',candidateEquivalentImplemented:false,
 cases:{swap:{isValid:true,errorCount:0,warningCount:0,findings:[],
  teamSummaries:{AAA:{incomingSalary:8000000,outgoingSalary:8000000}}}}};
test('never accepts the original Dart reference itself as an independent CBA candidate',()=>{
 const dir=mkdtempSync(path.join(tmpdir(),'arcside-phase3-cba-'));
 try{
  const original=path.join(dir,'dart.json');writeFileSync(original,JSON.stringify(dart));
  const result=spawnSync(process.execPath,[script,original,original],{encoding:'utf8'});
  assert.equal(result.status,1);
  assert.match(result.stderr,/cannot serve as its own independent candidate/);
 }finally{rmSync(dir,{recursive:true,force:true})}
});
test('missing or copied Dart report fails candidate provenance',()=>{
 const dir=mkdtempSync(path.join(tmpdir(),'arcside-phase3-cba-'));
 try{
  const original=path.join(dir,'dart.json'),candidate=path.join(dir,'candidate.json');
  writeFileSync(original,JSON.stringify(dart));writeFileSync(candidate,JSON.stringify(dart));
  const result=spawnSync(process.execPath,[script,original,candidate],{encoding:'utf8'});
  assert.equal(result.status,1);assert.match(result.stderr,/independently implemented React candidate/);
 }finally{rmSync(dir,{recursive:true,force:true})}
});
test('declared independent candidates must still match every finding and salary value',()=>{
 const dir=mkdtempSync(path.join(tmpdir(),'arcside-phase3-cba-'));
 try{
  const original=path.join(dir,'dart.json'),candidate=path.join(dir,'candidate.json');
  const declared={...dart,kind:'ARCSIDE_INDEPENDENT_REACT_CBA_CANDIDATE_V1',
   candidateEquivalentImplemented:true,implementationSource:'src/independentTradeRules.ts'};
  writeFileSync(original,JSON.stringify(dart));
  writeFileSync(candidate,JSON.stringify({...declared,
   cases:{swap:{...declared.cases.swap,errorCount:1}}}));
  const fail=spawnSync(process.execPath,[script,original,candidate],{encoding:'utf8'});
  assert.equal(fail.status,1);assert.match(fail.stderr,/swap.errorCount/);
  writeFileSync(candidate,JSON.stringify(declared));
  const pass=spawnSync(process.execPath,[script,original,candidate],{encoding:'utf8'});
  assert.equal(pass.status,0);assert.match(pass.stdout,/NOT full CBA parity/);
 }finally{rmSync(dir,{recursive:true,force:true})}
});