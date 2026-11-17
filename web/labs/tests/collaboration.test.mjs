import test from 'node:test';
import assert from 'node:assert/strict';
import {diffWorkbook,collaborationEndpoint} from '../sheets/collaboration.mjs';
const doc=(values={})=>({
  name:'Research',workbook:{version:1,active:'Analysis',
    sheets:[{name:'Analysis',cells:{A1:'Label',B2:'5',...values},styles:{},
      widths:{}}],rules:[],charts:[],pivots:[]},
});
test('independent cell updates produce fine-grained patch without replacing workbook',()=>{
 const before=doc();
 const after=doc({B2:'8',C2:'10'});
 const diff=diffWorkbook(before,after);
 assert.equal(diff.type,'patch');
 assert.deepEqual(diff.changes.map(x=>x.ref),['B2','C2']);
 assert.deepEqual(diff.changes.map(x=>x.value),['8','10']);
});
test('sheet selection is personal and not synchronized',()=>{
 const before=doc(),after=doc();
 after.workbook.active='Other';
 assert.equal(diffWorkbook(before,after),null);
});
test('format styles and cell deletion produce separate patches',()=>{
 const before=doc(),after=doc();
 after.workbook.sheets[0].styles.A1={bold:true,color:'#ffffff'};
 delete after.workbook.sheets[0].cells.B2;
 const diff=diffWorkbook(before,after);
 assert.deepEqual(diff.changes,[
  {sheet:'Analysis',ref:'B2',field:'raw',value:''},
  {sheet:'Analysis',ref:'A1',field:'style',value:{bold:true,color:'#ffffff'}},
 ]);
});
test('adding sheet or modifying workbook metadata requires structural CAS',()=>{
 const before=doc(),after=doc();
 after.workbook.sheets.push({name:'New',cells:{},styles:{},widths:{}});
 assert.equal(diffWorkbook(before,after).type,'replace');
 const styled=doc();styled.workbook.rules=[{kind:'greaterThan',value:'5'}];
 assert.equal(diffWorkbook(before,styled).type,'replace');
});
test('only explicit loopback service URLs can receive credentials',()=>{
 assert.equal(collaborationEndpoint('http://127.0.0.1:8767'),'http://127.0.0.1:8767');
 for(const url of ['https://example.com','http://evil.test:8767',
   'http://127.0.0.1:8767/?key=test','http://user:pass@localhost:8767',
   'ws://127.0.0.1:8767','http://localhost:8767/private']){
  assert.throws(()=>collaborationEndpoint(url));
 }
});
