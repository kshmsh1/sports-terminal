// Executable real-data Advanced Stats acceptance: original Flutter/Dart
// catalog resolver vs independently ported React metric + display semantics.
// Zero comparison errors is required; zero observed rows is NOT a pass.
// Must run after regenerating the Dart file from the same canonical manifest.
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createServer} from 'vite';

const here=path.dirname(fileURLToPath(import.meta.url));
const app=path.resolve(here,'..'),repo=path.resolve(app,'../..');
const source=path.resolve(process.env.ARCSIDE_NBA_CORPUS??path.join(repo,'web/data/nba_static'));
const outDir=path.join(app,'evidence/advanced');
const refPath=path.join(outDir,'dart-reference.json');
const sha=b=>createHash('sha256').update(b).digest('hex');
await mkdir(outDir,{recursive:true});
const report={kind:'ARCSIDE_ADVANCED_STATS_REAL_DART_REACT_ACCEPTANCE_V1',createdAt:new Date().toISOString(),
 status:'FAIL',source:'ACTUAL_LOCAL_V5_CORPUS',manifestSha256:null,
 reference:refPath,cases:[],comparisons:0,mismatches:0,missingCoverage:0,
 numericMismatches:0,catalogMismatches:0,filterMismatches:0,sortMismatches:0,
 samples:[],errors:[],metricPresence:{},sampledCatalogMetricCoverage:null,caveat:'Compares Dart catalog resolver and React source-backed computations; does not observe Flutter runtime widgets, keyboard/visual UX, or human task performance'};
