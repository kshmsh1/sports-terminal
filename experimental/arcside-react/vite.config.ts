import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import sirv from 'sirv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

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
const assets = (server: {middlewares: {use: (prefix: string, middleware: any) => void}}) => {
  // Serve the SAME local corpus and ORIGINAL Labs, not demo copies or remote API data.
  server.middlewares.use('/data/nba_static', sirv(path.join(repoWeb, 'data/nba_static'), { dev: true, etag: true }));
  server.middlewares.use('/labs', sirv(path.join(repoWeb, 'labs'), { dev: true, etag: true, single: false }));
  server.middlewares.use('/data/phase3/2026-27-contracts.json',(req,res,next)=>{
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
