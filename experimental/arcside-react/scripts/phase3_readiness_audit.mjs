// Read-only Phase 3 readiness audit: evidence, never migration authorization.
// Uses actual tracked reference sources and current candidate shell, not screenshots.
import {readFile,access,mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..'),home=path.resolve(here,'..');
const read=async p=>readFile(path.join(root,p),'utf8');
const exists=async p=>{try{await access(path.join(root,p));return true}catch{return false}};
const hash=s=>createHash('sha256').update(s).digest('hex');
const app=await read('experimental/arcside-react/src/App.tsx');
const chart=await read('experimental/arcside-react/src/Chart.tsx');
const flutterTrade=await read('lib/services/trade_machine_engine.dart');
const python=await read('web/labs/python/index.html');
const sheets=await read('web/labs/sheets/index.html');
const routes=(app.match(/const allowedRoutes=\[([^\]]+)\]/)?.[1]??'').match(/'[^']+'/g)?.map(x=>x.slice(1,-1))??[];
const reference=[
 {module:'Stats',path:'lib/screens/website_nba_stats_screen.dart',candidate:'/stats'},
 {module:'Advanced Stats',path:'lib/screens/website_nba_advanced_stats_v4_screen.dart',candidate:'/advanced'},
 {module:'Visualization Studio',path:'lib/screens/website_nba_visualizations_v2_screen.dart',candidate:'/visualizations'},
 {module:'Player comparison',path:'lib/screens/compare_screen.dart'},
 {module:'Team comparison',path:'lib/screens/website_nba_team_comparison_screen.dart'},
 {module:'Trade Machine',path:'lib/screens/product_trade_machine_complete_screen.dart'},
 {module:'Box scores',path:'lib/screens/website_nba_box_scores_screen.dart'},
 {module:'With/Without',path:'lib/screens/website_nba_with_without_v2_screen.dart'},
 {module:'Player profiles',path:'lib/screens/entity_profile_screens.dart',candidate:'/player/:key'},
 {module:'Python Lab',path:'web/labs/python/index.html',candidate:'/workspaces/python'},
 {module:'Excel Workspace',path:'web/labs/sheets/index.html',candidate:'/workspaces/sheets'}
];
const modules=[];
for(const item of reference){
 const tracked=await exists(item.path);
 const route=item.candidate?.startsWith('/player/')?app.includes("view.path.startsWith('/player/')"):
  !!item.candidate&&routes.includes(item.candidate);
 const status=!tracked?'REFERENCE_PATH_MISSING':!route?'CANDIDATE_ROUTE_MISSING':
  item.module==='Player profiles'?'PARTIAL_DOSSIER_FIELDS_ONLY':
  ['Python Lab','Excel Workspace'].includes(item.module)?'ORIGINAL_MODULE_EMBEDDED_NOT_FULLY_VALIDATED':
  'PILOT_ROUTE_PRESENT_NOT_FULL_SCOPE_VALIDATED';
 modules.push({...item,referencePathExists:tracked,candidateRoutePresent:route,status});
}
const directFailures=[
 {check:'Full CBA trade rules',status:'NOT_IMPLEMENTED_IN_REACT_PILOT',
  detail:'Original Dart TradeMachineEngine exists; React candidate has no independent equivalent or transaction UI. Exporter alone cannot establish port parity.'},
 {check:'Player dossier complete Stats/Advanced tables',status:'NOT_IMPLEMENTED_IN_REACT_PILOT',
  detail:'React /player/:key renders a minimal eight-field metadata list rather than the original source-backed full player stats/advanced profile tables.'},
 {check:'React chart keyboard alternative',status:chart.includes('className="chart-accessible"')?'PARTIAL_TABLE_ALTERNATIVE':'NOT_VERIFIED',
  detail:'Underlying data table may support screen readers, but plot navigation, focus and tooltip parity require real assistive-technology tests.'}
];
const backendRisks=[
 {name:'Original Lab runtime',status:'SAME_ORIGIN_IFRAME',evidence:'Existing Python and Sheets HTML modules embedded unchanged'},
 {name:'Python local runtime',status:python.includes('localToken')?'TOKEN_INPUT_PRESENT_NOT_SECURITY_VERIFIED':'NOT_DETECTED',
  evidence:'Presence of password input does not prove token lifetime, CSRF protection, privilege separation or network binding'},
 {name:'Sheets collaboration',status:sheets.includes('shareWorkbook')?'COLLABORATION_PRESENT_NOT_SECURITY_VERIFIED':'NOT_DETECTED',
  evidence:'Original collaboration UI reused; authorization and role isolation require a live authenticated server test'},
 {name:'Lab bridge',status:app.includes('evt.origin!==location.origin')&&app.includes('evt.source!==labRef.current?.contentWindow')?'EXPLICIT_ORIGIN_AND_SOURCE_CHECKS':'BRIDGE_CHECK_MISSING',
  evidence:'Static source checks only. Runtime cross-origin attack probe remains required'}
];
const checkFiles=[
 'test/trade_machine_cba_edge_rules_test.dart','test/phase3_stats_parity_export_test.dart',
 'test/phase3_visualization_reference_export_test.dart',
 'experimental/arcside-react/scripts/compare_trade_goldens.mjs'];
const sourceTests=[];for(const p of checkFiles)sourceTests.push({path:p,exists:await exists(p)});
const report={kind:'ARCSIDE_PHASE3_FULL_SCOPE_AUDIT_V1',createdAt:new Date().toISOString(),
 branchPurpose:'narrow React proof of concept only',
 gitReference:{tradeEngineSha256:hash(flutterTrade),reactAppSha256:hash(app),reactChartSha256:hash(chart)},
 candidateRoutes:routes,modules,directFailures,backendRisks,sourceTests,
 fullScopeFeatureParity:false,fullTradeAndProfileParity:false,securityCertified:false,accessibilityCertified:false,
 status:'GAPS_CONFIRMED',
 caveat:'Route presence is not feature equivalence. This read-only audit cannot verify untracked historic datasets, physical macOS Safari/VoiceOver, Windows NVDA, GPU metrics, server privilege boundaries or owner signoff.'};
const output=path.join(home,'evidence/readiness');
await mkdir(output,{recursive:true});
await writeFile(path.join(output,'phase3-readiness-audit.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({status:report.status,referenceModules:modules.length,
 absentCandidateModules:modules.filter(x=>x.status==='CANDIDATE_ROUTE_MISSING').map(x=>x.module),
 partialPlayerProfiles:true,fullTradeAndProfileParity:false,
 output:path.join(output,'phase3-readiness-audit.json')},null,2));
