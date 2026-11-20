import {describe,it,expect} from 'vitest';
import {selectVisualizationRows,linearStats,quantile,histogram,correlationLabel,rowTeams} from '../src/visualization_math';
import type {Row,MetricKey} from '../src/engine';

function row(id:string,pts:number,ast:number,gp=55,team='BOS'):Row{
 const keys=['gp','min','pts','ast','reb','stl','blk','ts_pct'] as MetricKey[];
 const values=Object.fromEntries(keys.map(k=>[k,k==='gp'?gp:k==='pts'?pts:k==='ast'?ast:1])) as Row['values'];
 return {id,player:id,team,position:'PG',raw:{},estimated:false,values,percentiles:{}};
}
describe('Flutter-matched visualization population and statistical projections',()=>{
 it('selects top 40 by actual Y metric after qualification with stable name/id ties',()=>{
  const rows=Array.from({length:60},(_,i)=>row('Player '+String(i).padStart(2,'0'),i,i/2));
  const sample=selectVisualizationRows(rows,{x:'ast',y:'pts',kind:'scatter',minGames:50,
   population:40,filter:''});
  expect(sample.matching).toHaveLength(60);
  expect(sample.eligible).toHaveLength(60);
  expect(sample.plotted).toHaveLength(40);
  expect(sample.plotted[0].player).toBe('Player 59');
  expect(sample.plotted.at(-1)?.player).toBe('Player 20');
  expect(selectVisualizationRows(rows,{x:'ast',y:'pts',kind:'scatter',minGames:50,
   population:0,filter:''}).plotted).toHaveLength(60);
  const ties=[row('Z',5,2),row('A',5,1)];
  expect(selectVisualizationRows(ties,{x:'ast',y:'pts',kind:'scatter',
   minGames:0,population:40,filter:''}).plotted.map(r=>r.player)).toEqual(['A','Z']);
 });
 it('counts min GP independently of raw totals; source-null rows are excluded',()=>{
  const rows=[row('eligible',10,5,50),row('lowGP',20,10,49),row('missing',30,8,60)];
  rows[2].values.ast=null;
  const result=selectVisualizationRows(rows,{x:'ast',y:'pts',kind:'scatter',
   minGames:50,population:40,filter:''});
  expect(result.matching.map(r=>r.id)).toEqual(['eligible','missing']);
  expect(result.eligible.map(r=>r.id)).toEqual(['eligible']);
  expect(result.plotted.map(r=>r.id)).toEqual(['eligible']);
 });
 it('filters teams by historical stints and players by stable player ID',()=>{
  const r=row('traded',15,5,70,'2TM');
  r.raw.team_stints=[{team_abbreviation:'BOS'},{team_ids:'CHI'}];
  const rows=[r,row('other',10,4)];
  expect(rowTeams(r)).toEqual(['BOS','CHI']);
  const args={x:'ast' as MetricKey,y:'pts' as MetricKey,kind:'scatter' as const,
   minGames:50,population:40};
  expect(selectVisualizationRows(rows,{...args,filter:'team:CHI'}).plotted.map(x=>x.id))
   .toEqual(['traded']);
  expect(selectVisualizationRows(rows,{...args,filter:'player:other'}).plotted.map(x=>x.id))
   .toEqual(['other']);
 });
 it('calculates sample regression, R-squared and mean lines from plotted values',()=>{
  const stats=linearStats([row('one',3,1),row('two',5,2),row('three',7,3)],'ast','pts');
  expect(stats?.count).toBe(3);
  expect(stats?.slope).toBeCloseTo(2);
  expect(stats?.intercept).toBeCloseTo(1);
  expect(stats?.r).toBeCloseTo(1);
  expect(stats?.rSquared).toBeCloseTo(1);
  expect(stats?.meanX).toBe(2);
  expect(stats?.meanY).toBe(5);
  expect(correlationLabel(stats!.r)).toBe('strong positive');
  expect(linearStats([row('one',3,1)],'ast','pts')).toBeNull();
 });
 it('does not invent quartiles or histogram counts',()=>{
  expect(quantile([1,2,3,4],.25)).toBeCloseTo(1.75);
  expect(quantile([],.5)).toBeNull();
  expect(histogram([1,2,3,4],2).map(x=>x.count)).toEqual([2,2]);
  expect(histogram([],8)).toEqual([]);
 });
});
