import test from 'node:test';
import assert from 'node:assert/strict';
import {ArcsideWorkbook, parseAddress, colLabel, colIndex} from '../web/labs/excel/engine.mjs';

const workbook=()=>new ArcsideWorkbook();
test('base-26 references and column indexes',()=>{
  assert.equal(colLabel(0),'A');
  assert.equal(colLabel(25),'Z');
  assert.equal(colLabel(26),'AA');
  assert.equal(colLabel(701),'ZZ');
  assert.equal(colIndex('ZZ'),701);
  assert.deepEqual(parseAddress('$BC$123'),{row:122,col:54,ref:'BC123'});
});
test('formula precedence, references and ranges',()=>{
  const w=workbook(),s=w.active.id;
  w.setRaw(s,'A1','10');w.setRaw(s,'A2','20');
  w.setRaw(s,'B1','=SUM(A1:A2)*2+3');
  assert.equal(w.getValue(s,'B1'),63);
  w.setRaw(s,'B2','=A1+A2/2');
  assert.equal(w.getValue(s,'B2'),20);
  w.setRaw(s,'C1','=AVERAGE(A1:A2)');
  assert.equal(w.getValue(s,'C1'),15);
  w.setRaw(s,'C2','=ROUND(1.234,2)');
  assert.equal(w.getValue(s,'C2'),1.23);
});
test('editing a source invalidates indirect dependents',()=>{
  const w=workbook(),s=w.active.id;
  w.setRaw(s,'A1','1');
  w.setRaw(s,'B1','=A1+2');
  w.setRaw(s,'C1','=B1*2');
  assert.equal(w.getValue(s,'C1'),6);
  w.setRaw(s,'A1','3');
  assert.equal(w.getValue(s,'C1'),10);
  w.setRaw(s,'B1','=A1*3');
  assert.equal(w.getValue(s,'C1'),18);
});
test('cross-sheet formulas and renamed workbooks',()=>{
  const w=workbook();const first=w.active.id;
  const s=w.addSheet('Budget');
  w.setRaw(s.id,'A1','250');
  w.setRaw(first,'A1','=Budget!A1*2');
  assert.equal(w.getValue(first,'A1'),500);
  w.setRaw(first,'A2',"='Budget'!A1+5");
  assert.equal(w.getValue(first,'A2'),255);
});
test('circular references and missing sheets are explicit errors',()=>{
  const w=workbook(),s=w.active.id;
  w.setRaw(s,'A1','=B1');
  w.setRaw(s,'B1','=A1');
  assert.equal(w.getValue(s,'A1'),'#CIRC!');
  assert.equal(w.getValue(s,'B1'),'#CIRC!');
  w.setRaw(s,'C1','=Missing!A1');
  assert.equal(w.getValue(s,'C1'),'#REF!');
});
test('lazy IF and IFERROR avoid errors in untaken branches',()=>{
  const w=workbook(),s=w.active.id;
  w.setRaw(s,'A1','=IF(1=1,7,1/0)');
  assert.equal(w.getValue(s,'A1'),7);
  w.setRaw(s,'A2','=IFERROR(1/0,42)');
  assert.equal(w.getValue(s,'A2'),42);
  w.setRaw(s,'A3','=1/0');
  assert.equal(w.getValue(s,'A3'),'#DIV/0!');
});
test('numeric, string, boolean and lookup functions',()=>{
  const w=workbook(),s=w.active.id;
  w.setRaw(s,'A1','A');w.setRaw(s,'B1','12');
  w.setRaw(s,'A2','B');w.setRaw(s,'B2','25');
  w.setRaw(s,'C1','=VLOOKUP("B",A1:B2,2,TRUE)');
  assert.equal(w.getValue(s,'C1'),25);
  w.setRaw(s,'C2','=COUNT(B1:B2)+SUM(B1:B2)');
  assert.equal(w.getValue(s,'C2'),39);
  w.setRaw(s,'C3','=IF(AND(B1>10,B2>20),"yes","no")');
  assert.equal(w.getValue(s,'C3'),'yes');
  w.setRaw(s,'C4','=COUNTIF(B1:B2,">20")');
  assert.equal(w.getValue(s,'C4'),1);
  w.setRaw(s,'C5','=SUMIF(B1:B2,">20")');
  assert.equal(w.getValue(s,'C5'),25);
});
test('styles and workbook data survive project JSON reload',()=>{
  const w=workbook(),s=w.active.id;
  w.setRaw(s,'A1','8');w.setRaw(s,'B1','=A1/2');
  w.setStyle(s,'B1',{format:'currency',bold:true});
  const recovered=new ArcsideWorkbook(JSON.parse(JSON.stringify(w.snapshot())));
  assert.equal(recovered.getValue(s,'B1'),4);
  assert.equal(recovered.display(s,'B1'),'$4.00');
  assert.equal(recovered.getStyle(s,'B1').bold,true);
});
test('no eval() or arbitrary JS execution in formula parser',async()=>{
  const {readFile}=await import('node:fs/promises');
  const text=await readFile(new URL('../web/labs/excel/engine.mjs',import.meta.url),'utf8');
  assert.doesNotMatch(text,/\beval\s*\(/);
  assert.doesNotMatch(text,/\bnew Function\s*\(/);
});
