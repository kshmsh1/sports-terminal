import {describe,it,expect} from 'vitest';
import {resolveTeamIndex} from '../src/data';
import {teamCareerSeasons,joinTeamRoster} from '../src/TeamDetailWorkspace';
import {gameType,selectPublishedGames} from '../src/GamesWorkspace';
import {originalFlutterPlan} from '../src/FranchiseHistoryWorkspace';
import type {SeasonSnapshot,DatedContractSnapshot} from '../src/data';
describe('canonical Flutter team, game and franchise contracts',()=>{
 it('resolves exact key and abbreviation ahead of unrelated fuzzy candidates',()=>{
  const teams=[{team_key:'old-chi',canonical_name:'Chicago Team'},
   {team_key:'team-chi',abbreviation:'CHI',canonical_name:'Chicago'}];
  expect(resolveTeamIndex(teams,'CHI')?.team_key).toBe('team-chi');
  expect(resolveTeamIndex(teams,'team-chi')?.team_key).toBe('team-chi');
  expect(resolveTeamIndex(teams,'no-such-franchise')).toBeNull();
 });
 it('preserves segment-specific real historical team rows',()=>{
  const data={seasons:[{season_id:'2024-25',season_type:'regular'},
   {season_id:'2024-25',season_type:'playoffs'}]};
  expect(teamCareerSeasons(data,'regular')).toHaveLength(1);
  expect(teamCareerSeasons(data,'playoffs')).toHaveLength(1);
 });
 it('joins roster only to source-published 2026–27 salary records',()=>{
  const snapshot:SeasonSnapshot={season_id:'2025-26',season_type:'regular',players:[],
   player_season_totals:[]};
  const contracts:DatedContractSnapshot={kind:'ARCSIDE_ORIGINAL_FLUTTER_2026_27_CONTRACT_SEED_V1',
   asOf:'2026-09-11',dartSeedSha256:'test',sourceNote:'synthetic',records:[
    {id:'CHI:x',player:'Test Player',team:'CHI',salaries:{'2026-27':12000000},
     guaranteed:null,sourceStatus:'test',sourceLabel:'synthetic'},
    {id:'BOS:y',player:'Other',team:'BOS',salaries:{'2026-27':9000000},
     guaranteed:null,sourceStatus:'test',sourceLabel:'synthetic'}
   ]};
  expect(joinTeamRoster(contracts,'CHI',snapshot)).toHaveLength(1);
  expect(joinTeamRoster(contracts,'NYK',snapshot)).toHaveLength(0);
  expect(joinTeamRoster(null,'CHI',snapshot)).toHaveLength(0);
 });
 it('game filter respects season, segment, exact participating team and search',()=>{
  const games=[
   {season_id:'2025-26',season_type:'regular',game_date:'2025-12-01',home_team_abbreviation:'CHI',away_team_abbreviation:'BOS',game_key:'g1'},
   {season_id:'2025-26',season_type:'playoffs',game_date:'2026-05-01',home_team_abbreviation:'CHI',away_team_abbreviation:'NYK',game_key:'g2'},
   {season_id:'2024-25',season_type:'regular',game_date:'2025-01-01',home_team_abbreviation:'CHI',away_team_abbreviation:'BOS',game_key:'g3'}
  ];
  expect(gameType(games[1])).toBe('playoffs');
  expect(selectPublishedGames(games,'2025-26','regular','CHI','g1')).toHaveLength(1);
  expect(selectPublishedGames(games,'2025-26','regular','NYK','')).toHaveLength(0);
 });
 it('historical relocations remain explicitly planned in the unchanged original roadmap',()=>{
  expect(originalFlutterPlan).toHaveLength(6);
  expect(originalFlutterPlan.find(x=>x.area==='Historical names and relocations')?.status).toBe('Planned');
 });
});