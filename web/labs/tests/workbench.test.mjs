import test from 'node:test';
import assert from 'node:assert/strict';
import {matchCommands} from '../workbench.mjs';

const catalog=[
 {label:'Run Python file',section:'Run & debug',keywords:'execute',order:1},
 {label:'Export workbook',section:'Workbook',order:6},
 {label:'Open Pivot Studio',section:'Analyze',keywords:'pivot table',order:7},
 {label:'Open Python terminal',section:'Panels',order:3},
];
test('search matches labels, functional keywords and categories without exact phrasing',()=>{
 assert.deepEqual(matchCommands(catalog,'python').map(x=>x.label),
   ['Run Python file','Open Python terminal']);
 assert.deepEqual(matchCommands(catalog,'pivot table').map(x=>x.label),['Open Pivot Studio']);
 assert.deepEqual(matchCommands(catalog,'workbook').map(x=>x.label),['Export workbook']);
});
test('multiple search terms match regardless of order and rank by stable priority',()=>{
 assert.deepEqual(matchCommands(catalog,'studio pivot').map(x=>x.label),['Open Pivot Studio']);
 assert.deepEqual(matchCommands(catalog,'').map(x=>x.label),
   ['Run Python file','Open Python terminal','Export workbook','Open Pivot Studio']);
});
test('unknown action is never returned',()=>{
 assert.deepEqual(matchCommands(catalog,'delete filesystem'),[]);
});
