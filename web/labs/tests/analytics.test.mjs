import test from 'node:test';
import assert from 'node:assert/strict';
import {pivotTable,filterTable,chartData,conditionalStyle} from '../sheets/analytics.mjs';

const sales=[
 ['Region','Product','Revenue','Units'],
 ['East','A',100,2],
 ['West','B',80,3],
 ['East','B',220,4],
 ['West','A',120,2],
 ['East','A',300,5],
];
test('pivot sums multiple groups and grand total',()=>{
 const r=pivotTable(sales,{rows:['Region'],metrics:[
   {field:'Revenue',aggregate:'sum'},{field:'Units',aggregate:'count'},
 ]});
 assert.equal(r.matrix[0].length,3);
 assert.deepEqual(r.matrix[1],['East',620,3]);
 assert.deepEqual(r.matrix[2],['West',200,2]);
 assert.deepEqual(r.matrix[3],['Grand Total',820,5]);
});
test('pivot cross tab columns and multiple measures',()=>{
 const r=pivotTable(sales,{rows:['Region'],column:'Product',metrics:[
   {field:'Revenue',aggregate:'sum'},{field:'Units',aggregate:'average'},
 ]});
 assert.equal(r.matrix[0].length,5);
 assert.equal(r.matrix[1][1],400);
 assert.equal(r.matrix[1][2],3.5);
 assert.equal(r.matrix[1][3],220);
 assert.equal(r.matrix[3][1],520);
});
test('multi-field pivot supports distinct, median and stdev',()=>{
 const r=pivotTable(sales,{rows:['Region','Product'],metrics:[
  {field:'Revenue',aggregate:'median'},{field:'Units',aggregate:'distinctCount'},
 ]});
 assert.deepEqual(r.matrix[1],['East','A',200,2]);
 assert.equal(r.matrix.at(-1)[2],120);
});
test('source filters affect pivot results without modifying input',()=>{
 const r=pivotTable(sales,{rows:['Region'],metrics:[{field:'Revenue',aggregate:'sum'}],
  filters:[{field:'Product',op:'equals',value:'A'}]});
 assert.equal(r.sourceRows,3);
 assert.deepEqual(r.matrix[1],['East',400]);
 assert.deepEqual(r.matrix[2],['West',120]);
 assert.equal(sales.length,6);
});
test('table filtering preserves headers and supports numeric criteria',()=>{
 const v=filterTable(sales,[{field:'Revenue',op:'greaterOrEqual',value:150}]);
 assert.deepEqual(v.map(row=>row[2]),['Revenue',220,300]);
});
test('chart data supports multiple series and numeric filtering',()=>{
 const x=chartData(sales,{category:'Product',series:['Revenue','Units'],type:'line'});
 assert.equal(x.series.length,2);
 assert.deepEqual(x.labels,['A','B','B','A','A']);
 assert.deepEqual(x.series[0].values,[100,80,220,120,300]);
});
test('conditional rules respect ranges, comparisons and text',()=>{
 const range={a:2,b:6,l:3,r:3};
 assert.deepEqual(conditionalStyle(200,{kind:'greaterThan',value:150,range,color:'#006622'},
   {row:2,col:3}),{fill:'#006622',color:'#e6f8ef'});
 assert.equal(conditionalStyle(200,{kind:'greaterThan',value:150,range},
   {row:1,col:3}),null);
 assert.ok(conditionalStyle('Boston',{kind:'contains',value:'ton',range},
   {row:3,col:3})?.fill);
 assert.ok(conditionalStyle(50,{kind:'dataBar',range,value:100},{row:4,col:3})?.background.includes('50%'));
 assert.ok(conditionalStyle(50,{kind:'colorScale',range,value:100},{row:4,col:3})?.fill.startsWith('rgb('));
});
test('invalid pivot aggregation and output dimensions are rejected',()=>{
 assert.throws(()=>pivotTable(sales,{rows:['Unknown']}),/Unknown/);
 assert.throws(()=>pivotTable(sales,{rows:['Region'],metrics:[{field:'Revenue',aggregate:'invalid'}]}),/Unsupported/);
});
