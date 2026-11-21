import {describe,expect,it} from 'vitest';
import {parseTradeAmount} from '../src/TradeMachinePilot';

describe('hypothetical trade input amounts',()=>{
 it('accepts valid nonnegative integer or cent-precise amounts',()=>{
  expect(parseTradeAmount('140000000')).toBe(140000000);
  expect(parseTradeAmount(' 0 ')).toBe(0);
  expect(parseTradeAmount('10.25')).toBe(10.25);
 });
 it('rejects empty, hexadecimal, scientific notation, negative, nonfinite or currency strings',()=>{
  for(const invalid of ['', '   ', '0x10', '1e6', '-4', 'Infinity',
   'NaN', '$5000', '1,000', '1.234'])expect(parseTradeAmount(invalid)).toBeNull();
 });
 it('rejects dollar amounts too large for cent-precision safe integers',()=>{
  expect(parseTradeAmount('999999999999999')).toBeNull();
 });
});
