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


test('COUNTIF/SUMIF/AVERAGEIF and wildcard criteria evaluate correctly',()=>{
  const x=wb();
  for(const [ref,value] of Object.entries({A1:1,A2:2,A3:2,B1:10,B2:20,B3:30,C1:'NY',C2:'CA',C3:'NY'}))x.set('Sheet1',ref,value);
  x.set('Sheet1','D1','=COUNTIF(A1:A3,">=2")');
  x.set('Sheet1','D2','=SUMIF(C1:C3,"NY",B1:B3)');
  x.set('Sheet1','D3','=AVERAGEIF(A1:A3,">=2",B1:B3)');
  x.set('Sheet1','D4','=COUNTIF(C1:C3,"N*")');
  assert.equal(x.display('Sheet1','D1'),'2');
  assert.equal(x.display('Sheet1','D2'),'40');
  assert.equal(x.display('Sheet1','D3'),'25');
  assert.equal(x.display('Sheet1','D4'),'2');
});
test('SUMIFS and COUNTIFS evaluate multiple filters',()=>{
  const x=wb();
  for(const [ref,value] of Object.entries({A1:1,A2:2,A3:2,B1:10,B2:20,B3:30,C1:'NY',C2:'CA',C3:'NY'}))x.set('Sheet1',ref,value);
  x.set('Sheet1','D1','=SUMIFS(B1:B3,C1:C3,"NY",A1:A3,">=2")');
  x.set('Sheet1','D2','=COUNTIFS(C1:C3,"NY",A1:A3,">=2")');
  assert.equal(x.display('Sheet1','D1'),'30');
  assert.equal(x.display('Sheet1','D2'),'1');
});
test('exact lookup functions, no-match error and IFNA handling',()=>{
  const x=wb();
  for(const [ref,value] of Object.entries({A1:1,A2:2,A3:3,B1:10,B2:20,B3:30}))x.set('Sheet1',ref,value);
  x.set('Sheet1','C1','=VLOOKUP(2,A1:B3,2,FALSE)');
  x.set('Sheet1','C2','=XLOOKUP(3,A1:A3,B1:B3)');
  x.set('Sheet1','C3','=INDEX(A1:B3,1,2)');
  x.set('Sheet1','C4','=MATCH(20,B1:B3,0)');
  x.set('Sheet1','C5','=IFNA(XLOOKUP(8,A1:A3,B1:B3),"not found")');
  x.set('Sheet1','C6','=IFNA(1/0,"should fail")');
  assert.deepEqual(['C1','C2','C3','C4','C5','C6'].map(ref=>x.display('Sheet1',ref)),
    ['20','30','10','2','not found','#DIV/0!']);
});
test('rounding follows Excel direction for negative numbers',()=>{
  const x=wb();
  x.set('Sheet1','A1','=ROUND(-1.5,0)');
  x.set('Sheet1','A2','=ROUNDUP(-1.2,0)');
  x.set('Sheet1','A3','=ROUNDDOWN(-1.7,0)');
  assert.deepEqual([1,2,3].map(i=>x.display('Sheet1','A'+i)),['-2','-2','-1']);
});
test('text functions handle empty RIGHT, MID, FIND, SUBSTITUTE',()=>{
  const x=wb();
  x.set('Sheet1','A1','=RIGHT("hello",0)');
  x.set('Sheet1','A2','=MID("Arcside",2,3)');
  x.set('Sheet1','A3','=FIND("s","Arcside")');
  x.set('Sheet1','A4','=SUBSTITUTE("NBA NBA","NBA","Arcside")');
  assert.deepEqual([1,2,3,4].map(i=>x.display('Sheet1','A'+i)),
    ['','rcs','4','Arcside Arcside']);
});
