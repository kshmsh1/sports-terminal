import {describe,expect,it} from 'vitest';
import {dossierMetric,dossierMetricText,dossierName,dossierSegments} from '../src/ProfileTable';
import {advancedMetricCatalog} from '../src/advancedCatalog';
describe('original Flutter player dossier source semantics',()=>{
 const fixture={profile:{canonical_name:'Fixture Player'},
  regular_seasons:[{season_id:'2025-26',games:65,pts:1300,min:2100,points:1300,minutes:2100,
   rebounds:325,fg_pct:0.50,bpm:2.2}],
  playoff_seasons:[{season_id:'2025-26',games:6,points:120}]};
 it('reads the nested original player dossier contract and independent segments',()=>{
  expect(dossierName(fixture)).toBe('Fixture Player');
  expect(dossierSegments(fixture).regular).toHaveLength(1);
  expect(dossierSegments(fixture).playoffs).toHaveLength(1);
  expect(dossierSegments({regular_seasons:null}).regular).toEqual([]);
 });
 it('uses source-backed PPG and MPG totals divided by games, as Dart does',()=>{
  const row=fixture.regular_seasons[0];
  expect(dossierMetricText(row,advancedMetricCatalog.ppg)).toBe('20.0');
  expect(dossierMetricText(row,advancedMetricCatalog.mpg)).toBe('32.3');
 });
 it('formats source percentages exactly as original dossier threshold, including old percentage-valued sources',()=>{
  expect(dossierMetricText({fg_pct:0.5},advancedMetricCatalog.fg_pct)).toBe('50.0%');
  expect(dossierMetricText({fg_pct:50},advancedMetricCatalog.fg_pct)).toBe('50.0%');
  expect(dossierMetricText({fg_pct:1.3},advancedMetricCatalog.fg_pct)).toBe('130.0%');
 });
 it('accepts exact source numeric strings but rejects malformed numbers and empty fields',()=>{
  expect(dossierMetricText({games:'65',pts:'1300'},advancedMetricCatalog.ppg)).toBe('20.0');
  expect(dossierMetricText({fg_pct:'0.51'},advancedMetricCatalog.fg_pct)).toBe('51.0%');
  expect(dossierMetricText({bpm:'-2.25'},advancedMetricCatalog.bpm)).toBe('-2.3');
  expect(dossierMetricText({bpm:'0x10'},advancedMetricCatalog.bpm)).toBe('—');
  expect(dossierMetricText({bpm:'unknown'},advancedMetricCatalog.bpm)).toBe('—');
 });
 it('does not make missing fields into zeros and retains actual zeroes',()=>{
  expect(dossierMetric({},advancedMetricCatalog.bpm)).toBeNull();
  expect(dossierMetricText({},advancedMetricCatalog.bpm)).toBe('—');
  expect(dossierMetricText({bpm:0},advancedMetricCatalog.bpm)).toBe('+0.0');
 });
});