// Phase 3 local, read-only proof: inspects ACTUAL publisher output; no fallback fixture.
// Usage from repo root: node experimental/arcside-react/scripts/inspect_corpus.mjs
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const here=path.dirname(fileURLToPath(import.meta.url));
const opts=process.argv.slice(2);
function option(name,fallback){const i=opts.indexOf(name);return i<0?fallback:opts[i+1]??fallback;}
const root=path.resolve(option('--root',path.join(here,'../../../web/data/nba_static')));
const out=option('--out','');
const requested=option('--seasons','').split(',').map(s=>s.trim()).filter(Boolean);
const issues=[];
const sha256=bytes=>createHash('sha256').update(bytes).digest('hex');
async function readJson(relative){
 const location=path.join(root,relative);
 let bytes;
 try{bytes=await readFile(location);}catch(e){throw Error('Required canonical NBA static asset missing: '+location+' ('+e.code+')');}
 try{return {data:JSON.parse(bytes.toString('utf8')),sha256:sha256(bytes),bytes:bytes.length};}
 catch{throw Error('Invalid JSON at canonical asset: '+location);}
}
try{
 const manifest=await readJson('manifest.json');
 const meta=manifest.data;
 if(meta.contract!=='sports-terminal-static-nba-website-v5'||meta.static_schema_version!==5||
  !meta.database_fingerprint)throw Error('Unsupported or non-canonical NBA v5 manifest');
 const catalog=await readJson('seasons.json');
 if(!Array.isArray(catalog.data)||!catalog.data.length)throw Error('Empty or invalid canonical seasons catalog');
 const seasons=catalog.data.map(s=>s.season_id);
 if(seasons.some(s=>typeof s!=='string'||!/^\\d{4}-\\d{2}$/.test(s)))throw Error('Malformed catalog season ID');
 if(new Set(seasons).size!==seasons.length)issues.push('Duplicate season identifiers in catalog');
 if(meta.season_count!==seasons.length)issues.push('Manifest/catalog season_count mismatch');
 const selected=requested.length?requested:[seasons[0],seasons[Math.floor((seasons.length-1)/2)],seasons.at(-1)];
 if(selected.some(s=>!seasons.includes(s)))throw Error('Requested season not in canonical catalog: '+selected.filter(s=>!seasons.includes(s)).join(', '));
 const samples=[];
 for(const season of new Set(selected)){
  for(const segment of ['regular','playoffs']){
   const shard=await readJson('seasons/'+season+'/'+segment+'.json');
   const data=shard.data;
   if(data.season_id!==season||data.season_type!==segment||!Array.isArray(data.player_season_totals)){
    issues.push('Invalid season/segment contract: '+season+'/'+segment);continue;
   }
   const records=data.player_season_totals;
   const total=records.length;
   const keys=new Set(records.flatMap(r=>r&&typeof r==='object'&&!Array.isArray(r)?Object.keys(r):[]));
   const missing=key=>records.filter(r=>r?.[key]===null||r?.[key]===undefined).length;
   const distinct=new Set(records.map(r=>String(r?.player_id??'')));
   const multiTeam=records.filter(r=>Array.isArray(r?.team_stints)&&r.team_stints.length>=2).length;
   const incomplete=records.filter(r=>!r||typeof r!=='object'||!r.player_id).length;
   if(incomplete)issues.push(season+'/'+segment+' '+incomplete+' records lack player_id');
   samples.push({season,segment,sourceSeason:data.source_season_id??null,sha256:shard.sha256,
    jsonBytes:shard.bytes,rows:total,distinctPlayerIds:distinct.size,recordedMultiTeamRows:multiTeam,
    missing:{points:missing('points'),assists:missing('assists'),rebounds:missing('rebounds'),
     trueShooting:missing('true_shooting_percentage'),bpm:missing('avg_bpm')},
    presentMetricFields:['points','assists','rebounds','avg_bpm','true_shooting_percentage','fg3_pct','ts_pct'].filter(k=>keys.has(k))});
  }
 }
 const report={kind:'ARCSIDE_REAL_STATIC_RELEASE_PROBE',createdAt:new Date().toISOString(),root,
  manifest:{sha256:manifest.sha256,contract:meta.contract,schema:meta.static_schema_version,
   fingerprint:meta.database_fingerprint,seasonCount:meta.season_count,compilerVersion:meta.compiler_version,
   entityDossiers:meta.entity_dossiers},catalogSha256:catalog.sha256,inspectedSeasons:[...new Set(selected)],
  samples,issues,claim:'Actual local source-shard inspection only; NOT a Flutter/React parity or performance benchmark'};
 if(out){await mkdir(path.dirname(path.resolve(out)),{recursive:true});await writeFile(out,JSON.stringify(report,null,2)+'\\n');}
 console.log(JSON.stringify(report,null,2));
 if(issues.length)process.exitCode=1;
}catch(err){console.error('Real corpus inspection FAILED:',err.message);process.exitCode=1;}
