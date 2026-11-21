import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import sirv from 'sirv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import type { IncomingMessage, ServerResponse } from 'node:http';

const cwd = path.dirname(fileURLToPath(import.meta.url));
const repoWeb = path.resolve(cwd, '../../web');
// Materialize the exact original Flutter dated 2026–27 salary seed as a
// separate read-only asset. No local private workbooks or warehouse mutation.
const originalFlutterContractSeed = () => {
  const source = readFileSync(path.resolve(cwd,'../../lib/services/nba_trade_contract_seed.dart'),'utf8');
  const match = source.match(/const nbaTradeContractSeed202627\s*=\s*'''([\s\S]*?)''';/);
  if (!match) throw Error('Missing original Flutter 2026–27 salary seed; never substitute mock contracts.');
  const seen = new Set<string>();
  const records: {id:string;player:string;team:string;salaries:Record<string,number>;
    guaranteed:number|null;sourceStatus:string;sourceLabel:string}[] = [];
  for (const line of match[1].split(/\r?\n/)) {
    const parts = line.split('\t');
    if (parts.length<4) continue;
    const player=parts[0].trim(),team=parts[1].trim().toUpperCase();
    const salary=Number(parts[2]),rawGuaranteed=Number(parts[3]);
    if(!player||!team||!Number.isFinite(salary)||salary<=0)continue;
    const playerKey=player.toLowerCase();
    if(seen.has(playerKey))continue;
    seen.add(playerKey);
    const slug=playerKey.replace(/[^a-z0-9]+/g,'-').replace(/^-+|-+$/g,'');
    records.push({id:team+':'+slug,player,team,salaries:{'2026-27':salary},
      guaranteed:Number.isFinite(rawGuaranteed)&&rawGuaranteed>0?rawGuaranteed:null,
      sourceStatus:'uploaded',sourceLabel:'User-supplied Sports Reference salary export (2026-09-11)'});
  }
  return JSON.stringify({kind:'ARCSIDE_ORIGINAL_FLUTTER_2026_27_CONTRACT_SEED_V1',
    asOf:'2026-09-11',sourceNote:'Duplicate source rows collapsed by normalized player name.',
    dartSeedSha256:createHash('sha256').update(source).digest('hex'),records});
};
// Export the original team financial snapshot exactly from the Dart reference,
// never a second hand-maintained set of NBA cap values.
const originalTeamFinancialSeed=()=>{
 const source=readFileSync(path.resolve(cwd,'../../lib/services/nba_team_financial_reference_2026.dart'),'utf8');
 const rows=[...source.matchAll(/'([A-Z]{3})':\s*NbaTeamFinancialSnapshot\(([^\n]+)\)/g)].map((match)=>{
  const team=match[1],body=match[2];
  const numeric=(key:string)=>{
   const hit=body.match(new RegExp('\\b'+key+':(-?\\d+(?:\\.\\d+)?)'));
   return hit?Number(hit[1]):null;
  };
  const literal=(key:string)=>body.match(new RegExp('\\b'+key+':\\x27([^\\x27]+)\\x27'))?.[1]??null;
  const exceptionsText=body.match(/availableExceptions:\{([^}]*)\}/)?.[1]??'';
  const availableExceptions=Object.fromEntries([...exceptionsText.matchAll(/'([^']+)':(-?\d+(?:\.\d+)?)/g)]
   .map(x=>[x[1],Number(x[2])]));
  return {team,standardRoster:numeric('standardRoster'),twoWayRoster:numeric('twoWayRoster'),
   capSpace:numeric('capSpace'),taxSpace:numeric('taxSpace'),firstApronSpace:numeric('firstApronSpace'),
   secondApronSpace:numeric('secondApronSpace'),hardCap:literal('hardCap'),
   availableExceptions,largestTpe:numeric('largestTpe'),largestTpeExpires:literal('largestTpeExpires')};
 });
 if(rows.length!==30||rows.some(row=>row.capSpace===null||row.standardRoster===null))
  throw Error('Original 2026–27 team financial data parsing failed: expected 30 verified teams.');
 return JSON.stringify({kind:'ARCSIDE_ORIGINAL_FLUTTER_TEAM_FINANCIALS_2026_27_V1',
  sourceAsOf:'2026-10-05',source:'User-supplied 2026–27 NBA Team Summary screenshots',
  dartSourceSha256:createHash('sha256').update(source).digest('hex'),teams:rows});
};
// Single source of truth: extract the 30 original Dart team cap ledgers.
// Never reinterpret a sum of salaries as the team's full cap ledger.
const originalTeamCapLedger=()=>{
 const source=readFileSync(path.resolve(cwd,'../../lib/services/nba_team_cap_reference_2026.dart'),'utf8');
 const records=[...source.matchAll(/'([A-Z]{3})':\s*NbaTeamCapLedgerEntry\(([^)]*)\)/g)].map(match=>{
  const body=match[2],field=(key:string)=>{
   const found=body.match(new RegExp('(?:^|,)\\s*'+key+':\\s*(-?\\d+(?:\\.\\d+)?)'));
   return found?Number(found[1]):null;
  };
  return {team:match[1],totalCap:field('totalCap'),active:field('active'),dead:field('dead'),
   retained:field('retained')??0,capHolds:field('capHolds')??0,
   incompleteRosterCharges:field('incompleteRosterCharges')??0};
 });
 const capBlock=source.match(/static const Map<String, String> hardCap = \{([\s\S]*?)\};/)?.[1];
 if(!capBlock)throw Error('Original hard-cap map is missing.');
 const caps=new Map([...capBlock.matchAll(/'([A-Z]{3})':\s*'(first|second)'/g)].map(x=>[x[1],x[2]]));
 if(records.length!==30||new Set(records.map(x=>x.team)).size!==30||
    records.some(x=>x.totalCap===null||x.active===null||x.dead===null))
  throw Error('Original Dart team ledger parse failed: require exactly 30 complete unique teams.');
 const teams=records.map(x=>({...x,hardCap:caps.get(x.team)??null}));
 return JSON.stringify({kind:'ARCSIDE_ORIGINAL_DART_TEAM_CAP_LEDGER_2026_27_V1',
  operatingSeason:'2026-27',source:'Original Flutter Spotrac-transcribed static cap ledger',
  sourceNote:'Dated snapshot only; use only with explicit source selection; not a live cap feed.',
  dartSourceSha256:createHash('sha256').update(source).digest('hex'),teams});
};
const assets = (server: {middlewares: {use: (prefix: string, middleware: any) => void}}) => {
  // Serve the SAME local corpus and ORIGINAL Labs, not demo copies or remote API data.
  server.middlewares.use('/data/nba_static', sirv(path.join(repoWeb, 'data/nba_static'), { dev: true, etag: true }));
  server.middlewares.use('/labs', sirv(path.join(repoWeb, 'labs'), { dev: true, etag: true, single: false }));
  server.middlewares.use('/data/phase3/2026-27-team-financials.json',(
   req:IncomingMessage,res:ServerResponse,next:()=>void)=>{
    if(req.method!=='GET'&&req.method!=='HEAD')return next();
    res.setHeader('content-type','application/json; charset=utf-8');
    res.setHeader('cache-control','no-store');
    res.end(req.method==='HEAD'?'':originalTeamFinancialSeed());
  });
  server.middlewares.use('/data/phase3/2026-27-team-cap-ledger.json',(
   req:IncomingMessage,res:ServerResponse,next:()=>void)=>{
    if(req.method!=='GET'&&req.method!=='HEAD')return next();
    res.setHeader('content-type','application/json; charset=utf-8');
    res.setHeader('cache-control','no-store');
    res.end(req.method==='HEAD'?'':originalTeamCapLedger());
  });
  server.middlewares.use('/data/phase3/2026-27-contracts.json',(
    req:IncomingMessage,res:ServerResponse,next:()=>void)=>{
    if(req.method!=='GET'&&req.method!=='HEAD')return next();
    const json=originalFlutterContractSeed();
    res.setHeader('content-type','application/json; charset=utf-8');
    res.setHeader('cache-control','no-store');
    res.end(req.method==='HEAD'?'':json);
  });
};
export default defineConfig({
  plugins: [react(),
    {name:'arcside-2026-27-dated-contract-seed',generateBundle(){
      this.emitFile({type:'asset',fileName:'data/phase3/2026-27-team-financials.json',
        source:originalTeamFinancialSeed()});
      this.emitFile({type:'asset',fileName:'data/phase3/2026-27-team-cap-ledger.json',
        source:originalTeamCapLedger()});
      this.emitFile({type:'asset',fileName:'data/phase3/2026-27-contracts.json',
        source:originalFlutterContractSeed()});
    }},
    { name: 'arcside-original-static-resources', configureServer: assets, configurePreviewServer: assets }
  ],
  publicDir: false,
  server: { host: '127.0.0.1', port: 5173, strictPort: true },
  preview: { host: '127.0.0.1', port: 4173, strictPort: true },
  build: { outDir: 'dist', emptyOutDir: true },
  test: { environment: 'node', include: process.env.ARCSIDE_RUN_PARITY === '1' ? ['tests/parity.test.ts'] : ['tests/**/*.test.ts'],
    exclude: process.env.ARCSIDE_RUN_PARITY === '1' ? [] : ['tests/parity.test.ts'] }
});
