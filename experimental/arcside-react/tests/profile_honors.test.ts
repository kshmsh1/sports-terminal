import {describe,it,expect} from 'vitest';
import {profileHonors,orderedPositions} from '../src/profileHonors';
describe('original Dart nba_player_profile_format parity',()=>{
 it('orders and deduplicates player positions',()=>{
  expect(orderedPositions('SG, SF, PF, PG, C')).toBe('PG, SG, SF, PF, C');
  expect(orderedPositions('PF, PF, C')).toBe('PF, C');
  expect(orderedPositions('')).toBe('');
 });
 it('counts only confirmed MVP wins and translates to ending years',()=>{
  const rows=['2008-09','2009-10','2011-12','2012-13'].map(season_id=>
   ({award:'nba_mvp',season_id,winner:1}));
  rows.push({award:'nba_mvp',season_id:'2010-11',winner:0});
  const honors=profileHonors(rows);
  expect(honors).toEqual([{title:'Most Valuable Player (MVP)',years:[2009,2010,2012,2013]}]);
 });
 it('deduplicates All-NBA selections and all-star rows; never counts nominee wins',()=>{
  const honors=profileHonors([
   {award:'all_nba',season_id:'2014-15',winner:0},
   {award:'All-NBA',season_id:'2014-15',winner:0},
   {award:'nba_mvp',season_id:'2014-15',winner:0}
  ],[{season_id:'2015-16'},{season_id:'2015-16'}]);
  expect(honors).toEqual([
   {title:'All-NBA Team',years:[2015]},
   {title:'NBA All-Star',years:[2016]}
  ]);
 });
 it('uses source-confirmed award rows, not generic category or blank-year rows',()=>{
  expect(profileHonors([{award:'nba_mvp',season_id:'unknown',winner:1},
   {award:'nba_mvp',season_id:'2025-26',winner:0}])).toEqual([]);
 });
});