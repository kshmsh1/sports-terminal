import {describe,it,expect} from 'vitest';
import {mkdtempSync,mkdirSync,writeFileSync,rmSync,readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const inspect=fileURLToPath(new URL('../scripts/inspect_corpus.mjs',import.meta.url));
function json(root:string,file:string,value:unknown){
 const target=path.join(root,file);mkdirSync(path.dirname(target),{recursive:true});
 writeFileSync(target,JSON.stringify(value));
}
describe('source-release probe itself (synthetic FILES only, not NBA validation)',()=>{
 it('checks source shape and produces release evidence; refuses missing shards',()=>{
  const root=mkdtempSync(path.join(tmpdir(),'arcside-synthetic-contract-'));
  try{
   json(root,'manifest.json',{contract:'sports-terminal-static-nba-website-v5',static_schema_version:5,
    database_fingerprint:{SYNTHETIC_TEST_ONLY:true},season_count:2,compiler_version:3});
   json(root,'seasons.json',[{season_id:'2025-26'},{season_id:'1949-50'}]);
   for(const season of ['1949-50','2025-26'])for(const segment of ['regular','playoffs'])
    json(root,'seasons/'+season+'/'+segment+'.json',{season_id:season,season_type:segment,
     player_season_totals:[{player_id:'SYNTHETIC',points:0,assists:null,games:5}]});
   const out=path.join(root,'report.json');
   const ok=spawnSync(process.execPath,[inspect,'--root',root,'--out',out],{encoding:'utf8'});
   expect(ok.status,ok.stderr).toBe(0);
   const report=JSON.parse(readFileSync(out,'utf8'));
   expect(report.kind).toBe('ARCSIDE_REAL_STATIC_RELEASE_PROBE'); // probe mode; fixture is marked synthetic
   expect(report.manifest.fingerprint.SYNTHETIC_TEST_ONLY).toBe(true);
   expect(report.samples).toHaveLength(4);
   expect(report.samples[0].missing.assists).toBe(1);
   rmSync(path.join(root,'seasons/2025-26/playoffs.json'));
   const bad=spawnSync(process.execPath,[inspect,'--root',root],{encoding:'utf8'});
   expect(bad.status).not.toBe(0);
   expect(bad.stderr).toContain('Required canonical NBA static asset missing');
  }finally{rmSync(root,{recursive:true,force:true});}
 });
});
