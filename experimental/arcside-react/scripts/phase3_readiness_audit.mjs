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
const comparisons=await read('experimental/arcside-react/src/ComparisonWorkspaces.tsx');
const financials=await read('experimental/arcside-react/src/FinancialsWorkspace.tsx');
const boxScores=await read('experimental/arcside-react/src/BoxScoresWorkspace.tsx');
const withWithout=await read('experimental/arcside-react/src/WithWithoutWorkspace.tsx');
const teamDetail=await read('experimental/arcside-react/src/TeamDetailWorkspace.tsx');
const games=await read('experimental/arcside-react/src/GamesWorkspace.tsx');
const franchise=await read('experimental/arcside-react/src/FranchiseHistoryWorkspace.tsx');
const profile=await read('experimental/arcside-react/src/ProfileTable.tsx');
const tradeCandidate=await read('experimental/arcside-react/src/tradeEngine.ts');
const flutterTrade=await read('lib/services/trade_machine_engine.dart');
const python=await read('web/labs/python/index.html');
const sheets=await read('web/labs/sheets/index.html');
const routes=(app.match(/const allowedRoutes=\[([^\]]+)\]/)?.[1]??'').match(/'[^']+'/g)?.map(x=>x.slice(1,-1))??[];
const reference=[
 {module:'Stats',path:'lib/screens/website_nba_stats_screen.dart',candidate:'/stats'},
 {module:'Advanced Stats',path:'lib/screens/website_nba_advanced_stats_v4_screen.dart',candidate:'/advanced'},
 {module:'Visualization Studio',path:'lib/screens/website_nba_visualizations_v2_screen.dart',candidate:'/visualizations'},
 {module:'Player comparison',path:'lib/screens/website_nba_player_comparison_screen.dart',candidate:'/player-compare'},
 {module:'Team comparison',path:'lib/screens/website_nba_team_comparison_screen.dart',candidate:'/team-compare'},
 {module:'Trade Machine',path:'lib/screens/product_trade_machine_complete_screen.dart',candidate:'/trade'},
 {module:'Box scores',path:'lib/screens/website_nba_box_scores_screen.dart',candidate:'/box-scores'},
 {module:'Financials and player contracts',path:'lib/screens/website_nba_financials_screen.dart',candidate:'/financials'},
 {module:'Team detail',path:'lib/screens/website_nba_team_detail_screen.dart',candidate:'/teams'},
 {module:'Games',path:'lib/screens/games_screen.dart',candidate:'/games'},
 {module:'Franchise history',path:'lib/screens/franchise_history_screen.dart',candidate:'/franchise-history'},
 {module:'With/Without',path:'lib/screens/website_nba_with_without_v2_screen.dart',candidate:'/with-without'},
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
  item.module==='Player profiles'?'CAREER_ADVANCED_DATED_SALARY_CONTRACT_HONORS_PARTIAL_NOT_PARITY_VALIDATED':
  item.module==='Trade Machine'?'SCENARIO_VALIDATOR_PILOT_ONLY_NOT_PRODUCTION_UI':
  ['Player comparison','Team comparison','Box scores','Financials and player contracts','With/Without','Team detail','Games','Franchise history'].includes(item.module)?'SOURCE_BACKED_PILOT_ROUTE_NOT_FULL_PARITY':
  ['Python Lab','Excel Workspace'].includes(item.module)?'ORIGINAL_MODULE_EMBEDDED_NOT_FULLY_VALIDATED':
  'PILOT_ROUTE_PRESENT_NOT_FULL_SCOPE_VALIDATED';
 modules.push({...item,referencePathExists:tracked,candidateRoutePresent:route,status});
}
const directFailures=[
 {check:'Cross-route full feature equivalence',status:'PARTIAL_SOURCE_BACKED_PILOTS',
  detail:'Player and Team Compare, Box Scores, Financials, With/Without, Team Detail, Games and Franchise History now expose source-backed pilot routes. Original Flutter feature controls, native device UX and cross-route parity remain unverified. Player comparison now supports browser-local presets, not authenticated saved-view interchange. The original Franchise History screen is a roadmap, not an implemented historical continuity database.'},
 {check:'Full CBA trade rules and production transaction UI',status:'INDEPENDENT_TS_VALIDATOR_PRESENT_BUT_UNVERIFIED_FULL_SCOPE',
  detail:'An independent TypeScript validator and isolated 2–5 team hypothetical editor exist, with strict numeric input parsing and date-labeled 2026–27 player salary records from the original Flutter seed. Expanded original-Dart golden fixtures now cover 27 deterministic scenarios (subject to the run result). Full source payroll/cap and draft-asset eligibility feeds, original Flutter transaction workflows and exhaustive NBA CBA rule coverage remain unverified.'},
 {check:'Player dossier holistic profile parity',status:'PARTIAL_IN_REACT_PILOT',
  detail:'React /player/:key now renders source-backed career and Advanced Stats tables, Dart-format honors, and same-origin dated 2026-27 salary seed plus optional static front-office contract joins. Browser-local front-office overlays, exact all-column comparisons, deep links and complete Flutter UX remain unverified.'},
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
 gitReference:{tradeEngineSha256:hash(flutterTrade),reactTradeEngineSha256:hash(tradeCandidate),reactAppSha256:hash(app),reactChartSha256:hash(chart),comparisonSha256:hash(comparisons),financialsSha256:hash(financials),boxScoreSha256:hash(boxScores),withWithoutSha256:hash(withWithout),teamDetailSha256:hash(teamDetail),gamesSha256:hash(games),franchiseSha256:hash(franchise),reactProfileTablesSha256:hash(profile)},
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
