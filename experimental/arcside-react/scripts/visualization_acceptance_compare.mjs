// Phase 3 Visualization original Dart source-vs-React source acceptance.
// Requires fresh Flutter exporter from the SAME canonical v5 NBA shard set.
// Exact ordered top-N IDs and original metric values are independently compared.
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createServer} from 'vite';
const here=path.dirname(fileURLToPath(import.meta.url));
const app=path.resolve(here,'..'),repo=path.resolve(app,'../..');
const source=path.resolve(process.env.ARCSIDE_NBA_CORPUS??path.join(repo,'web/data/nba_static'));
const outDir=path.join(app,'evidence/visualization');
const sha=b=>createHash('sha256').update(b).digest('hex');
const report={kind:'ARCSIDE_VISUALIZATION_REAL_DART_REACT_ACCEPTANCE_V1',
 createdAt:new Date().toISOString(),status:'FAIL',
 source:'ACTUAL_LOCAL_V5_CORPUS',manifestSha256:null,comparisons:0,mismatches:0,
 cases:[],samples:[],errors:[],
 caveat:'Dart original engine vs React original-corpus source projections; not a visual rendering or human UX equivalence claim'};
const equal=(a,b)=>{
 if(a===null||b===null)return a===b;
 if(typeof a==='number'&&typeof b==='number'&&Number.isFinite(a)&&Number.isFinite(b))
  return Math.abs(a-b)<=1e-7*Math.max(1,Math.abs(a),Math.abs(b));
 return a===b;
};
const compare=(expected,actual,detail)=>{
 report.comparisons++;
 if(!equal(expected,actual)){
  report.mismatches++;
  if(report.samples.length<90)report.samples.push({...detail,expected,actual});
 }
};
let vite=null;
try {
 await mkdir(outDir,{recursive:true});
 const manifestBytes=await readFile(path.join(source,'manifest.json'));
 const manifest=JSON.parse(manifestBytes.toString());
 report.manifestSha256=sha(manifestBytes);
 if(manifest.contract!=='sports-terminal-static-nba-website-v5'||
  manifest.static_schema_version!==5||!manifest.database_fingerprint)
  throw Error('Only original canonical published NBA v5 input accepted');
 const dart=JSON.parse(await readFile(path.join(outDir,'dart-reference.json'),'utf8'));
 if(dart.kind!=='ARCSIDE_FLUTTER_VISUALIZATION_REFERENCE_V1'||
  dart.source!=='ACTUAL_LOCAL_V5_CORPUS'||
  JSON.stringify(dart.manifestFingerprint)!==JSON.stringify(manifest.database_fingerprint))
  throw Error('Flutter source reference stale, missing or mismatched to original corpus');
 vite=await createServer({root:app,server:{middlewareMode:true},appType:'custom',
  logLevel:'error',configFile:false});
 const [{buildRows},{selectVisualizationRows,linearStats}]=await Promise.all([
  vite.ssrLoadModule('/src/engine.ts'),
  vite.ssrLoadModule('/src/visualization_math.ts')]);
 const cache=new Map();
 let nonempty=0;
 for(const item of dart.cases){
  const {season,segment,basis,variant,x,y,minGames,topN}=item;
  const key=season+'/'+segment;
  let original=cache.get(key);
  if(!original){
   const p=path.join(source,'seasons',season,segment+'.json');
   original=JSON.parse(await readFile(p,'utf8'));
   if(original.season_id!==season||original.season_type!==segment)
    throw Error('Mismatched source shard '+p);
   cache.set(key,original);
  }
  const rows=buildRows(original,basis);
  const selection=selectVisualizationRows(rows,{
   x,y,basis,kind:'scatter',minGames,population:topN,filter:''});
  const prior=report.mismatches;
  const prefix={season,segment,basis,variant};
  compare(item.sourceRowCount,rows.length,{...prefix,field:'sourceRowCount'});
  compare(item.matchingCount,selection.matching.length,{...prefix,field:'matchingCount'});
  compare(item.eligibleCount,selection.eligible.length,{...prefix,field:'eligibleCount'});
  compare(item.plotted.length,selection.plotted.length,{...prefix,field:'populationCount'});
  for(let i=0;i<Math.max(item.plotted.length,selection.plotted.length);i++){
   const expected=item.plotted[i],actual=selection.plotted[i];
   if(!expected||!actual){compare(expected?.id??null,actual?.id??null,
    {...prefix,i,field:'missingPlottedRow'});continue;}
   for(const field of ['id','player','team'])
    compare(expected[field],field==='id'?actual.id:field==='player'?actual.player:actual.team,
     {...prefix,i,field});
   compare(expected.x,actual.values[x],{...prefix,i,field:'metricX'});
   compare(expected.y,actual.values[y],{...prefix,i,field:'metricY'});
  }
  const computed=linearStats(selection.plotted,x,y);
  const gold=item.regression;
  if(gold.count>=2){
   for(const field of ['count','slope','intercept','r','rSquared'])
    compare(gold[field],computed?.[field]??null,{...prefix,field:'regression.'+field});
  }
  if(item.plotted.length)nonempty++;
  report.cases.push({...prefix,sourceRows:rows.length,
   plotted:item.plotted.length,mismatches:report.mismatches-prior});
 }
 report.nonemptyCases=nonempty;
 if(report.cases.length<30||nonempty<12)throw Error('Insufficient real Flutter plot cases');
 report.status=report.mismatches===0?'PASS':'FAIL';
}catch(error){
 report.errors.push(error instanceof Error?error.stack??error.message:String(error));
 report.status='FAIL';
}finally{
 if(vite)await vite.close();
 await mkdir(outDir,{recursive:true});
 await writeFile(path.join(outDir,'visualization-source-parity.json'),
  JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({status:report.status,comparisons:report.comparisons,
  mismatches:report.mismatches,cases:report.cases.length,nonemptyCases:report.nonemptyCases,
  examples:report.samples.slice(0,12),errors:report.errors.slice(0,2),
  output:path.join(outDir,'visualization-source-parity.json')},null,2));
 if(report.status!=='PASS')process.exitCode=1;
}
