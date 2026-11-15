import test from 'node:test';
import assert from 'node:assert/strict';
import {Workbook,sampleWorkbook,parseFormula,parseCsv,stringifyCsv,columnName,parseRef,expandRange} from '../sheets/core.mjs';

const wb=()=>new Workbook();
test('column names and absolute references',()=>{
  assert.equal(columnName(1),'A');assert.equal(columnName(26),'Z');assert.equal(columnName(27),'AA');
  assert.equal(columnName(703),'AAA');assert.equal(parseRef('$AC$12').ref,'AC12');
  assert.deepEqual(expandRange('A1','B2'),['A1','B1','A2','B2']);
});
test('sample workbook is computed, not a mockup',()=>{
  const x=sampleWorkbook();
  assert.equal(x.display('Analysis','D2'),'38000');
  assert.equal(x.display('Analysis','D6'),'153700');
});
test('precedence, powers, nested function calls',()=>{
  const x=wb();x.set('Sheet1','A1','=2*(3+4)^2');
  x.set('Sheet1','A2','=ROUND(10/3,2)');
  x.set('Sheet1','A3','=SUM(1,2,ROUND(3.9,0))');
  assert.equal(x.display('Sheet1','A1'),'98');
  assert.equal(x.display('Sheet1','A2'),'3.33');
  assert.equal(x.display('Sheet1','A3'),'7');
});
test('IF is lazy and IFERROR catches errors',()=>{
  const x=wb();x.set('Sheet1','A1','=IF(TRUE,2,1/0)');
  x.set('Sheet1','A2','=IFERROR(1/0,42)');
  assert.equal(x.display('Sheet1','A1'),'2');
  assert.equal(x.display('Sheet1','A2'),'42');
});
test('dependency invalidation is transitive',()=>{
  const x=wb();x.set('Sheet1','A1','2');x.set('Sheet1','B1','=A1+5');x.set('Sheet1','C1','=B1*2');
  assert.equal(x.display('Sheet1','C1'),'14');x.set('Sheet1','A1','10');
  assert.equal(x.display('Sheet1','B1'),'15');assert.equal(x.display('Sheet1','C1'),'30');
});
test('circular references detected',()=>{
  const x=wb();x.set('Sheet1','A1','=B1+1');x.set('Sheet1','B1','=A1+1');
  assert.equal(x.display('Sheet1','A1'),'#CYCLE!');
  assert.equal(x.display('Sheet1','B1'),'#CYCLE!');
});
test('aggregate functions and blanks',()=>{
  const x=wb();x.set('Sheet1','A1','2');x.set('Sheet1','A2','4');
  x.set('Sheet1','B1','=SUM(A1:A3)');x.set('Sheet1','B2','=AVERAGE(A1:A3)');
  x.set('Sheet1','B3','=COUNT(A1:A3)');x.set('Sheet1','B4','=COUNTA(A1:A3)');
  assert.equal(x.display('Sheet1','B1'),'6');
  assert.equal(x.display('Sheet1','B2'),'3');
  assert.equal(x.display('Sheet1','B3'),'2');
  assert.equal(x.display('Sheet1','B4'),'2');
});
test('cross-sheet dependency invalidation',()=>{
  const x=wb();x.addSheet('Inputs 2026');x.set('Inputs 2026','A1','10');
  x.set('Sheet1','B2',"='Inputs 2026'!A1*3");
  assert.equal(x.display('Sheet1','B2'),'30');
  x.set('Inputs 2026','A1','12');
  assert.equal(x.display('Sheet1','B2'),'36');
});
test('sheet renaming rewrites references',()=>{
  const x=wb();x.addSheet('Sales 2026');x.set('Sales 2026','A1','7');
  x.set('Sheet1','A1',"='Sales 2026'!A1");
  x.renameSheet('Sales 2026','New Sales');
  assert.equal(x.get('Sheet1','A1'),"='New Sales'!A1");
  assert.equal(x.display('Sheet1','A1'),'7');
});
test('missing sheet, unknown function and malformed formula',()=>{
  const x=wb();x.set('Sheet1','A1','=Ghost!A1');
  x.set('Sheet1','A2','=MISSING(1)');x.set('Sheet1','A3','=SUM(');
  assert.equal(x.display('Sheet1','A1'),'#REF!');
  assert.equal(x.display('Sheet1','A2'),'#NAME?');
  assert.equal(x.display('Sheet1','A3'),'#ERROR!');
});
test('formula parser cannot run arbitrary JavaScript',()=>{
  const x=wb();x.set('Sheet1','A1','=constructor.constructor("return 1")()');
  assert.equal(x.display('Sheet1','A1'),'#ERROR!');
  assert.ok(parseFormula('SUM(1,2)'));
});
test('save/restore formulas and formatting',()=>{
  const x=sampleWorkbook();x.setStyle('Analysis','B2',{bold:true,numberFormat:'currency'});
  const y=new Workbook(JSON.parse(JSON.stringify(x.toJSON())));
  assert.equal(y.display('Analysis','D2'),'38000');
  assert.equal(y.sheets.get('Analysis').styles.B2.numberFormat,'currency');
});
test('CSV roundtrip commas, quotes, Unicode and line breaks',()=>{
  const matrix=[['name','quote','note'],['São Paulo','He said "hi"','one\nsecond'],['x,y','','5']];
  assert.deepEqual(parseCsv(stringifyCsv(matrix)),matrix);
});
test('oversized ranges are rejected',()=>{
  assert.throws(()=>expandRange('A1','Z99999'),error=>error.code==='#REF!');
});


test('relative references rebase but absolute row and column anchors remain fixed',async()=>{
  const {rebaseFormula}=await import('../sheets/references.mjs');
  assert.equal(rebaseFormula('=A1+$B2+C$3+$D$4',2,1),'=B3+$B4+D$3+$D$4');
  assert.equal(rebaseFormula('=$A$1',100,200),'=$A$1');
});
test('quoted strings and sheet names are not accidentally modified',async()=>{
  const {rebaseFormula}=await import('../sheets/references.mjs');
  assert.equal(rebaseFormula('=IF(A1="B2",A1,0)',1,1),'=IF(B2="B2",B2,0)');
  assert.equal(rebaseFormula("='A1'!C3+ASDF2!B4",1,2),"='A1'!E4+ASDF2!D5");
  assert.equal(rebaseFormula('=AA12&"A1"',0,1),'=AB12&"A1"');
});
test('negative out-of-bounds relative references become REF errors',async()=>{
  const {rebaseFormula}=await import('../sheets/references.mjs');
  assert.equal(rebaseFormula('=A1',-1,0),'=#REF!');
});