const mismatch=(type,detail)=>{
 report.mismatches++;report[type]=(report[type]??0)+1;
 if(report.samples.length<100)report.samples.push(detail);
};
const numericEqual=(a,b)=>{
 if(a===null||b===null)return a===b;
 return typeof a==='number'&&typeof b==='number'&&Number.isFinite(a)&&Number.isFinite(b)&&
  Math.abs(a-b)<=1e-7*Math.max(1,Math.abs(a),Math.abs(b));
};
let vite;
try{
 const manifestBytes=await readFile(path.join(source,'manifest.json'));
 const manifest=JSON.parse(manifestBytes.toString());
 if(manifest.contract!=='sports-terminal-static-nba-website-v5'||manifest.static_schema_version!==5||
    !manifest.database_fingerprint)throw Error('No authentic original NBA static v5 manifest');
 report.manifestSha256=sha(manifestBytes);
 const dart=JSON.parse(await readFile(refPath,'utf8'));
 if(dart.kind!=='ARCSIDE_FLUTTER_ADVANCED_STATS_REFERENCE'||dart.source!=='ACTUAL_LOCAL_V5_CORPUS'||
    JSON.stringify(dart.manifestFingerprint)!==JSON.stringify(manifest.database_fingerprint))
  throw Error('Dart reference is absent, stale or not tied to same original manifest. Regenerate via Flutter test first.');
 vite=await createServer({root:app,server:{middlewareMode:true},appType:'custom',
  logLevel:'error',configFile:false});
 const [{advancedMetricCatalog,advancedGroups,advancedChildren},
        {metricValue,advancedText,advancedLabel},{buildRows}]=await Promise.all([
  vite.ssrLoadModule('/src/advancedCatalog.ts'),
  vite.ssrLoadModule('/src/AdvancedStatsTable.tsx'),
  vite.ssrLoadModule('/src/engine.ts')
 ]);
 // Verifies metadata from the compiled Dart catalog rather than an independently
 // hand-authored list that could accidentally agree with React-only definitions.
 const dartByKey=new Map(dart.metrics.map(m=>[m.key,m]));
 for(const m of dart.metrics){
  const cand=advancedMetricCatalog[m.key];
  if(!cand){mismatch('catalogMismatches',{reason:'missing metric',key:m.key});continue}
  for(const [k,expected,actual] of [
   ['engine',m.engine,cand.engine],['format',m.format,cand.format],
   ['decimals',m.decimals,cand.decimals],
   ['raw',m.rawAliases,cand.raw],['children',m.children,cand.children]
  ]){
   if(JSON.stringify(expected)!==JSON.stringify(actual))
    mismatch('catalogMismatches',{reason:'metric metadata',key:m.key,property:k,expected,actual});
   report.comparisons++;
  }
 }
 for(const k of Object.keys(advancedMetricCatalog)){
  if(!dartByKey.has(k)&&!['bio_college','bio_country'].includes(k))
   mismatch('catalogMismatches',{reason:'React metric not in Dart catalog',key:k});
 }
 const derivedGroups=new Map([
  ['Defensive / Hustle','defense_hustle'],['Hustle Breakdown','hustle_detail'],
  ['Playmaking / Possession','playmaking'],['Rebounding','rebounding'],
  ['Impact','impact'],['Aggregate Metrics','aggregate'],['Movement','movement'],
  ['Clutch','clutch'],['Shot Profile','shot_profile'],['Play Type','play_type'],
  ['Gravity / Creation','gravity_creation'],['Physical Profile','physical'],
  ['Fouls / Discipline','discipline'],['Availability / Injury','availability']
 ]);
 for(const [name,id] of derivedGroups){
  const group=advancedGroups.find(g=>g.name===name),original=dart.families.find(g=>g.id===id);
  if(!group||!original||JSON.stringify(group.keys.filter(k=>!['bio_college','bio_country'].includes(k)))!==JSON.stringify(original.metrics)){
   mismatch('catalogMismatches',{reason:'Flutter family keys',name,expected:original?.metrics,actual:group?.keys});
  }
  if(group&&original)for(const [key,children] of Object.entries(original.expansionOverrides??{})){
   if(JSON.stringify(advancedChildren(name,key))!==JSON.stringify(children))
    mismatch('catalogMismatches',{reason:'child expansion overrides',name,key,expected:children,actual:advancedChildren(name,key)});
  }
  report.comparisons++;
 }
 if(advancedGroups.length!==18)mismatch('catalogMismatches',{reason:'expected 18 Flutter page groups',count:advancedGroups.length});
 // Cover all rate bases and both regular and playoff segments across multiple eras.
 const bases=['perGame','per36','per48','per75','per100','totals'];
 let nonEmptyCases=0,nonEmptySeasons=new Set();
 const sortIds=(arr,key,desc)=>{
  const list=[...arr];list.sort((a,b)=>{
   const av=a.metrics[key]??null,bv=b.metrics[key]??null;
   if(av===null&&bv===null)return a.player.localeCompare(b.player);
   if(av===null)return 1;if(bv===null)return -1;
   return (desc?bv-av:av-bv)||a.player.localeCompare(b.player);
  });return list.map(r=>r.id);
 };
 for(const item of dart.cases){
  const {season,segment}=item;
  const shardPath=path.join(source,'seasons',season,segment+'.json');
  const original=JSON.parse(await readFile(shardPath,'utf8'));
  if(original.season_id!==season||original.season_type!==segment)throw Error('Mismatched shard '+shardPath);
  const byBasis=new Map(item.bases.map(b=>[b.basis,b]));
  for(const basis of bases){
   const d=byBasis.get(basis);
   if(!d)throw Error('Dart missing basis '+season+'/'+segment+'/'+basis);
   const rows=buildRows(original,basis),index=new Map(rows.map(r=>[r.id,r]));
   const info={season,segment,basis,sourceRows:rows.length,samples:d.samples.length,metricsCompared:0,mismatches:0,
    exactSourceShardSha256:sha(await readFile(shardPath))};
   const prior=report.mismatches;
   if(d.sourceRowCount!==rows.length)
    mismatch('numericMismatches',{reason:'Flutter/React record count',season,segment,basis,expected:d.sourceRowCount,actual:rows.length});
   if(d.samples.length){nonEmptyCases++;nonEmptySeasons.add(season)}
   const lookup=[];
   for(const gold of d.samples){
    const react=index.get(gold.id);
    if(!react){mismatch('numericMismatches',{reason:'missing sample player',season,segment,basis,id:gold.id});continue}
    lookup.push({gold,react});
    if(gold.player!==react.player||gold.team!==react.team||gold.position!==react.position)
     mismatch('numericMismatches',{reason:'player identity',season,segment,basis,id:gold.id,expected:[gold.player,gold.team,gold.position],actual:[react.player,react.team,react.position]});
    for(const [key,v] of Object.entries(gold.metrics)){
     const actual=metricValue(react,key);
     if(!report.metricPresence[key])report.metricPresence[key]={sourceNonNull:0,reactNonNull:0};
     if(v!==null)report.metricPresence[key].sourceNonNull++;
     if(actual!==null)report.metricPresence[key].reactNonNull++;
     info.metricsCompared++;report.comparisons++;
     if(!numericEqual(v,actual))
      mismatch('numericMismatches',{season,segment,basis,id:gold.id,key,expected:v,actual});
    }
   }
   // Matching 50/20 filters and PTS/100 sort order (source-tied IDs).
   // Flutter screen filters row.value('min') in the SELECTED rate basis.
   // Using a per-game minimum for every rate basis would be a false match.
   for(const [gpMin,minMin] of [[0,0],[50,20],[20,15]]){
    const f=lookup.filter(({gold})=>(gold.gp??0)>=gpMin&&(gold.minutes??0)>=minMin)
      .map(x=>x.gold.id).sort();
    const r=lookup.filter(({react})=>(react.values.gp??0)>=gpMin&&(react.values.min??0)>=minMin)
      .map(x=>x.react.id).sort();
    if(JSON.stringify(f)!==JSON.stringify(r))
     mismatch('filterMismatches',{season,segment,basis,gpMin,minMin,expected:f.slice(0,20),actual:r.slice(0,20)});
    report.comparisons++;
   }
   for(const descending of [true,false]){
    const expected=sortIds(lookup.map(x=>x.gold),'ppg',descending);
    const actual=sortIds(lookup.map(({gold,react})=>({...gold,
     metrics:{...gold.metrics,ppg:metricValue(react,'ppg')}})),'ppg',descending);
    if(JSON.stringify(expected)!==JSON.stringify(actual))
     mismatch('sortMismatches',{season,segment,basis,descending,expected:expected.slice(0,20),actual:actual.slice(0,20)});
    report.comparisons++;
   }
   if(basis==='per100'&&advancedLabel('ppg',basis)!=='PTS/100')
    mismatch('catalogMismatches',{reason:'PTS/100 sort column not named correctly'});
   if(basis==='perGame'&&advancedLabel('ppg',basis)!=='PPG')
    mismatch('catalogMismatches',{reason:'PPG sort column not named correctly'});
   info.mismatches=report.mismatches-prior;
   report.cases.push(info);
  }
 }
 if(nonEmptyCases<12||nonEmptySeasons.size<2)
  throw Error('Insufficient non-empty real-data reference coverage (need 12+ basis cases and 2+ distinct seasons).');
 report.sampledCatalogMetricCoverage={
  total:dart.metrics.length,
  observedSourceNonNull:Object.values(report.metricPresence).filter(x=>x.sourceNonNull>0).length,
  unavailableInSample:dart.metrics.filter(x=>(report.metricPresence[x.key]?.sourceNonNull??0)===0).map(x=>x.key),
  note:'Unavailable fields are not treated as fabricated zero; a PASS does not mean every catalog field is populated in these three seasons.'
 };
 report.status=report.mismatches===0?'PASS':'FAIL';
 report.nonEmptyCases=nonEmptyCases;report.nonEmptySeasons=[...nonEmptySeasons];
}catch(error){
 report.errors.push(error instanceof Error?error.stack??error.message:String(error));
 report.status='FAIL';
}finally{
 if(vite)await vite.close();
 await writeFile(path.join(outDir,'advanced-source-parity.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({status:report.status,manifestSha256:report.manifestSha256,
  comparisons:report.comparisons,mismatches:report.mismatches,
  numericMismatches:report.numericMismatches,catalogMismatches:report.catalogMismatches,
  filterMismatches:report.filterMismatches,sortMismatches:report.sortMismatches,
  nonEmptyCases:report.nonEmptyCases,errors:report.errors.slice(0,2),
  mismatchExamples:report.samples.slice(0,12),
  output:path.join(outDir,'advanced-source-parity.json')},null,2));
 if(report.status!=='PASS')process.exitCode=1;
}
