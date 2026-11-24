// Read-only inventory of the owner's actual NBA-v5 archive. No scraping or fabricated data.
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const here=path.dirname(fileURLToPath(import.meta.url));
const repo=path.resolve(here,'../../..'),root=path.join(repo,'web/data/nba_static');
const bytes=await readFile(path.join(root,'manifest.json'));
const manifest=JSON.parse(bytes);
if(manifest.contract!=='sports-terminal-static-nba-website-v5'||manifest.static_schema_version!==5||!manifest.database_fingerprint)
 throw Error('Original v5 manifest required; never substitute fixtures');
const seasons=JSON.parse(await readFile(path.join(root,'seasons.json')));
if(!Array.isArray(seasons)||!seasons.length)throw Error('Original season index missing or invalid');
const games=JSON.parse(await readFile(path.join(root,'games/index.json')));
if(!Array.isArray(games))throw Error('Original game index is not an array');
const groups=new Map();
for(const g of games){
 const key=String(g.season_id??'UNKNOWN');
 const seg=String(g.season_type??g.seasonType??g.segment??'UNKNOWN');
 const groupKey=key+'|'+seg;
 if(!groups.has(groupKey))groups.set(groupKey,{season:key,segment:seg,records:0,flaggedBoxScores:0,detailReferences:0,earliest:null,latest:null});
 const v=groups.get(groupKey);v.records++;
 if(g.box_score_available===true)v.flaggedBoxScores++;
 if(typeof g.file==='string'&&g.file)v.detailReferences++;
 const date=String(g.game_date??'').split(/[T ]/)[0];
 if(/^\d{4}-\d{2}-\d{2}$/.test(date)){
  if(!v.earliest||date<v.earliest)v.earliest=date;
  if(!v.latest||date>v.latest)v.latest=date;
 }
}
const lineup=[];
for(const season of seasons){
 const id=season.season_id;
 if(typeof id!=='string'||!/^\d{4}-\d{2}$/.test(id))continue;
 for(const segment of ['regular','playoffs']){
  const file=path.join(root,'lineups',id,segment,'with_without.json');
  try{
   const data=JSON.parse(await readFile(file,'utf8'));
   if(!Array.isArray(data.rows))throw Error('Invalid rows array');
   lineup.push({season:id,segment,status:data.rows.length?'PUBLISHED_ROWS':'EMPTY_FILE',rows:data.rows.length,source:data.source??null});
  }catch(e){
   lineup.push({season:id,segment,status:e.code==='ENOENT'?'NOT_PUBLISHED':'INVALID_OR_UNREADABLE',rows:null,error:e.code==='ENOENT'?null:String(e.message??e)});
  }
 }
}
const grouped=[...groups.values()].sort((a,b)=>a.season.localeCompare(b.season)||a.segment.localeCompare(b.segment));
const result={kind:'ARCSIDE_LOCAL_SOURCE_COVERAGE_V1',createdAt:new Date().toISOString(),
 manifestSha256:createHash('sha256').update(bytes).digest('hex'),latestSeason:manifest.latest_season,
 seasonIndexCount:seasons.length,gameIndexRecords:games.length,
 latestIndexedGameDate:grouped.map(x=>x.latest).filter(Boolean).sort().at(-1)??null,
 gameCoverage:grouped,lineupCoverage:lineup,
 caveat:'Index references and lineup-file presence are inventory only, not verification of every game detail, lineup statistic, or source completeness.'};
const dir=path.resolve(here,'../evidence/coverage');
await mkdir(dir,{recursive:true});
const output=path.join(dir,'local-source-coverage.json');
await writeFile(output,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({manifestSha256:result.manifestSha256,latestSeason:result.latestSeason,
 seasonIndexCount:result.seasonIndexCount,gameIndexRecords:result.gameIndexRecords,latestIndexedGameDate:result.latestIndexedGameDate,
 lineupFilesWithRows:lineup.filter(x=>x.status==='PUBLISHED_ROWS').length,
 lineupFilesNotPublished:lineup.filter(x=>x.status==='NOT_PUBLISHED').length,
 invalidLineupFiles:lineup.filter(x=>x.status==='INVALID_OR_UNREADABLE').length,output},null,2));
if(lineup.some(x=>x.status==='INVALID_OR_UNREADABLE'))process.exitCode=1;
