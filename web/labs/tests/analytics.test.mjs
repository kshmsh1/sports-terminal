import test from 'node:test';
import assert from 'node:assert/strict';
import {buildPivot,filterTable} from '../sheets/analytics.mjs';

const sales=[
  ['Region','Product','Year','Revenue','Customer'],
  ['East','A',2025,100,'C1'],
  ['East','B',2025,200,'C1'],
  ['West','A',2025,350,'C2'],
  ['West','B',2026,450,'C3'],
  ['East','A',2026,700,'C4'],
];

test('two dimensional pivot sums across row and column grouping with totals',()=>{
  const result=buildPivot(sales,{rows:[0],column:2,value:3,aggregate:'sum'});
  assert.deepEqual(result.matrix,[
    ['Region','2025','2026','Grand Total'],
    ['East',300,700,1000],
    ['West',350,450,800],
    ['Grand Total',650,1150,1800]
  ]);
  assert.equal(result.meta.records,5);
});
test('multi-level row grouping and filtered source',()=>{
  const result=buildPivot(sales,{
    rows:[0,1],column:null,value:3,aggregate:'sum',
    filter:{field:2,mode:'equals',value:'2025'}
  });
  assert.deepEqual(result.matrix,[
    ['Region','Product','Revenue · sum'],
    ['East','A',100],
    ['East','B',200],
    ['West','A',350],
    ['Grand Total','',650],
  ]);
});
test('average is weighted by source observations, not average of group means',()=>{
  const result=buildPivot(sales,{rows:[0],column:2,value:3,aggregate:'average'});
  assert.deepEqual(result.matrix,[
    ['Region','2025','2026','Grand Total'],
    ['East',150,700,1000/3],
    ['West',350,450,400],
    ['Grand Total',650/3,575,360]
  ]);
});
test('distinct customer count is scoped independently per pivot cell',()=>{
  const result=buildPivot(sales,{rows:[0],column:null,value:4,aggregate:'countDistinct'});
  assert.deepEqual(result.matrix,[
    ['Region','Customer · countDistinct'],
    ['East',2],
    ['West',2],
    ['Grand Total',4]
  ]);
});
test('median, min, max and source filters work without mutating data',()=>{
  const med=buildPivot(sales,{rows:[0],value:3,aggregate:'median'});
  assert.deepEqual(med.matrix[1],['East',200]);
  const min=buildPivot(sales,{rows:[0],value:3,aggregate:'min'});
  assert.equal(min.matrix[2][1],350);
  const max=buildPivot(sales,{rows:[0],value:3,aggregate:'max'});
  assert.equal(max.matrix.at(-1)[1],700);
  assert.equal(sales.length,6);
});
test('filter and numeric sort preserve header and do not rewrite original table',()=>{
  const filtered=filterTable(sales,{field:0,mode:'equals',value:'east',sort:'desc',sortField:3});
  assert.equal(filtered.length,4);
  assert.equal(filtered[0][0],'Region');
  assert.equal(filtered[1][3],700);
  assert.equal(filtered.at(-1)[3],100);
  assert.equal(sales.length,6);
});
test('invalid pivots reject unsupported source dimensions',()=>{
  assert.throws(()=>buildPivot(sales,{rows:[15],value:3}),/Invalid pivot/);
  assert.throws(()=>buildPivot(sales,{rows:[0],value:3,aggregate:'javascript'}),/Invalid pivot/);
});


test('large 20,000-row pivot aggregates without materializing a grid-sized DOM',()=>{
  const rows=[['Region','FiscalYear','Value']];
  for(let i=0;i<20000;i++)
    rows.push(['Division'+(i%40),2025+i%2,i%7]);
  const result=buildPivot(rows,{rows:[0],column:1,value:2,aggregate:'sum'});
  assert.equal(result.meta.records,20000);
  assert.equal(result.meta.groups,40);
  assert.equal(result.matrix.length,42); // Header, 40 groups, grand total.
  assert.equal(result.matrix[0].length,4);
  const expected=rows.slice(1).reduce((sum,row)=>sum+row[2],0);
  assert.equal(result.matrix.at(-1).at(-1),expected);
});
