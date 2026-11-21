import {describe,it,expect} from 'vitest';
import {originalCapContext} from '../src/TradeMachinePilot';
import type {TeamCapLedgerSnapshot} from '../src/data';

const ledger:TeamCapLedgerSnapshot={
 kind:'ARCSIDE_ORIGINAL_DART_TEAM_CAP_LEDGER_2026_27_V1',operatingSeason:'2026-27',
 source:'test-only fixture',sourceNote:'synthetic',dartSourceSha256:'test',
 teams:[
  {team:'BOS',totalCap:207991480,active:199617438,dead:0,retained:1972866,
   capHolds:0,incompleteRosterCharges:0,hardCap:'first'},
  {team:'GSW',totalCap:254337411,active:224265316,dead:0,retained:0,
   capHolds:0,incompleteRosterCharges:0,hardCap:'second'}
 ]};
describe('explicitly selected original Flutter dated cap snapshot',()=>{
 it('applies original first-apron hard cap only to source-matched payroll',()=>{
  const context=originalCapContext('BOS',207991480,ledger,true);
  expect(context.teamSalary).toBe(207991480);
  expect(context.hardCappedAt).toBe(context.firstApron);
 });
 it('applies original second-apron hard cap to another published team',()=>{
  const context=originalCapContext('GSW',254337411,ledger,true);
  expect(context.hardCappedAt).toBe(context.secondApron);
 });
 it('never presents illustrative or user-edited payroll as original cap ledger',()=>{
  expect(originalCapContext('BOS',140000000,ledger,true).hardCappedAt).toBeUndefined();
  expect(originalCapContext('BOS',207991480,ledger,false).hardCappedAt).toBeUndefined();
  expect(originalCapContext('ZZZ',140000000,ledger,true).hardCappedAt).toBeUndefined();
  expect(originalCapContext('BOS',207991480,null,true).hardCappedAt).toBeUndefined();
 });
});
