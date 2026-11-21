import {describe,it,expect} from 'vitest';
import {buildTeamRows,leaderIndices} from '../src/ComparisonWorkspaces';
import type {SeasonSnapshot} from '../src/data';
const base=(extra:Partial<SeasonSnapshot>):SeasonSnapshot=>({
 season_id:'2025-26',season_type:'regular',players:[],player_season_totals:[],...extra
});
describe('original Flutter team comparison source contract',()=>{
 it('does not invent team values when complete team game logs are missing',()=>{
  const teams=buildTeamRows(base({teams:[{team_id:'AAA',name:'Alpha'}]}));
  expect(teams).toHaveLength(1);
  expect(teams[0].values.ppg).toBeUndefined();
  expect(teams[0].values.wins).toBeUndefined();
 });
 it('preserves canonical team-record points and wins',()=>{
  const teams=buildTeamRows(base({team_records:[{team_id:'AAA',team_name:'Alpha',
   games:4,wins:3,losses:1,points:404,opponent_points:400}]}));
  expect(teams[0].values.ppg).toBe(101);
  expect(teams[0].values.opp_ppg).toBe(100);
  expect(teams[0].values.point_diff).toBe(1);
  expect(teams[0].values.win_pct).toBe(.75);
 });
 it('only aggregates shooting percentages from complete published logs',()=>{
  const snapshot=base({team_records:[{team_id:'AAA',games:2}],
   team_game_logs:[{team_id:'AAA',result:'W',points:100,field_goals_made:40,field_goal_attempts:80},
    {team_id:'AAA',result:'L',points:102,field_goals_made:42,field_goal_attempts:80}]});
  const found=buildTeamRows(snapshot)[0];
  expect(found.values.wins).toBe(1);
  expect(found.values.fg_pct).toBe(82/160);
  expect(found.values.ppg).toBe(101);
  expect(found.values.ts_pct).toBeUndefined();
  const missing=buildTeamRows({...snapshot,team_game_logs:snapshot.team_game_logs?.slice(0,1)})[0];
  expect(missing.values.fg_pct).toBeUndefined();
  expect(missing.values.ppg).toBeUndefined();
 });
 it('winners require two observed values, and ties are shared',()=>{
  expect(leaderIndices([null,5])).toEqual([]);
  expect(leaderIndices([5,5,1])).toEqual([0,1]);
  expect(leaderIndices([5,2],false)).toEqual([1]);
 });
});