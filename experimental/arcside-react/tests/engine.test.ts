import {describe,it,expect} from 'vitest';
import {normalize,buildRows,formatMetric,sortRows,stintRows} from '../src/engine';
import type {JsonRow,SeasonSnapshot} from '../src/data';

// Values copied from committed Flutter test/nba_stats_workstation_engine_test.dart.
// Synthetic GOLDEN FIXTURE of the Dart engine, not NBA production facts.
const alpha:JsonRow={
 player_id:'alpha',player_label:'Alpha Guard',team_ids:'AAA',age:25,games:10,minutes:300,
 points:200,assists:80,rebounds:40,offensive_rebounds:5,defensive_rebounds:35,
 steals:20,blocks:2,turnovers:30,personal_fouls:18,
 field_goals_made:70,field_goal_attempts:140,three_pointers_made:20,
 three_point_attempts:50,free_throws_made:40,free_throw_attempts:50,plus_minus:50,avg_bpm:5.5
};
const beta:JsonRow={player_id:'beta',player_label:'Beta Center',team_ids:'BBB',age:29,
 games:10,minutes:250,points:120,assists:20,rebounds:100,offensive_rebounds:30,
 defensive_rebounds:70,steals:5,blocks:25,turnovers:20,personal_fouls:28,
 field_goals_made:50,field_goal_attempts:90,three_pointers_made:0,
 three_point_attempts:0,free_throws_made:20,free_throw_attempts:40,
 plus_minus:10,avg_bpm:2.0};
const fixture:SeasonSnapshot={season_id:'2025-26',season_type:'regular',
 players:[{player_id:'alpha',position:'PG'},{player_id:'beta',position:'C'}],
 player_season_totals:[alpha,beta]};
describe('limited NbaStatsWorkstationEngine port; anchored to original Dart test fixtures',()=>{
 it('matches sourced counting, percentages and derived efficiency',()=>{
  const row=buildRows(fixture,'perGame').find(r=>r.id==='alpha')!;
  expect(row.position).toBe('PG');
  expect(row.values.pts).toBe(20);
  expect(row.values.ast).toBe(8);
  expect(row.values.fg_pct).toBeCloseTo(.5,8);
  expect(row.values.three_pct).toBeCloseTo(.4,8);
  expect(row.values.ft_pct).toBeCloseTo(.8,8);
  expect(row.values.ts_pct).toBeCloseTo(200/(2*(140+.44*50)),8);
  expect(row.values.efg_pct).toBeCloseTo((70+.5*20)/140,8);
  expect(row.estimated).toBe(true);
 });
 it('matches totals, per 36, per 48 and possession basis',()=>{
  expect(normalize(alpha,{},'totals').values.pts).toBe(200);
  expect(normalize(alpha,{},'per36').values.pts).toBeCloseTo(24,7);
  expect(normalize(alpha,{},'per48').values.pts).toBeCloseTo(32,7);
  expect(normalize(alpha,{},'per100').values.pts!).toBeGreaterThan(normalize(alpha,{},'per75').values.pts!);
 });
 it('matches Flutter direction-aware percentiles on distinct values',()=>{
  const rows=buildRows(fixture,'perGame');
  expect(rows[0].percentiles.pts).toBe(100);
  expect(rows[1].percentiles.pts).toBe(0);
  expect(rows[0].percentiles.tov).toBe(0);
  expect(rows[1].percentiles.tov).toBe(100);
 });
 it('preserves canonically supplied historical percentages when attempts are unavailable',()=>{
  const row=normalize({player_id:'historical',games:30,minutes:900,points:400,
   field_goal_percentage:.47,three_point_percentage:.35,free_throw_percentage:.79,
   true_shooting_percentage:.56,effective_field_goal_percentage:.51},{},'perGame');
  expect(row.values.fg_pct).toBeCloseTo(.47);
  expect(row.values.three_pct).toBeCloseTo(.35);
  expect(row.values.ft_pct).toBeCloseTo(.79);
  expect(row.values.ts_pct).toBeCloseTo(.56);
  expect(row.values.efg_pct).toBeCloseTo(.51);
 });
 it('does not fabricate unavailable source-backed values as zero',()=>{
  const row=normalize({player_id:'sparse',games:10,minutes:100,points:0},{},'perGame');
  expect(row.values.pts).toBe(0); // actual source-backed zero
  expect(row.values.ast).toBeNull(); // missing field
  expect(row.values.ts_pct).toBeNull();
  expect(formatMetric('ast',row.values.ast)).toBe('—');
 });
 it('uses null-last stable sorting with deterministic tie breaks',()=>{
  const rows=buildRows(fixture,'perGame'),sparse=normalize({player_id:'missing',player_label:'Absent',games:5},{},'perGame');
  expect(sortRows([...rows,sparse],'pts').map(r=>r.id)).toEqual(['alpha','beta','missing']);
  expect(sortRows([...rows,sparse],'pts',false).map(r=>r.id)).toEqual(['beta','alpha','missing']);
 });
 it('only expands actual source-recorded stints, never estimates team splits',()=>{
  const raw={...alpha,team_ids:'AAA,BBB',team_stints:[
   {...alpha,team_ids:'AAA',games:5,points:100},
   {...alpha,team_ids:'BBB',games:5,points:100}
  ]};
  const row=normalize(raw,{},'perGame');
  expect(stintRows(row,'perGame').map(s=>s.team)).toEqual(['AAA','BBB']);
  expect(stintRows(normalize({...alpha,team_ids:'AAA,BBB'}, {},'perGame'),'perGame')).toEqual([]);
 });
 it('keeps playoff and regular season records separated',()=>{
  const play:{season_id:string;season_type:'playoffs';player_season_totals:JsonRow[];players:JsonRow[]}={
   season_id:'2025-26',season_type:'playoffs',player_season_totals:[
    {...alpha,season_type:'regular'}, {...beta,season_type:'playoffs'}
   ],players:[]
  };
  expect(buildRows(play,'perGame').map(r=>r.id)).toEqual(['beta']);
 });
});
