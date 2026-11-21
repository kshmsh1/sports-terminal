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
 const salarySource=readFileSync(path.resolve(cwd,'../../lib/services/nba_team_salary_position_2026.dart'),'utf8');
 const salaryRows=[...salarySource.matchAll(/'([A-Z]{3})':\s*NbaTeamSalaryPosition\(([^)]*)\)/g)];
 const salaryEntries=new Map(salaryRows.map(row=>{
  const field=(key:string)=>{
   const found=row[2].match(new RegExp('(?:^|,)\\s*'+key+':\\s*(-?\\d+(?:\\.\\d+)?)'));
   return found?Number(found[1]):null;
  };
  return [row[1],{salaryPosition:field('totalSalary'),guaranteedSalary:field('guaranteed'),
   salaryPositionDeadMoney:field('deadMoney')??0}];
 }));
 if(salaryRows.length!==30||salaryEntries.size!==30||
   [...salaryEntries.values()].some(x=>x.salaryPosition===null))
  throw Error('Missing original Flutter 30-team salary positions.');
 const capBlock=source.match(/static const Map<String, String> hardCap = \{([\s\S]*?)\};/)?.[1];
 if(!capBlock)throw Error('Original hard-cap map is missing.');
 const caps=new Map([...capBlock.matchAll(/'([A-Z]{3})':\s*'(first|second)'/g)].map(x=>[x[1],x[2]]));
 if(records.length!==30||new Set(records.map(x=>x.team)).size!==30||
    records.some(x=>x.totalCap===null||x.active===null||x.dead===null))
  throw Error('Original Dart team ledger parse failed: require exactly 30 complete unique teams.');
 const teams=records.map(x=>{const salary=salaryEntries.get(x.team);
  if(!salary)throw Error('Original Flutter salary position missing: '+x.team);
  return {...x,...salary,hardCap:caps.get(x.team)??null};
 });
 return JSON.stringify({kind:'ARCSIDE_ORIGINAL_DART_TEAM_CAP_LEDGER_2026_27_V1',
  operatingSeason:'2026-27',source:'Original Flutter Spotrac-transcribed static cap ledger',
  sourceNote:'Dated snapshot only; use only with explicit source selection; not a live cap feed.',
  dartSourceSha256:createHash('sha256').update(source).digest('hex'),
  dartSalarySourceSha256:createHash('sha256').update(salarySource).digest('hex'),teams});
};
// Read-only first- and second-round draft interests + TPEs from the Dart
// canonical repository. Conditional rights remain CONDITIONAL, not owned picks.
const originalDraftAndExceptions=()=>{
 const firstSource=readFileSync(path.resolve(cwd,'../../lib/services/nba_future_draft_asset_repository.dart'),'utf8');
 const secondSource=readFileSync(path.resolve(cwd,'../../lib/services/nba_second_round_draft_seed.dart'),'utf8');
 const tpeSource=readFileSync(path.resolve(cwd,'../../lib/services/nba_trade_exception_reference_2026.dart'),'utf8');
 const stringField=(line:string,name:string)=>line.match(new RegExp('\\b'+name+":'((?:\\\\'|[^'])*)'"))?.[1]?.replace(/\\'/g,"'")??null;
 const numberField=(line:string,name:string)=>{const match=line.match(new RegExp('\\b'+name+':(\\d+)'));return match?Number(match[1]):null};
 const first=firstSource.split('\n').filter(line=>line.includes('NbaFutureDraftAsset(id:')).map(line=>{
  const id=stringField(line,'id'),team=stringField(line,'team'),year=numberField(line,'year'),round=numberField(line,'round');
  if(!id||!team||!year||round!==1)throw Error('Malformed original Dart first-round draft asset: '+line.slice(0,120));
  return {id,team,year,round,label:stringField(line,'label')??id,
   description:stringField(line,'description')??'',
   tradable:!line.includes('tradable:false'),frozen:line.includes('frozen:true'),
   conditional:line.includes('conditional:true'),swapRight:line.includes('swapRight:true'),
   stepienSafe:line.includes('stepienSafe:true'),protection:stringField(line,'protection'),
   source:'Original Flutter RealGM future-draft seed 2026-09-11'};
 });
 if(first.length<180||new Set(first.map(x=>x.id)).size!==first.length)
  throw Error('Original Dart first-round interests could not be parsed completely.');
 const secondText=secondSource.match(/const nbaSecondRoundSeed2027To2033\s*=\s*r?'''([\s\S]*?)''';/)?.[1];
 if(!secondText)throw Error('Original second-round seed missing');
 let sequence=0;
 const second=secondText.split('\n').flatMap(line=>{
  const [team,yearText,...payload]=line.split('|');const year=Number(yearText);
  if(!/^[A-Z]{3}$/.test(team??'')||!Number.isInteger(year))return [];
  return payload.join('|').split(';').map(raw=>raw.trim()).filter(Boolean).map(text=>{
   sequence++;
   const outgoing=text.startsWith('OUT:');
   const conditional=text.startsWith('COND:')||text.startsWith('SWAP:')||
    text.includes(' if ')||text.includes('favorable')||text.includes('allocation');
   const swap=text.startsWith('SWAP:')||text.toLowerCase().includes('swap');
   const clean=text.replace(/^(OUT|COND|SWAP):\s*/,'');
   const slug=clean.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-+|-+$/g,'');
   return {id:team+'-'+year+'-2-'+sequence+'_'+slug,team,year,round:2,
    label:year+' 2nd · '+clean,description:clean,tradable:!outgoing,frozen:false,
    conditional,swapRight:swap,stepienSafe:true,protection:null,
    source:'Original Flutter RealGM 2nd-round seed 2026-09-11'};
  });
 });
 if(second.length<200||new Set(second.map(x=>x.id)).size!==second.length)
  throw Error('Original Dart second-round interests could not be parsed completely.');
 const tpeText=tpeSource.match(/const _tpeSeed\s*=\s*r?'''([\s\S]*?)''';/)?.[1];
 if(!tpeText)throw Error('Original Dart TPE seed missing');
 const exceptions=tpeText.split('\n').filter(x=>x.trim()).map(line=>{
  const fields=line.split('|');
  if(fields.length!==8||!Number.isFinite(Number(fields[5])))
   throw Error('Malformed original TPE row: '+line.slice(0,100));
  return {id:fields[0]+'-'+fields[1]+'-'+fields[2].slice(0,4),
   team:fields[0],expires:fields[2],sourceTransaction:fields[3],
   original:Number(fields[4]),available:Number(fields[5]),note:fields[6]||null,
   unusableAboveSecondApron:fields[7]==='1'};
 });
 if(exceptions.length<30)throw Error('Original Flutter TPE ledger is unexpectedly incomplete.');
 return JSON.stringify({
  kind:'ARCSIDE_ORIGINAL_FLUTTER_DRAFT_TPE_2026_27_V1',sourceAsOf:'2026-09-11',
  firstSourceSha256:createHash('sha256').update(firstSource).digest('hex'),
  secondSourceSha256:createHash('sha256').update(secondSource).digest('hex'),
  tpeSourceSha256:createHash('sha256').update(tpeSource).digest('hex'),
  draftAssets:[...first,...second],exceptions,
  caveat:'Dated Flutter source interests, NOT guaranteed pick ownership or current tradeability. Protections, restrictions and exception eligibility require verification.'});
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
  server.middlewares.use('/data/phase3/2026-27-draft-exceptions.json',(
   req:IncomingMessage,res:ServerResponse,next:()=>void)=>{
    if(req.method!=='GET'&&req.method!=='HEAD')return next();
    res.setHeader('content-type','application/json; charset=utf-8');
    res.setHeader('cache-control','no-store');
    res.end(req.method==='HEAD'?'':originalDraftAndExceptions());
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
      this.emitFile({type:'asset',fileName:'data/phase3/2026-27-draft-exceptions.json',
        source:originalDraftAndExceptions()});
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
