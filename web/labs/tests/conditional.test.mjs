import test from 'node:test';
import assert from 'node:assert/strict';
import {conditionalStyle,matchesRule,validateRule} from '../sheets/conditional.mjs';
import {Workbook} from '../sheets/core.mjs';

const area={a:2,b:8,l:2,r:4};
test('conditional comparisons handle live numeric values',()=>{
  assert.equal(matchesRule('38000',{operator:'greaterThan',value:'40000'}),false);
  assert.equal(matchesRule('48000',{operator:'greaterThan',value:'40000'}),true);
  assert.equal(matchesRule(-2,{operator:'lessThan',value:'0'}),true);
  assert.equal(matchesRule(3,{operator:'between',value:1,value2:4}),true);
  assert.equal(matchesRule(0,{operator:'greaterOrEqual',value:0}),true);
});
test('text, empty and error highlighting are safe and case insensitive',()=>{
  assert.equal(matchesRule('ARCSIDE',{operator:'textContains',value:'side'}),true);
  assert.equal(matchesRule('',{operator:'isBlank'}),true);
  assert.equal(matchesRule(0,{operator:'isBlank'}),false);
  assert.equal(matchesRule('#DIV/0!',{operator:'isError'}),true);
  assert.equal(matchesRule('hello',{operator:'isNotBlank'}),true);
  assert.equal(matchesRule('something',{operator:'textContains',value:''}),false);
});
test('overlapping rules respect order and selected range',()=>{
  const rules=[
    validateRule({range:area,operator:'greaterThan',value:5,fill:'#112233',color:'#eeeeee'}),
    validateRule({range:area,operator:'greaterThan',value:8,fill:'#445566',color:'#dddddd'})
  ];
  assert.equal(conditionalStyle(rules,1,2,10),null);
  assert.equal(conditionalStyle(rules,4,2,6).fill,'#112233');
  assert.equal(conditionalStyle(rules,4,2,10).fill,'#445566');
  assert.equal(conditionalStyle(rules,4,6,10),null);
});
test('validation blocks unbounded selectors and malicious color text',()=>{
  assert.throws(()=>validateRule({range:{a:1,b:100001,l:1,r:256},operator:'greaterThan'}),/range/i);
  assert.throws(()=>validateRule({range:area,operator:'eval'}),/operator/);
  assert.throws(()=>validateRule({range:area,operator:'equals',fill:'url(javascript:bad)'}),/hex RGB/);
});
test('conditional rules persist and bulk set refreshes cross-sheet formulas',()=>{
  const wb=new Workbook();
  wb.set('Sheet1','A1','10');
  wb.addSheet('Derived');
  wb.set('Derived','A1','=Sheet1!A1*2');
  wb.setCondition('Sheet1',{range:area,operator:'greaterThan',value:5});
  assert.equal(wb.display('Derived','A1'),'20');
  wb.replaceSheetCells('Sheet1',[['A1','30']]);
  assert.equal(wb.display('Derived','A1'),'60');
  const restored=new Workbook(wb.toJSON());
  assert.equal(restored.sheets.get('Sheet1').conditions.length,1);
  assert.equal(restored.display('Derived','A1'),'60');
  restored.clearConditions('Sheet1');
  assert.equal(restored.sheets.get('Sheet1').conditions.length,0);
});
