import {describe,it,expect} from 'vitest';
import {buildRows} from '../src/engine';
import {advancedGroups,advancedMetricCatalog} from '../src/advancedCatalog';
import {advancedLabel,advancedText,metricValue} from '../src/AdvancedStatsTable';
import type {SeasonSnapshot} from '../src/data';
const snapshot:SeasonSnapshot={season_id:'2025-26',season_type:'regular',players:[],
 player_season_totals:[{player_id:'one',player_label:'Test Player',team_ids:'BOS',games:50,
  minutes:1500,points:1000,assists:250,rebounds:200,field_goals_made:350,
  field_goal_attempts:700,three_pointers_made:120,three_point_attempts:300,
  free_throws_made:180,free_throw_attempts:200,deflections_pg:3.5,per:19.2}]};
describe('Flutter catalog-backed React Advanced Stats pilot',()=>{
 it('retains the full Flutter category taxonomy and reference metric identities',()=>{
  expect(advancedGroups).toHaveLength(18);
  expect(advancedGroups.map(g=>g.name)).toEqual([
   'Overview','Shooting & Efficiency','Defensive / Hustle','Hustle Breakdown',
   'Playmaking / Possession','Rebounding','Impact','Aggregate Metrics',
   'Movement','Clutch','Shot Profile','Play Type','Isolation','Gravity / Creation',
   'Physical Profile','Fouls / Discipline','Availability / Injury','Rate Adjusted']);
  for(const g of advancedGroups)for(const k of g.keys)expect(advancedMetricCatalog[k],g.name+': '+k).toBeDefined();
 });
 it('matches PPG, PTS/36 and PTS/100 labels and source-calculated values',()=>{
  const pg=buildRows(snapshot,'perGame')[0],p36=buildRows(snapshot,'per36')[0],p100=buildRows(snapshot,'per100')[0];
  expect(advancedLabel('ppg','perGame')).toBe('PPG');
  expect(advancedLabel('ppg','per36')).toBe('PTS/36');
  expect(advancedLabel('ppg','per100')).toBe('PTS/100');
  expect(metricValue(pg,'ppg')).toBe(20);
  expect(metricValue(p36,'ppg')).toBeCloseTo(24);
  expect(metricValue(p100,'ppg')).toBeGreaterThan(0);
  expect(metricValue(p100,'ppg')).not.toBe(metricValue(pg,'ppg'));
 });
 it('exposes genuinely present native metrics and avoids invented data',()=>{
  const row=buildRows(snapshot,'perGame')[0];
  expect(metricValue(row,'deflections_pg')).toBe(3.5);
  expect(metricValue(row,'per')).toBe(19.2);
  expect(metricValue(row,'lebron')).toBeNull();
  expect(advancedText(row,'lebron')).toBe('—');
 });
 it('does not scale rate-insensitive efficiency statistics when rate basis changes',()=>{
  const pg=buildRows(snapshot,'perGame')[0],p100=buildRows(snapshot,'per100')[0];
  expect(metricValue(pg,'fg_pct')).toBeCloseTo(metricValue(p100,'fg_pct')!);
 });
});
